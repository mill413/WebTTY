from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import get_current_user
from app.database import get_db
from app.models import UserSettings
from app.schemas import UserSettingsResponse, UserSettingsUpdate

router = APIRouter(prefix="/api/settings", tags=["settings"])


@router.get("", response_model=UserSettingsResponse)
async def get_settings(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == current_user.id)
    )
    user_settings = result.scalar_one_or_none()
    if user_settings is None:
        user_settings = UserSettings(user_id=current_user.id)
        db.add(user_settings)
        await db.commit()
        await db.refresh(user_settings)
    return user_settings


@router.put("", response_model=UserSettingsResponse)
async def update_settings(
    body: UserSettingsUpdate,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(UserSettings).where(UserSettings.user_id == current_user.id)
    )
    user_settings = result.scalar_one_or_none()
    if user_settings is None:
        user_settings = UserSettings(user_id=current_user.id)
        db.add(user_settings)

    update_data = body.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(user_settings, key, value)

    await db.commit()
    await db.refresh(user_settings)
    return user_settings
