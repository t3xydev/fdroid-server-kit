from __future__ import annotations

import asyncio
import json
import os
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

ROOT_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = Path(os.environ.get("DATA_DIR", str(ROOT_DIR))).resolve()
SCRIPTS_DIR = ROOT_DIR / "scripts"
STATUS_FILE = DATA_DIR / "status.json"
WEBHOOK_TOKEN = os.environ.get("WEBHOOK_TOKEN", "")

S3_REQUIRED = (
    "S3_REMOTE_NAME",
    "S3_PROVIDER",
    "S3_BUCKET",
    "S3_ACCESS_KEY_ID",
    "S3_SECRET_ACCESS_KEY",
    "S3_ENDPOINT",
)

_publish_lock = asyncio.Lock()


def _truthy(value: str | None) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes", "on"}


def s3_configured() -> bool:
    return all(os.environ.get(name) for name in S3_REQUIRED)


def is_self_host() -> bool:
    return _truthy(os.environ.get("SELF_HOST")) or not s3_configured()


def resolve_mode() -> str:
    return "self_host" if is_self_host() else "s3"


def ensure_data_dirs() -> None:
    for name in ("apks", "repo", "metadata", "tmp", "cache", "logs", "srclibs", "assets"):
        (DATA_DIR / name).mkdir(parents=True, exist_ok=True)


def read_status() -> dict[str, Any]:
    if not STATUS_FILE.exists():
        return {
            "status": "idle",
            "mode": resolve_mode(),
            "message": "No publish jobs yet",
        }
    try:
        return json.loads(STATUS_FILE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {
            "status": "unknown",
            "mode": resolve_mode(),
            "message": "Could not read status.json",
        }


def write_status(payload: dict[str, Any]) -> None:
    ensure_data_dirs()
    payload = {
        **payload,
        "mode": resolve_mode(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    STATUS_FILE.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def require_token(
    authorization: str | None = Header(default=None),
    x_webhook_token: str | None = Header(default=None, alias="X-Webhook-Token"),
) -> None:
    if not WEBHOOK_TOKEN:
        raise HTTPException(
            status_code=503,
            detail="WEBHOOK_TOKEN is not configured on the server",
        )
    token = None
    if x_webhook_token:
        token = x_webhook_token.strip()
    elif authorization:
        parts = authorization.split(" ", 1)
        if len(parts) == 2 and parts[0].lower() == "bearer":
            token = parts[1].strip()
        else:
            token = authorization.strip()
    if not token or token != WEBHOOK_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid or missing webhook token")


def safe_apk_name(filename: str | None) -> str:
    name = Path(filename or "upload.apk").name
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", name)
    if not name.lower().endswith(".apk"):
        name = f"{name}.apk"
    return name or "upload.apk"


async def run_script(script_name: str) -> dict[str, Any]:
    script = SCRIPTS_DIR / script_name
    if not script.is_file():
        raise RuntimeError(f"Missing script: {script}")

    env = os.environ.copy()
    env["DATA_DIR"] = str(DATA_DIR)

    proc = await asyncio.create_subprocess_exec(
        str(script),
        cwd=str(DATA_DIR),
        env=env,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    stdout_b, _ = await proc.communicate()
    log = stdout_b.decode("utf-8", errors="replace")
    return {
        "exit_code": proc.returncode or 0,
        "log": log,
        "ok": (proc.returncode or 0) == 0,
    }


async def run_publish_job(trigger: str) -> dict[str, Any]:
    if _publish_lock.locked():
        raise HTTPException(status_code=409, detail="A publish job is already running")

    async with _publish_lock:
        started = datetime.now(timezone.utc).isoformat()
        write_status(
            {
                "status": "running",
                "trigger": trigger,
                "started_at": started,
                "message": f"Running update.sh ({trigger})",
            }
        )
        try:
            result = await run_script("update.sh")
        except Exception as exc:  # noqa: BLE001
            write_status(
                {
                    "status": "failed",
                    "trigger": trigger,
                    "started_at": started,
                    "finished_at": datetime.now(timezone.utc).isoformat(),
                    "message": str(exc),
                    "log": "",
                }
            )
            raise HTTPException(status_code=500, detail=str(exc)) from exc

        finished = datetime.now(timezone.utc).isoformat()
        if result["ok"]:
            write_status(
                {
                    "status": "success",
                    "trigger": trigger,
                    "started_at": started,
                    "finished_at": finished,
                    "message": "Publish succeeded",
                    "exit_code": result["exit_code"],
                    "log": result["log"][-20000:],
                }
            )
        else:
            write_status(
                {
                    "status": "failed",
                    "trigger": trigger,
                    "started_at": started,
                    "finished_at": finished,
                    "message": "Publish failed",
                    "exit_code": result["exit_code"],
                    "log": result["log"][-20000:],
                }
            )
            raise HTTPException(
                status_code=500,
                detail={
                    "message": "Publish failed",
                    "exit_code": result["exit_code"],
                    "log_tail": result["log"][-4000:],
                },
            )
        return read_status()


app = FastAPI(title="F-Droid Repo Server", version="1.0.0")


@app.on_event("startup")
def on_startup() -> None:
    ensure_data_dirs()
    # Seed shipped icon into data volume if missing
    default_icon = ROOT_DIR / "assets" / "icon.png"
    data_icon = DATA_DIR / "assets" / "icon.png"
    if default_icon.is_file() and not data_icon.is_file():
        shutil.copy2(default_icon, data_icon)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/status")
def api_status() -> dict[str, Any]:
    status = read_status()
    status["mode"] = resolve_mode()
    status["self_host"] = is_self_host()
    status["s3_configured"] = s3_configured()
    status["data_dir"] = str(DATA_DIR)
    status["repo_url"] = os.environ.get("REPO_URL", "")
    return status


@app.post("/hooks/publish")
async def hooks_publish(_: None = Depends(require_token)) -> dict[str, Any]:
    return await run_publish_job("publish")


@app.post("/hooks/apk")
async def hooks_apk(
    file: UploadFile = File(...),
    _: None = Depends(require_token),
) -> dict[str, Any]:
    ensure_data_dirs()
    filename = safe_apk_name(file.filename)
    dest = DATA_DIR / "apks" / filename
    with dest.open("wb") as out:
        while True:
            chunk = await file.read(1024 * 1024)
            if not chunk:
                break
            out.write(chunk)
    status = await run_publish_job(f"apk:{filename}")
    status["apk"] = filename
    return status


# Mount repo static files when self-host is active (and always for debug browse).
# Clients should use REPO_URL pointing here when mode is self_host.
repo_dir = DATA_DIR / "repo"
repo_dir.mkdir(parents=True, exist_ok=True)
app.mount("/fdroid/repo", StaticFiles(directory=str(repo_dir), html=True), name="repo")


@app.get("/")
def root() -> JSONResponse:
    return JSONResponse(
        {
            "service": "fdroid-server",
            "mode": resolve_mode(),
            "health": "/health",
            "status": "/api/status",
            "repo": "/fdroid/repo/" if is_self_host() else None,
            "hooks": {
                "apk": "POST /hooks/apk",
                "publish": "POST /hooks/publish",
            },
        }
    )
