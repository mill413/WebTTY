#!/usr/bin/env bash
#
# WebTTY - One-click deployment script
#
# Usage:
#   ./deploy.sh              # Build and start
#   ./deploy.sh --docker     # Build and start via Docker
#   ./deploy.sh --stop       # Stop the running server
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
VENV_DIR="$BACKEND_DIR/venv"
DATA_DIR="$BACKEND_DIR/data"
HOST="${WEBTTY_HOST:-0.0.0.0}"
PORT="${WEBTTY_PORT:-8000}"
PID_FILE="$SCRIPT_DIR/.webtty.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[WebTTY]${NC} $*"; }
warn() { echo -e "${YELLOW}[WebTTY]${NC} $*"; }
err()  { echo -e "${RED}[WebTTY]${NC} $*" >&2; }

check_deps() {
    local missing=()
    command -v python3 >/dev/null 2>&1 || missing+=(python3)
    command -v node    >/dev/null 2>&1 || missing+=(node)
    command -v npm     >/dev/null 2>&1 || missing+=(npm)
    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing required tools: ${missing[*]}"
        err "Please install them and try again."
        exit 1
    fi
    log "Dependencies check passed (python3, node, npm)"
}

build_frontend() {
    log "Building frontend..."
    cd "$FRONTEND_DIR"
    if [[ ! -d node_modules ]]; then
        log "Installing frontend dependencies..."
        npm install
    fi
    npm run build
    log "Frontend built successfully -> frontend/dist/"
}

setup_backend() {
    log "Setting up backend..."
    cd "$BACKEND_DIR"

    if [[ ! -d "$VENV_DIR" ]]; then
        log "Creating Python virtual environment..."
        python3 -m venv "$VENV_DIR"
    fi

    source "$VENV_DIR/bin/activate"
    log "Installing Python dependencies..."
    pip install -q -r requirements.txt

    mkdir -p "$DATA_DIR" "$BACKEND_DIR/uploads"
}

start_server() {
    cd "$BACKEND_DIR"
    source "$VENV_DIR/bin/activate"

    # Stop existing instance if running
    stop_server 2>/dev/null || true

    export WEBTTY_STATIC_DIR="$FRONTEND_DIR/dist"
    export WEBTTY_DATABASE_URL="${WEBTTY_DATABASE_URL:-sqlite+aiosqlite:///$DATA_DIR/webtty.db}"
    export WEBTTY_SECRET_KEY="${WEBTTY_SECRET_KEY:-$(python3 -c 'import secrets; print(secrets.token_hex(32))')}"

    log "Starting WebTTY server on $HOST:$PORT..."
    log "  Frontend: $WEBTTY_STATIC_DIR"
    log "  Database: $WEBTTY_DATABASE_URL"

    nohup python3 -m uvicorn app.main:app \
        --host "$HOST" \
        --port "$PORT" \
        > "$SCRIPT_DIR/webtty.log" 2>&1 &

    echo $! > "$PID_FILE"
    sleep 2

    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        log "Server started (PID: $(cat "$PID_FILE"))"
        echo ""
        echo -e "${CYAN}========================================${NC}"
        echo -e "${CYAN}  WebTTY is running!${NC}"
        echo -e "${CYAN}  Open: http://localhost:$PORT${NC}"
        echo -e "${CYAN}  Log:  $SCRIPT_DIR/webtty.log${NC}"
        echo -e "${CYAN}  Stop: ./deploy.sh --stop${NC}"
        echo -e "${CYAN}========================================${NC}"
    else
        err "Server failed to start. Check log:"
        tail -20 "$SCRIPT_DIR/webtty.log"
        exit 1
    fi
}

stop_server() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping server (PID: $pid)..."
            kill "$pid"
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
            log "Server stopped."
        fi
        rm -f "$PID_FILE"
    fi
}

docker_deploy() {
    if ! command -v docker >/dev/null 2>&1; then
        err "Docker is not installed."
        exit 1
    fi
    log "Building and starting Docker containers..."
    cd "$SCRIPT_DIR"
    docker compose up --build -d
    log "Docker containers started."
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  WebTTY is running!${NC}"
    echo -e "${CYAN}  Open: http://localhost:8000${NC}"
    echo -e "${CYAN}  Stop: docker compose down${NC}"
    echo -e "${CYAN}  Logs: docker compose logs -f${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Main
case "${1:-}" in
    --docker)
        docker_deploy
        ;;
    --stop)
        stop_server
        ;;
    --help|-h)
        echo "Usage:"
        echo "  ./deploy.sh              Build frontend + start backend server"
        echo "  ./deploy.sh --docker     Deploy via Docker Compose"
        echo "  ./deploy.sh --stop       Stop the running server"
        echo ""
        echo "Environment variables:"
        echo "  WEBTTY_HOST          Bind address (default: 0.0.0.0)"
        echo "  WEBTTY_PORT          Listen port  (default: 8000)"
        echo "  WEBTTY_SECRET_KEY    JWT secret   (default: auto-generated)"
        echo "  WEBTTY_DATABASE_URL  Database URL (default: SQLite in data/)"
        ;;
    *)
        check_deps
        build_frontend
        setup_backend
        start_server
        ;;
esac
