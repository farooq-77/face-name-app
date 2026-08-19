from __future__ import annotations

import io
import threading
import time
from dataclasses import dataclass

import face_recognition
import numpy as np
from PIL import Image, UnidentifiedImageError
from fastapi import HTTPException, status
from firebase_admin import firestore

from app.core.firebase import db
from app.core.settings import settings


@dataclass(frozen=True)
class KnownFace:
    face_id: str
    name: str
    embedding: np.ndarray
    image_path: str | None


class FaceService:
    def __init__(self) -> None:
        self._cache: dict[str, tuple[float, list[KnownFace]]] = {}
        self._lock = threading.Lock()
        self._cache_ttl = 30.0

    def invalidate(self, uid: str) -> None:
        with self._lock:
            self._cache.pop(uid, None)

    def _known_faces(self, uid: str) -> list[KnownFace]:
        now = time.monotonic()
        with self._lock:
            cached = self._cache.get(uid)
            if cached and now - cached[0] <= self._cache_ttl:
                return cached[1]

        docs = (
            db().collection("users").document(uid)
            .collection("faces").stream()
        )
        faces: list[KnownFace] = []
        for doc in docs:
            data = doc.to_dict()
            embedding_raw = data.get("embedding")
            if not isinstance(embedding_raw, list) or len(embedding_raw) != 128:
                continue
            faces.append(
                KnownFace(
                    face_id=doc.id,
                    name=str(data.get("name") or "Unnamed"),
                    embedding=np.asarray(embedding_raw, dtype=np.float64),
                    image_path=data.get("imagePath"),
                )
            )

        with self._lock:
            self._cache[uid] = (now, faces)
        return faces

    def _decode_image(self, raw: bytes) -> tuple[np.ndarray, int, int]:
        if not raw:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"code": "EMPTY_IMAGE", "message": "Image is empty."},
            )
        if len(raw) > settings.max_upload_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail={
                    "code": "IMAGE_TOO_LARGE",
                    "message": "Image exceeds upload limit.",
                },
            )

        try:
            pil = Image.open(io.BytesIO(raw)).convert("RGB")
            width, height = pil.size
            if width < 80 or height < 80:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={
                        "code": "IMAGE_TOO_SMALL",
                        "message": "Image is too small.",
                    },
                )

            max_pixels = 20_000_000
            if width * height > max_pixels:
                scale = (max_pixels / (width * height)) ** 0.5
                pil = pil.resize(
                    (
                        max(80, int(width * scale)),
                        max(80, int(height * scale)),
                    )
                )
                width, height = pil.size

            return np.asarray(pil), width, height
        except HTTPException:
            raise
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "code": "INVALID_IMAGE",
                    "message": "Unsupported or corrupted image.",
                },
            ) from exc

    def encodings(
        self, raw: bytes
    ) -> tuple[
        list[tuple[int, int, int, int]],
        list[np.ndarray],
        int,
        int,
    ]:
        image, width, height = self._decode_image(raw)
        locations = face_recognition.face_locations(image, model="hog")
        embeddings = face_recognition.face_encodings(
            image,
            known_face_locations=locations,
            num_jitters=1,
            model="small",
        )
        return locations, embeddings, width, height

    def recognize(self, uid: str, raw: bytes) -> dict:
        locations, embeddings, width, height = self.encodings(raw)
        known = self._known_faces(uid)
        known_vectors = [face.embedding for face in known]

        result_faces = []
        for index, (location, embedding) in enumerate(
            zip(locations, embeddings)
        ):
            top, right, bottom, left = (int(v) for v in location)
            item = {
                "index": index,
                "matched": False,
                "box": {
                    "top": top,
                    "right": right,
                    "bottom": bottom,
                    "left": left,
                },
                "faceId": None,
                "name": None,
                "distance": None,
                "similarity": None,
            }

            if known_vectors:
                distances = face_recognition.face_distance(
                    known_vectors, embedding
                )
                best_index = int(np.argmin(distances))
                distance = float(distances[best_index])

                if distance <= settings.face_match_tolerance:
                    matched = known[best_index]
                    item.update(
                        matched=True,
                        faceId=matched.face_id,
                        name=matched.name,
                        distance=round(distance, 5),
                        similarity=round(
                            max(0.0, min(1.0, 1.0 - distance)), 5
                        ),
                    )

            result_faces.append(item)

        return {
            "faces": result_faces,
            "width": width,
            "height": height,
        }

    def enroll(
        self,
        uid: str,
        raw: bytes,
        face_index: int,
        name: str,
        image_path: str | None,
    ) -> dict:
        clean_name = " ".join(name.strip().split())
        if not clean_name or len(clean_name) > 80:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    "code": "INVALID_NAME",
                    "message": "Name must be 1–80 characters.",
                },
            )

        locations, embeddings, _, _ = self.encodings(raw)
        if not embeddings:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={"code": "NO_FACE", "message": "No face detected."},
            )
        if face_index < 0 or face_index >= len(embeddings):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    "code": "INVALID_FACE_INDEX",
                    "message": "Selected face was not found.",
                },
            )

        existing = self._known_faces(uid)
        if len(existing) >= settings.max_faces_per_user:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "FACE_LIMIT",
                    "message": "Face database limit reached.",
                },
            )

        embedding = embeddings[face_index]
        if existing:
            distances = face_recognition.face_distance(
                [face.embedding for face in existing],
                embedding,
            )
            best_index = int(np.argmin(distances))
            best_distance = float(distances[best_index])
            if best_distance <= settings.face_match_tolerance:
                duplicate = existing[best_index]
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={
                        "code": "FACE_ALREADY_ENROLLED",
                        "message": (
                            f"This face is already saved as "
                            f"{duplicate.name}."
                        ),
                        "faceId": duplicate.face_id,
                        "name": duplicate.name,
                    },
                )

        doc_ref = (
            db().collection("users").document(uid)
            .collection("faces").document()
        )
        top, right, bottom, left = (
            int(v) for v in locations[face_index]
        )
        doc_ref.set(
            {
                "name": clean_name,
                "nameLower": clean_name.casefold(),
                "embedding": [
                    float(v) for v in embedding.tolist()
                ],
                "imagePath": image_path or None,
                "sourceBox": {
                    "top": top,
                    "right": right,
                    "bottom": bottom,
                    "left": left,
                },
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
        )
        self.invalidate(uid)

        return {
            "id": doc_ref.id,
            "name": clean_name,
            "imagePath": image_path,
        }

    def list_faces(self, uid: str) -> list[dict]:
        docs = (
            db().collection("users").document(uid)
            .collection("faces")
            .order_by("nameLower")
            .stream()
        )

        result = []
        for doc in docs:
            data = doc.to_dict()
            result.append(
                {
                    "id": doc.id,
                    "name": str(data.get("name") or "Unnamed"),
                    "imagePath": data.get("imagePath"),
                }
            )
        return result

    def delete_face(self, uid: str, face_id: str) -> str | None:
        ref = (
            db().collection("users").document(uid)
            .collection("faces").document(face_id)
        )
        snapshot = ref.get()
        if not snapshot.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "NOT_FOUND",
                    "message": "Saved face not found.",
                },
            )

        image_path = snapshot.to_dict().get("imagePath")
        ref.delete()
        self.invalidate(uid)
        return image_path


face_service = FaceService()
