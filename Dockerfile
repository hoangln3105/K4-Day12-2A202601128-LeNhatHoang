# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (bản production-ready)
#
# Build:  docker build -t day12-chat:prod .
# Xem cỡ: docker images day12-chat:prod
# ═══════════════════════════════════════════════════════════════════

# ─── Stage 1: builder ───────────────────────────────────────────────
# Cài dependency ở đây. Stage này mang theo pip, cache wheel và mọi thứ
# cần để build package có phần C — không thứ nào trong số đó cần cho lúc
# chạy, nên nó sẽ bị vứt lại phía sau.
FROM python:3.11-slim AS builder

WORKDIR /app

# COPY requirements.txt TRƯỚC source code: layer pip install chỉ bị
# rebuild khi file này đổi. Sửa một dòng trong app/ không phải cài lại
# toàn bộ thư viện.
COPY requirements.txt .

# --user: cài vào /root/.local để copy sang stage sau bằng đúng một lệnh.
# --no-cache-dir: không giữ lại cache wheel, image nhỏ hơn.
RUN pip install --no-cache-dir --user -r requirements.txt

# ─── Stage 2: runtime ───────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# PYTHONDONTWRITEBYTECODE: không sinh .pyc trong container
# PYTHONUNBUFFERED: log ra stdout ngay, không kẹt trong buffer khi
#   stdout là pipe — mất log là mất luôn manh mối lúc container chết
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/appuser/.local/bin:$PATH \
    PORT=8000

# curl cho HEALTHCHECK; xoá apt list ngay trong cùng một layer để phần
# rác đó không nằm lại trong image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Tạo user thường TRƯỚC khi copy, để copy thẳng vào đúng chủ sở hữu.
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Chỉ lấy thư viện đã cài từ builder — không kéo theo pip cache,
# không compiler, không header file.
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# Source code copy SAU pip install: đây là thứ đổi thường xuyên nhất,
# đặt ở layer cuối để cache của các layer trên còn dùng lại được.
COPY --chown=appuser:appuser app/ ./app/
COPY --chown=appuser:appuser utils/ ./utils/

# Từ dòng này trở đi container chạy bằng user thường. Kẻ tấn công thoát
# được khỏi code Python cũng chỉ có quyền của appuser.
USER appuser

EXPOSE 8000

# $PORT do platform gán (Railway/Render/Cloud Run), mặc định 8000.
# Dạng shell form để biến môi trường được nội suy.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/healthz" || exit 1

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
