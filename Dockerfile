# Stage 1: Build frontend
FROM node:20-alpine AS frontend-builder
WORKDIR /build
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci --prefer-offline 2>/dev/null || npm install
COPY frontend/ ./
RUN npm run build

# Stage 2: Production backend
FROM python:3.12-slim AS runtime

# Install system dependencies for PTY support
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh \
    bash \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source
COPY backend/app/ ./app/

# Copy built frontend
COPY --from=frontend-builder /build/dist /app/frontend/dist

# Create data directories
RUN mkdir -p /app/data /app/uploads

# Environment
ENV MEBTTY_STATIC_DIR=/app/frontend/dist
ENV MEBTTY_DATABASE_URL=sqlite+aiosqlite:////app/data/mebtty.db
ENV MEBTTY_UPLOAD_DIR=/app/uploads

EXPOSE 18888

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "18888"]
