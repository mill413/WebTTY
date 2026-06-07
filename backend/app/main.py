import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

# Import models so they're registered with Base.metadata before init_db
from app.models import User, Session, CommandLog, AuditEvent  # noqa: F401

from app.auth.router import router as auth_router
from app.session.router import router as session_router
from app.terminal.router import router as terminal_router
from app.audit.router import router as audit_router
from app.file.router import router as file_router
from app.database import init_db, async_session_factory

logging.basicConfig(level=logging.INFO)

logger = logging.getLogger(__name__)


async def cleanup_stale_sessions():
    """Mark sessions that were running/starting when server shut down as stopped."""
    from sqlalchemy import select
    from app.models import Session

    async with async_session_factory() as db:
        result = await db.execute(
            select(Session).where(Session.status.in_(["running", "starting", "created"]))
        )
        stale = result.scalars().all()
        for s in stale:
            s.status = "stopped"
        if stale:
            await db.commit()
            logger.info(f"Cleaned up {len(stale)} stale session(s)")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing database...")
    await init_db()
    await cleanup_stale_sessions()
    logger.info("WebTTY Enterprise started")
    yield
    logger.info("WebTTY Enterprise shutting down")


app = FastAPI(
    title="WebTTY Enterprise",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware - applies to both HTTP and WebSocket
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(session_router)
app.include_router(terminal_router)
app.include_router(audit_router)
app.include_router(file_router)


@app.get("/api/health")
async def health():
    return {"status": "ok", "version": "1.0.0"}
