import uuid
from datetime import UTC, datetime, timedelta


def generate_presigned_url(user_id: str, doc_type: str, file_name: str, expires_seconds: int = 3600) -> tuple[str, str]:
    """Stub S3 presigned URL generator — swap for real S3/boto3 in production per system-architecture.md:59."""
    ext = file_name.split(".")[-1] if "." in file_name else "bin"
    key = f"{user_id}/{doc_type}/{uuid.uuid4()}.{ext}"
    file_url = f"s3://mossaid/{key}"
    # fake signed URL
    expires = int((datetime.now(UTC) + timedelta(seconds=expires_seconds)).timestamp())
    upload_url = f"https://mossaid-s3.test/{key}?signature=fake&expires={expires}"
    return upload_url, file_url
