# Kairō backend (Capture → Structure → Storage → Retrieval + Proactive + Sync).
# Heavier image (ChromaDB, faster-whisper). Needs an Ollama endpoint — provided
# by the `ollama` service in docker-compose.yml (set OLLAMA_HOST accordingly).
FROM python:3.12-slim

# ffmpeg is needed to decode browser/mobile audio for transcription.
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv
WORKDIR /app

# Install dependencies from pyproject (cached layer).
COPY pyproject.toml README.md ./
COPY backend ./backend
RUN uv pip install --system .

COPY frontend ./frontend
COPY syncserver ./syncserver

ENV KAIRO_HOME=/data \
    OLLAMA_HOST=http://ollama:11434
VOLUME ["/data"]
EXPOSE 8000

CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000"]
