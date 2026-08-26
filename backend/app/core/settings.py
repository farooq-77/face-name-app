import os


class Settings:
    face_match_tolerance: float = float(os.getenv("FACE_MATCH_TOLERANCE", "0.50"))
    face_template_min_distance: float = float(
        os.getenv("FACE_TEMPLATE_MIN_DISTANCE", "0.18")
    )
    max_templates_per_face: int = int(
        os.getenv("MAX_TEMPLATES_PER_FACE", "5")
    )
    max_faces_per_user: int = int(os.getenv("MAX_FACES_PER_USER", "1000"))
    max_upload_bytes: int = int(
        os.getenv("MAX_UPLOAD_BYTES", str(10 * 1024 * 1024))
    )
    firebase_storage_bucket: str = os.getenv(
        "FIREBASE_STORAGE_BUCKET", ""
    ).strip()
    service_account_json: str = os.getenv(
        "FIREBASE_SERVICE_ACCOUNT_JSON", ""
    ).strip()

    @property
    def cors_origins(self) -> list[str]:
        raw = os.getenv("CORS_ORIGINS", "").strip()
        return [value.strip() for value in raw.split(",") if value.strip()]


settings = Settings()
