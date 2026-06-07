import pathlib
from datetime import datetime, timezone

import aiofiles
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form
from fastapi.responses import FileResponse

from app.config import settings
from app.auth.dependencies import get_current_user

router = APIRouter(prefix="/api/files", tags=["files"])

CHUNK_SIZE = 4 * 1024 * 1024  # 4MB


def _user_upload_dir(user_id: str) -> pathlib.Path:
    return pathlib.Path(settings.UPLOAD_DIR) / str(user_id)


def _session_upload_dir(user_id: str, session_id: str) -> pathlib.Path:
    return _user_upload_dir(user_id) / session_id


def _validate_path(user_id: str, session_id: str, relative_path: str) -> pathlib.Path:
    """Resolve and validate that the requested path stays within the user's upload directory."""
    base = _user_upload_dir(user_id).resolve()
    target = (_session_upload_dir(user_id, session_id) / relative_path).resolve()
    if not str(target).startswith(str(base)):
        raise HTTPException(status_code=400, detail="Invalid path")
    return target


@router.post("/upload")
async def upload_file(
    session_id: str = Form(...),
    file: UploadFile = File(...),
    current_user=Depends(get_current_user),
):
    dest_dir = _session_upload_dir(current_user.id, session_id)
    dest_dir.mkdir(parents=True, exist_ok=True)

    file_path = dest_dir / file.filename
    size = 0

    async with aiofiles.open(file_path, "wb") as f:
        while True:
            chunk = await file.read(CHUNK_SIZE)
            if not chunk:
                break
            size += len(chunk)
            if size > settings.MAX_UPLOAD_SIZE:
                await f.close()
                file_path.unlink(missing_ok=True)
                raise HTTPException(
                    status_code=413,
                    detail=f"File too large. Maximum size is {settings.MAX_UPLOAD_SIZE} bytes",
                )
            await f.write(chunk)

    return {"filename": file.filename, "size": size}


@router.get("/download")
async def download_file(
    session_id: str = Query(...),
    path: str = Query(...),
    current_user=Depends(get_current_user),
):
    target = _validate_path(current_user.id, session_id, path)

    if not target.is_file():
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(
        path=str(target),
        filename=target.name,
        media_type="application/octet-stream",
    )


@router.get("/list")
async def list_files(
    session_id: str = Query(...),
    current_user=Depends(get_current_user),
):
    session_dir = _session_upload_dir(current_user.id, session_id)

    if not session_dir.is_dir():
        return []

    files = []
    for entry in session_dir.iterdir():
        if entry.is_file():
            stat = entry.stat()
            files.append(
                {
                    "filename": entry.name,
                    "size": stat.st_size,
                    "modified": datetime.fromtimestamp(
                        stat.st_mtime, tz=timezone.utc
                    ).isoformat(),
                }
            )

    return files
