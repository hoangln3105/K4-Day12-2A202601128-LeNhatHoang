# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị token vào đây.**
> Repo này công khai — dán token vào là mất token.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Lê Nhật Hoàng |
| Mã học viên | 2A202601128 |
| Repo | https://github.com/hoangln3105/K4-Day12-2A202601128-LeNhatHoang |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://dien-vao-sau-khi-deploy.onrender.com |
| Platform | Render (web service chạy Docker + Key Value instance làm Redis) |
| Ngày deploy | 10/08/2026 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `API_TOKEN` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Key Value instance `day12-chat-redis` của Render, nối tự động qua `fromService` trong `render.yaml` — không gõ tay |
| `BUCKET_CAPACITY` | ✅ | 10 |
| `REFILL_PER_MINUTE` | ✅ | 10 |
| `DAILY_BUDGET_USD` | ✅ | 1.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/healthz

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/readyz

# 3. Không có token — mong đợi 401 kèm header WWW-Authenticate
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello"}'

# 4. Có token — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "X-Client-Id: sv-test" \
  -d '{"message":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/chat \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "X-Client-Id: sv-test" \
    -d '{"message":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Dán output của các lệnh trên vào đây:

```
(dán output thật vào đây sau khi deploy — xem hướng dẫn cuối file)
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/healthz.png` — kết quả gọi `/healthz` từ trình duyệt hoặc curl

---

## Các Bước Đã Làm Trên Render

1. Push repo lên GitHub (repo public).
2. Trên Render: **New → Blueprint**, chọn repo này. Render đọc `render.yaml`
   và dựng sẵn 2 thành phần: web service `day12-chat` (runtime Docker) và
   Key Value instance `day12-chat-redis`.
3. Render hỏi giá trị `API_TOKEN` (khai báo `sync: false` nên nó không nằm
   trong repo). Dán token sinh bằng
   `python -c "import secrets; print(secrets.token_urlsafe(32))"`.
4. `REDIS_URL` **không** phải gõ tay: `fromService` trong `render.yaml` tự
   lấy connection string của Key Value instance.
5. Đợi build xong, lấy Public URL rồi điền vào bảng Service ở trên.
6. Chạy các lệnh ở mục "Lệnh Kiểm Tra", dán kết quả vào mục "Kết Quả Chạy Thật".

**Lưu ý về free tier:** service ngủ đông sau ~15 phút không có traffic, nên
request đầu tiên có thể mất 30–60 giây để đánh thức. Test CP5 đã để timeout
60 giây cho lần gọi đầu nên vẫn qua. Key Value bản free lưu dữ liệu trong RAM
— restart là mất lịch sử hội thoại, chấp nhận được với bài lab này.
