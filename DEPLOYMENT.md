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
| Public URL | https://day12-chat-wt2j.onrender.com |
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

Chạy lúc 15:20 ngày 10/08/2026, URL `https://day12-chat-wt2j.onrender.com`:

```
# 1. Liveness
$ curl -s -w "\nHTTP %{http_code}\n" https://day12-chat-wt2j.onrender.com/healthz
{"status":"ok","service":"day12-chat-service","version":"1.0.0"}
HTTP 200

# 2. Readiness — redis:true nghĩa là đã nối được Key Value instance
$ curl -s -w "\nHTTP %{http_code}\n" https://day12-chat-wt2j.onrender.com/readyz
{"status":"ready","redis":true}
HTTP 200

# 3. Không có token → 401 kèm WWW-Authenticate
$ curl -s -i -X POST https://day12-chat-wt2j.onrender.com/chat \
    -H "Content-Type: application/json" -d '{"message":"Hello"}'
HTTP/1.1 401 Unauthorized
www-authenticate: Bearer
x-render-origin-server: uvicorn

# 4. Có token → 200. Gọi 2 lượt để chứng minh lịch sử nằm ở Redis:
#    turns_before 0 → 2, và mock LLM tự nhắc "nhớ 2 lượt trao đổi trước đó"
$ curl -s -X POST .../chat -H "Authorization: Bearer $API_TOKEN" \
    -H "X-Client-Id: sv-test" -d '{"message":"Deploy la gi?"}'
{"reply":"Ngắn gọn: Deploy la gi phụ thuộc vào ba yếu tố — cấu hình qua biến
môi trường, health check để orchestrator biết trạng thái, và giới hạn tài
nguyên.","client_id":"sv-test","turns_before":0,"usd_cost":2.265e-05,
"usage":{"prompt":3,"completion":37}}

$ curl -s -X POST .../chat -H "Authorization: Bearer $API_TOKEN" \
    -H "X-Client-Id: sv-test" -d '{"message":"Con Kubernetes?"}'
{"reply":"Với Con Kubernetes, cách làm phổ biến trong production là đặt một
lớp gateway phía trước để lo authentication, rate limiting và bảo vệ chi phí.
(Mình đang nhớ 2 lượt trao đổi trước đó.)","client_id":"sv-test",
"turns_before":2,"usd_cost":3.42e-05,"usage":{"prompt":44,"completion":46}}

# 5. Rate limit — 15 lần liên tiếp với BUCKET_CAPACITY=10
$ for i in $(seq 1 15); do curl -s -o /dev/null -w "%{http_code} " ... ; done
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429
```

Đúng 10 lần đầu qua (bằng `BUCKET_CAPACITY`), 5 lần sau bị chặn — token bucket
hoạt động trên cloud với state chia sẻ qua Redis.

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

## Lỗi Gặp Phải Khi Deploy

**Triệu chứng:** `/healthz` trả 200 và Render báo "Your service is live 🎉",
nhưng `/readyz` trả **500 Internal Server Error** — trong khi code chỉ có thể
trả 200 hoặc 503.

**Nguyên nhân:** đọc log trên Render thấy traceback:

```
File "/app/app/config.py", line 64, in get_settings
    return Settings()
pydantic_core.ValidationError: 1 validation error for Settings
api_token
  Field required [type=missing, input_value={'port': '10000', 'redis_...}]
```

Blueprint khai `API_TOKEN` với `sync: false`, đúng ra Render phải hỏi giá trị
lúc tạo, nhưng bước đó bị bỏ qua nên biến không tồn tại trên cloud.

**Vì sao khó phát hiện:** hai thứ che lỗi này đi.

1. App **không crash lúc khởi động** dù thiếu secret, vì `get_settings()` có
   `@lru_cache` và chỉ chạy lần đầu khi có request cần nó. `lifespan` chỉ gọi
   `arm()` và `emit()`, không đụng tới `Settings`.
2. `/chat` không token vẫn trả **401 đúng như mong đợi**, vì `verify_bearer_token`
   raise 401 ở nhánh `if not authorization` *trước khi* chạm tới `get_settings()`.
   Nhìn vào 401 đó dễ tưởng nhầm là token đã cấu hình đúng.

Chỉ `/readyz` lộ ra lỗi, vì nó là endpoint đầu tiên bắt buộc phải giải
`Depends(get_store)` → `get_redis_client()` → `get_settings()`.

**Cách sửa:** thêm `API_TOKEN` trong tab Environment của service trên Render,
lưu lại, Render tự redeploy. Sau đó `/readyz` trả `{"status":"ready","redis":true}`.

**Bài học:** fail-fast của CP1 vẫn cứu được (service không bao giờ chạy với token
mặc định), nhưng vì dependency được giải lười (lazy), lỗi lộ ra muộn hơn mong
muốn — lúc có request thật chứ không phải lúc boot. Muốn fail đúng lúc khởi động
thì gọi `get_settings()` ngay trong `lifespan`.

**Lưu ý về free tier:** service ngủ đông sau ~15 phút không có traffic, nên
request đầu tiên có thể mất 30–60 giây để đánh thức. Test CP5 đã để timeout
60 giây cho lần gọi đầu nên vẫn qua. Key Value bản free lưu dữ liệu trong RAM
— restart là mất lịch sử hội thoại, chấp nhận được với bài lab này.
