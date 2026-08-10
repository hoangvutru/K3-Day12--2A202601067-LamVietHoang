# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Lâm Việt Hoàng |
| Mã học viên | 2A202601067 |
| Repo | https://github.com/hoangvutru/K3-Day12--2A202601067-LamVietHoang |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-9f60.onrender.com |
| Platform | Render (Blueprint từ render.yaml — web service + Key Value Redis) |
| Ngày deploy | 2026-08-10 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Key Value `day12-redis` của Render, nối tự động qua fromService trong render.yaml |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Dán output của các lệnh trên vào đây:

```
# 1. GET /health
{"status":"ok","service":"day12-agent","version":"1.0.0"}

# 2. GET /ready
{"status":"ready","redis":true}

# 3. POST /ask không có API key -> 401
HTTP/1.1 401 Unauthorized
{"detail":"Missing or invalid API key"}

# 4. POST /ask có API key hợp lệ -> 200
HTTP/1.1 200 OK
{"answer":"...","user_id":"sv-test","history_length":2,"cost_usd":...,"tokens":...}

# 5. Rate limit: gọi 15 lần, những lần vượt hạn mức trả 429
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429

Kết quả pytest tests/test_cp5.py:
- test_url_dung_https ................. PASSED
- test_health_tra_ve_200 ............. PASSED
- test_ready_tra_ve_200 .............. PASSED
- test_ask_yeu_cau_xac_thuc .......... PASSED
- test_ask_hoat_dong_voi_key_that .... PASSED
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform (Render, "Deploy live")
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt
- `screenshots/ready.png` — kết quả gọi `/ready` (`redis:true`)

> Đã deploy lên cloud thật (Render), không dùng phương án dự phòng local.
