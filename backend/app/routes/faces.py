from fastapi import APIRouter, Depends, File, Form, Response, UploadFile, status

from app.core.security import get_current_uid
from app.services.face_service import face_service

router = APIRouter(prefix="/v1", tags=["faces"])


@router.post("/recognize")
async def recognize(
    image: UploadFile = File(...),
    uid: str = Depends(get_current_uid),
):
    raw = await image.read()
    return face_service.recognize(uid, raw)


@router.post("/faces", status_code=status.HTTP_201_CREATED)
async def enroll_face(
    image: UploadFile = File(...),
    name: str = Form(...),
    face_index: int = Form(...),
    image_path: str | None = Form(default=None),
    uid: str = Depends(get_current_uid),
):
    raw = await image.read()
    return face_service.enroll(
        uid=uid,
        raw=raw,
        face_index=face_index,
        name=name,
        image_path=image_path,
    )


@router.get("/faces")
def list_faces(uid: str = Depends(get_current_uid)):
    return {"faces": face_service.list_faces(uid)}


@router.delete("/faces/{face_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_face(
    face_id: str,
    uid: str = Depends(get_current_uid),
):
    face_service.delete_face(uid, face_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
