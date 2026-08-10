# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Dưới đây là Dockerfile "chạy được nhưng chưa production": một stage,
# chạy bằng user root, không có health check, base image nặng.
#
# NHIỆM VỤ: sửa file này thành bản production-ready. Yêu cầu:
#   [ ] Multi-stage build: stage `builder` cài dependency, stage runtime
#       chỉ copy kết quả sang → image nhỏ hơn, không mang theo compiler.
#       Cú pháp: `FROM python:3.11-slim AS builder`
#   [ ] Base image slim (hoặc alpine), không dùng `python:3.11` bản đầy đủ
#   [ ] COPY requirements.txt và pip install TRƯỚC khi COPY source code
#       (Docker cache theo layer: sửa 1 dòng code không phải cài lại thư viện)
#   [ ] Tạo user thường và chuyển sang bằng lệnh `USER` — container chạy
#       root nghĩa là ai thoát được khỏi app cũng thành root trên host
#   [ ] Có `HEALTHCHECK` gọi vào endpoint /health
#   [ ] Đọc cổng từ biến môi trường PORT (cloud tự gán cổng, không cố định 8000)
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ─── Stage 1: builder — cài dependency (được phép nặng, sẽ bị vứt đi) ───
FROM python:3.11-slim AS builder

WORKDIR /app

# Copy requirements TRƯỚC để tận dụng cache: sửa code không phải cài lại thư viện
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ─── Stage 2: runtime — chỉ copy KẾT QUẢ sang, không mang theo compiler ───
FROM python:3.11-slim AS runtime

WORKDIR /app

# Lấy các package đã cài từ stage builder
COPY --from=builder /install /usr/local

# Copy source code SAU cùng (layer thay đổi thường xuyên nhất nằm cuối)
COPY app ./app
COPY utils ./utils

# Chạy bằng user thường, không phải root — thoát khỏi app không thành root trên host
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

# Docker tự biết container còn phục vụ được không, gọi vào /health
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import os, urllib.request; port=os.getenv('PORT','8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health', timeout=3)" || exit 1

# Đọc cổng từ $PORT (cloud tự gán), bind 0.0.0.0 để bên ngoài container gọi được
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
