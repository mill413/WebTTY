#!/usr/bin/env python3
"""Entry point for the PyInstaller-bundled MebTTY executable."""

import os
import sys


def main():
    # In PyInstaller --onefile mode, sys._MEIPASS is the temp extraction directory
    if hasattr(sys, "_MEIPASS"):
        bundled_frontend = os.path.join(sys._MEIPASS, "frontend_dist")
        bundled_data = os.path.join(os.path.dirname(sys.executable), "data")

        # Set env vars BEFORE importing the app so config.py picks them up
        if not os.environ.get("MEBTTY_STATIC_DIR") and os.path.isdir(bundled_frontend):
            os.environ["MEBTTY_STATIC_DIR"] = bundled_frontend

        if not os.environ.get("MEBTTY_DATABASE_URL"):
            os.makedirs(bundled_data, exist_ok=True)
            os.environ["MEBTTY_DATABASE_URL"] = (
                f"sqlite+aiosqlite:///{bundled_data}/mebtty.db"
            )

        if not os.environ.get("MEBTTY_UPLOAD_DIR"):
            upload_dir = os.path.join(bundled_data, "uploads")
            os.makedirs(upload_dir, exist_ok=True)
            os.environ["MEBTTY_UPLOAD_DIR"] = upload_dir

    # Now import and run the app
    import uvicorn

    host = os.environ.get("MEBTTY_HOST", "0.0.0.0")
    port = int(os.environ.get("MEBTTY_PORT", "18888"))

    uvicorn.run(
        "app.main:app",
        host=host,
        port=port,
        log_level="info",
    )


if __name__ == "__main__":
    main()
