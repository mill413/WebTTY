import re

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import CommandLog, AuditEvent


CRITICAL_PATTERNS = [
    r"rm\s+-rf\s+/",
    r"mkfs\b",
    r"dd\s+if=",
    r"\bshutdown\b",
    r"\breboot\b",
    r"\bhalt\b",
    r"\bpoweroff\b",
    r"init\s+0",
    r"init\s+6",
]

HIGH_PATTERNS = [
    r"rm\s+-rf\b",
    r"chmod\s+-R\s+777\b",
    r"iptables\s+-F\b",
    r"\bpasswd\b",
    r"\buserdel\b",
    r"\bfdisk\b",
]

MEDIUM_PATTERNS = [
    r"\bkill\b",
    r"\bpkill\b",
    r"systemctl\s+stop\b",
    r"systemctl\s+restart\b",
]


def detect_risk_level(command: str) -> str:
    for pattern in CRITICAL_PATTERNS:
        if re.search(pattern, command):
            return "critical"
    for pattern in HIGH_PATTERNS:
        if re.search(pattern, command):
            return "high"
    for pattern in MEDIUM_PATTERNS:
        if re.search(pattern, command):
            return "medium"
    return "low"


async def log_command(
    db: AsyncSession,
    session_id: str,
    user_id: str,
    command: str,
    output: str = "",
    risk_level: str = "low",
) -> CommandLog:
    log = CommandLog(
        session_id=session_id,
        user_id=user_id,
        command=command,
        output=output,
        risk_level=risk_level,
    )
    db.add(log)
    await db.flush()
    return log


async def log_event(
    db: AsyncSession,
    user_id: str,
    action: str,
    resource: str = "",
    detail: str = "",
    ip_address: str = "",
) -> AuditEvent:
    event = AuditEvent(
        user_id=user_id,
        action=action,
        resource=resource,
        detail=detail,
        ip_address=ip_address,
    )
    db.add(event)
    await db.flush()
    return event


async def get_session_commands(
    db: AsyncSession,
    session_id: str,
    skip: int = 0,
    limit: int = 50,
) -> list[CommandLog]:
    stmt = (
        select(CommandLog)
        .where(CommandLog.session_id == session_id)
        .order_by(CommandLog.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_user_events(
    db: AsyncSession,
    user_id: str,
    skip: int = 0,
    limit: int = 50,
) -> list[AuditEvent]:
    stmt = (
        select(AuditEvent)
        .where(AuditEvent.user_id == user_id)
        .order_by(AuditEvent.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())
