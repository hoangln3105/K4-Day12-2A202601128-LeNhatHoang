# Phiếu Phản Ánh — K4 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Lê Nhật Hoàng  Mã học viên: 2A202601128

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `api_token` không có giá trị mặc định nên app chết ngay khi
khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà việc
"chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống này xảy ra khi deploy lên Render ở CP5. Blueprint khai
> `API_TOKEN` với `sync: false`, đáng lẽ Render phải hỏi giá trị lúc tạo
> service, nhưng bước đó bị bỏ qua nên trên cloud không có biến này.
>
> Vì `api_token` không có mặc định, `Settings()` ném `ValidationError`:
>
> ```
> pydantic_core.ValidationError: 1 validation error for Settings
> api_token
>   Field required [type=missing, input_value={'port': '10000', 'redis_...}]
> ```
>
> Nếu đặt `api_token: str = "changeme"` thì service vẫn khởi động bình
> thường, `/healthz` vẫn trả 200, dashboard vẫn báo trạng thái live. Kết quả
> là một API công khai mà bất kỳ ai gõ đúng chuỗi `changeme` cũng gọi được.
> Chuỗi đó nằm sẵn trong `.env.example` trên GitHub nên không cần đoán. Lỗi
> chỉ bị phát hiện khi hóa đơn tăng hoặc log đầy request lạ, tức là sau khi
> thiệt hại đã xảy ra.
>
> Một quan sát thêm khi debug: cơ chế fail-fast ở đây lộ ra muộn hơn mong
> đợi. App vẫn boot được vì `get_settings()` có `@lru_cache` và chỉ chạy lần
> đầu khi có request cần tới nó, trong khi `lifespan` chỉ gọi `arm()` và
> `emit()`, không đụng tới `Settings`. Do đó `/healthz` (không có dependency)
> vẫn trả 200, chỉ `/readyz` mới lộ lỗi vì nó phải giải `Depends(get_store)`.
> Muốn dừng ngay lúc khởi động thì phải gọi `get_settings()` trong
> `lifespan`. Dù vậy, việc không có giá trị mặc định vẫn đạt mục đích chính:
> service không bao giờ chạy được với một token ai cũng biết.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/chat` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thu được khi gọi `/chat` trên bản deploy Render:
>
> ```json
> {"event": "chat_completed", "severity": "INFO", "ts": "2026-08-10T08:20:14.882431+00:00", "client_id": "sv-test", "prompt_tokens": 3, "completion_tokens": 37, "usd_cost": 2.265e-05}
> ```
>
> Việc 1 — lọc và tổng hợp theo trường. Mỗi thông tin là một field riêng nên
> có thể truy vấn `severity="ERROR" AND client_id="sv-test"` để xem riêng lỗi
> của một client, hoặc cộng `usd_cost` của cả ngày để biết mức chi tiêu. Với
> `print("đã trả lời xong")` thì chỉ có một chuỗi văn bản, muốn biết client
> nào tiêu bao nhiêu phải đọc thủ công.
>
> Việc 2 — đặt cảnh báo tự động. Có thể tạo alert dạng "nếu tổng `usd_cost`
> trong 1 giờ vượt 0.5 thì gửi thông báo", vì `usd_cost` là kiểu số chứ không
> phải chuỗi. Dòng `print` không chứa giá trị nào để so sánh nên không đặt
> được ngưỡng.
>
> Ngoài ra `ts` theo ISO-8601 kèm múi giờ UTC giúp log của nhiều container
> ghép lại vẫn sắp đúng thứ tự thời gian.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t chat:single .
docker build -t chat:multi .
docker images | grep chat
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1800 MB (theo mô tả trong Dockerfile gốc) |
| Multi-stage | **289 MB** (đo thật bằng `docker images`) |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Con số 289MB là kết quả đo trực tiếp:
>
> ```
> $ docker images day12-chat:cp2-test --format "{{.Size}}"
> 289MB
> ```
>
> Bản 1 stage không build lại được vì mạng đứt khi kéo image `python:3.11`
> từ Docker Hub (lỗi `EOF` giữa chừng, thử 2 lần đều hỏng), nên con số
> ~1.8GB là lấy theo mô tả trong Dockerfile gốc chứ không phải số tự đo.
>
> Phần chênh lệch khoảng 1.5GB đến từ hai nguồn.
>
> Thứ nhất là base image. `python:3.11` bản đầy đủ khoảng 1GB vì mang theo
> bộ công cụ biên dịch: gcc, make, header file của C, git và nhiều thư viện
> phát triển. `python:3.11-slim` chỉ khoảng 120MB vì bỏ hết những thứ đó,
> giữ lại Python cùng vài thư viện tối thiểu để chạy.
>
> Thứ hai là phần dư của bước cài đặt. Ở bản 1 stage, `pip install` để lại
> cache wheel và file tạm ngay trong image. Bản multi-stage cài bằng
> `pip install --no-cache-dir --user` ở stage `builder`, rồi stage runtime
> chỉ `COPY --from=builder /root/.local` sang. Chỉ thư viện đã cài xong được
> mang qua, còn pip cache và công cụ build nằm lại ở stage builder và không
> xuất hiện trong image cuối.
>
> Image nhỏ không chỉ tiết kiệm dung lượng lưu trữ. Nó còn rút ngắn thời
> gian deploy do phải đẩy và kéo ít byte hơn, đồng thời thu hẹp bề mặt tấn
> công: không có gcc trong image thì kẻ tấn công cũng khó biên dịch exploit
> ngay tại chỗ.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Thử nghiệm: sửa `SERVICE_VERSION` từ `"1.0.0"` thành `"1.0.1"` trong
> `app/main.py` rồi build lại. Kết quả:
>
> Các layer được dùng lại từ cache (đều báo `CACHED`):
> ```
> [builder 2/4] WORKDIR /app                                      CACHED
> [builder 3/4] COPY requirements.txt .                            CACHED
> [builder 4/4] RUN pip install --no-cache-dir --user -r ...       CACHED
> [runtime 2/7] RUN apt-get install curl ...                       CACHED
> [runtime 3/7] RUN useradd --create-home --uid 10001 appuser      CACHED
> [runtime 4/7] WORKDIR /app                                       CACHED
> [runtime 5/7] COPY --from=builder ... /home/appuser/.local       CACHED
> ```
>
> Layer phải chạy lại: chỉ hai layer cuối là `COPY app/ ./app/` và
> `COPY utils/ ./utils/`. Build lại hoàn tất trong khoảng 3 giây.
>
> Lý do là Docker cache theo từng layer, và một layer hỏng cache thì mọi
> layer sau nó cũng hỏng theo. Vì `COPY requirements.txt` đứng trước và file
> đó không đổi, layer `pip install` vẫn giữ nguyên giá trị cache. Source code
> được copy ở layer cuối cùng, đúng vị trí của thứ thay đổi thường xuyên nhất.
>
> Nếu đặt `COPY . .` lên trước `RUN pip install`, mỗi lần sửa một ký tự trong
> bất kỳ file nào cũng làm layer `COPY` đổi, kéo theo layer `pip install`
> phía sau mất cache và phải cài lại toàn bộ 31 thư viện từ đầu. Thay vì 3
> giây, mỗi lần build mất vài phút. Nhân với số lần build trong một buổi làm
> việc thì lượng thời gian mất đi là đáng kể, và trên CI/CD còn phát sinh
> thêm chi phí máy chạy.
>
> Nguyên tắc rút ra: xếp layer theo thứ tự từ ít thay đổi nhất tới hay thay
> đổi nhất, tức là base image → thư viện hệ thống → dependency Python →
> source code.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Kiểm chứng container chạy bằng user thường:
>
> ```
> $ docker run --rm day12-chat:cp2-test id
> uid=10001(appuser) gid=10001(appuser) groups=10001(appuser)
> ```
>
> Chuỗi sự kiện nếu container chạy bằng root:
>
> 1. Code Python có lỗ hổng, ví dụ một chỗ nhận dữ liệu người dùng rồi đưa
>    vào `eval()`, `subprocess`, hoặc thư viện deserialize không an toàn.
> 2. Kẻ tấn công gửi payload khai thác lỗ hổng đó và chạy được lệnh tùy ý
>    bên trong container, với quyền của process, tức là quyền root.
> 3. Với quyền root trong container, họ đọc và ghi được mọi file kể cả
>    `/etc`, cài thêm công cụ, đọc biến môi trường chứa secret, ghi vào
>    volume được mount từ host, và có đủ quyền để thử các kỹ thuật thoát
>    container như lạm dụng capability, mount `/proc`, hoặc khai thác lỗ
>    hổng kernel và runtime.
> 4. Vì container dùng chung kernel với host, thoát ra thành công đồng nghĩa
>    với việc có quyền root trên máy host, nơi thường chạy nhiều container
>    của các dịch vụ khác.
>
> Lệnh `USER` cắt chuỗi này ở bước 3. Sau `USER appuser`, code chạy với uid
> 10001 nên kẻ tấn công vào được cũng chỉ có quyền của một user thường:
> không ghi được `/etc`, không cài được gói, không bind được cổng dưới 1024,
> và thiếu hầu hết capability cần cho việc thoát container. Bước 1 và 2 vẫn
> xảy ra vì `USER` không vá lỗ hổng code, nhưng thiệt hại bị giới hạn trong
> phạm vi container thay vì lan ra host.
>
> Đây là nguyên tắc defense in depth: giả định lớp bảo vệ trước đó sẽ thủng
> và dựng sẵn lớp tiếp theo để hạn chế hậu quả. Việc dùng base image slim
> cũng góp phần tương tự, vì không có gcc trong image thì kẻ tấn công khó
> biên dịch exploit ngay tại chỗ.

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

> Header `WWW-Authenticate` là yêu cầu của chuẩn HTTP (RFC 7235). Response
> 401 chỉ nói rằng client chưa xác thực, còn header này trả lời câu hỏi tiếp
> theo là xác thực bằng cách nào. Nhờ đó client biết phải gửi token theo
> scheme Bearer chứ không phải Basic hay Digest, và thư viện HTTP đọc được
> để xử lý đúng thay vì phải tra tài liệu riêng của từng API.
>
> Kiểm chứng trên bản deploy:
> ```
> $ curl -i -X POST https://day12-chat-wt2j.onrender.com/chat \
>     -H "Content-Type: application/json" -d '{"message":"Hello"}'
> HTTP/1.1 401 Unauthorized
> www-authenticate: Bearer
> ```
>
> Về việc dùng chung một thông báo cho cả ba trường hợp: phân biệt rõ lỗi
> nào sẽ giúp người đang dò tìm thu hẹp phạm vi. Nếu trả lời khác nhau:
>
> - "thiếu header" cho biết cần thêm header
> - "sai scheme" cho biết đã đúng cách gửi, chỉ còn phải đoán token
> - "token không đúng" cho biết scheme đã chuẩn, chỉ sai giá trị
>
> Mỗi thông báo chi tiết là một manh mối được cung cấp miễn phí. Khi cả ba
> trường hợp trả về giống hệt nhau, kẻ tấn công không xác định được mình sai
> ở khâu nào và phải dò một không gian lớn hơn nhiều.
>
> Đánh đổi là lập trình viên hợp lệ cũng khó debug hơn. Tuy nhiên người dùng
> hợp lệ có tài liệu API và token trong tay, còn kẻ tấn công thì không, nên
> đánh đổi này chấp nhận được. Trong code, cả ba nhánh dùng chung một object
> `unauthorized` để đảm bảo nội dung không vô tình khác nhau.

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

> Thay vì tính nhẩm, kết quả dưới đây lấy từ một script chạy thử cả hai
> phiên bản:
>
> ```
> CO min(): gui duoc 10 request roi 429
> BO min(): gui duoc 109 request roi 429
> ```
>
> Có `min(capacity, ...)` thì gửi được 10 request. Client im lặng 10 phút về
> lý thuyết tích được 10 phút × 10 token/phút = 100 token, nhưng `min()` cắt
> xuống đúng sức chứa của xô là 10. Đây là ý nghĩa của khái niệm sức chứa:
> xô đầy rồi thì token nhỏ thêm vào sẽ tràn ra ngoài, không tích lại được.
>
> Bỏ `min()` thì con số là 109, cao hơn mức 100 mà phép tính đơn giản dự
> đoán. Nguyên nhân là ngoài 100 token tích được trong 10 phút, token vẫn
> tiếp tục nhỏ vào trong lúc client đang gửi, vì mỗi lần `consume` đều cập
> nhật `ts` và tính lại phần nạp thêm.
>
> Con số này còn tăng theo thời gian im lặng. Nếu client im lặng một ngày
> thì tích được 14.400 token và có thể gửi hết trong vài giây, thường rơi
> vào thời điểm hệ thống không lường trước. Rate limit khi đó gần như mất
> tác dụng.
>
> Như vậy dòng `min()` là ranh giới giữa việc cho phép burst ở mức hợp lý,
> phản ánh thói quen người dùng thật hay im một lúc rồi thao tác liên tiếp,
> và việc không giới hạn gì cả. Sức chứa của xô chính là mức burst tối đa
> mà hệ thống chấp nhận.

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

> Với hạn mức $30/tháng: sự cố bắt đầu lúc 2h sáng ngày 1, không có ai trực
> để phát hiện. Client gọi liên tục và tiêu hết $30, có thể chỉ trong vài
> giờ nếu tần suất cao. Thiệt hại tối đa là $30, tức toàn bộ ngân sách
> tháng. Sau đó service trả 402 cho client này và chỉ hồi phục vào ngày 1
> tháng sau. Nếu đây là client thật thì họ mất dịch vụ gần 30 ngày vì một
> sự cố kéo dài vài giờ.
>
> Với hạn mức $1/ngày: cùng sự cố đó, client tiêu tối đa $1 rồi bị chặn.
> Service tự hồi phục lúc 00:00 UTC hôm sau, không cần can thiệp thủ công.
> Nếu sự cố vẫn tiếp diễn thì mỗi ngày mất thêm $1, nhưng khoảng thời gian
> một ngày là đủ để phát hiện và xử lý trước khi tổng thiệt hại lớn lên.
>
> Bảng so sánh:
>
> | | $30/tháng | $1/ngày |
> |---|---|---|
> | Thiệt hại tối đa một sự cố | $30 | $1 |
> | Thời gian gián đoạn | tới 30 ngày | tới 24 giờ |
> | Cần người can thiệp | Có | Không |
>
> Điểm đáng chú ý là tổng ngân sách cả tháng gần như bằng nhau ($30 so với
> $1 × 30 = $30), nhưng cách chia nhỏ theo ngày làm thiệt hại tối đa của
> một sự cố giảm 30 lần và thời gian gián đoạn giảm từ hàng tuần xuống hàng
> giờ. Cùng một mức chi, nhưng hồ sơ rủi ro khác hẳn.
>
> Trong code, key Redis có dạng `spend:{client_id}:{ngày}` kèm TTL 3 ngày,
> nên hạn mức tự reset theo ngày UTC mà không cần job dọn dẹp.

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Thứ tự sự kiện nếu gộp hai endpoint và cho nó kiểm tra Redis:
>
> 1. t=0s — Redis mất kết nối. Cả 3 container cùng gọi Redis thất bại nên
>    health check của cả 3 cùng trả lỗi. Điểm mấu chốt là chúng hỏng đồng
>    thời, vì cùng phụ thuộc một Redis.
> 2. t≈5–15s — Sau vài lần probe liên tiếp thất bại, platform kết luận 3
>    process này đã chết và gửi SIGTERM để restart toàn bộ cụm.
> 3. t≈20s — Container mới khởi động nhưng Redis vẫn chưa lên. Health check
>    lại thất bại, container lại bị đánh dấu chết và restart tiếp. Cụm rơi
>    vào vòng lặp crash-restart.
> 4. t=30s — Redis lên lại. Tuy nhiên cụm vẫn đang trong chu kỳ restart nên
>    container phải khởi động lại từ đầu, gồm kéo image, boot app và chờ
>    probe lần đầu, do đó chưa phục vụ được ngay.
> 5. t≈60–90s — Cụm ổn định trở lại.
>
> Kết quả là một sự cố lẽ ra chỉ làm mất tính năng lưu lịch sử trong 30 giây
> đã trở thành gián đoạn toàn bộ dịch vụ trong 1–2 phút, kể cả những request
> không cần tới Redis.
>
> Nếu tách hai endpoint theo đúng yêu cầu của bài lab:
>
> - `/healthz` không truy cập Redis nên vẫn trả 200 suốt, không container
>   nào bị restart vì process thực sự vẫn hoạt động bình thường.
> - `/readyz` kiểm tra Redis nên trả 503, load balancer tạm ngừng đẩy traffic
>   vào nhưng không dừng container.
> - Redis lên lại ở t=30s, `/readyz` trả 200 ngay lần probe kế tiếp và cụm
>   phục vụ tiếp mà không cần khởi động lại.
>
> Hai endpoint tồn tại riêng vì chúng trả lời hai câu hỏi khác nhau:
> `/healthz` trả lời "có cần restart tiến trình này không", còn `/readyz`
> trả lời "có nên gửi request tới instance này lúc này không". Gộp lại là
> biến câu trả lời "tạm thời chưa sẵn sàng" thành "hãy khởi động lại tôi",
> trong khi restart không giải quyết được vấn đề nằm ở Redis.
>
> Trong code, `/healthz` được viết không nhận tham số nào để đảm bảo nó
> không vô tình phụ thuộc dependency qua `Depends()`.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Triệu chứng: Render báo service đã live, `/healthz` trả 200, `/chat` không
> token trả 401 đúng như mong đợi, nhìn qua thì mọi thứ đều bình thường.
> Tuy nhiên `/readyz` trả 500 Internal Server Error, trong khi code chỉ có
> thể trả 200 hoặc 503. Điều đó nghĩa là exception xảy ra trước khi vào được
> thân hàm.
>
> Thông báo lỗi lấy từ tab Logs trên dashboard Render:
>
> ```
> File "/app/app/main.py", line 44, in get_store
>     return ChatStore(get_redis_client())
> File "/app/app/store.py", line 28, in get_redis_client
>     url = url or get_settings().redis_url
> File "/app/app/config.py", line 64, in get_settings
>     return Settings()
> pydantic_core.ValidationError: 1 validation error for Settings
> api_token
>   Field required [type=missing, input_value={'port': '10000', 'redis_...}]
> ```
>
> Cách tìm ra nguyên nhân: hai giả thuyết ban đầu đều sai, gồm giả thuyết
> Redis cần TLS (`rediss://`) và giả thuyết web service với Key Value bị
> lệch region. Chỉ khi mở tab Logs và đọc traceback mới xác định được nguyên
> nhân thật là thiếu biến `API_TOKEN` trên cloud. Chi tiết `input_value`
> trong thông báo lỗi cho thấy Render đã truyền đầy đủ `port`, `redis_url`,
> `log_level` và chỉ thiếu `api_token`, nghĩa là Redis không có vấn đề gì.
>
> Nguyên nhân gốc là `render.yaml` khai `API_TOKEN` với `sync: false` để
> không lưu secret vào repo. Render đáng lẽ phải hỏi giá trị lúc tạo
> Blueprint nhưng bước đó bị bỏ qua.
>
> Có hai yếu tố khiến lỗi này khó nhận ra và dẫn tới các giả thuyết sai:
>
> 1. App không crash lúc khởi động dù thiếu secret, vì `get_settings()` có
>    `@lru_cache` và chỉ chạy lần đầu khi có request cần tới. `lifespan` chỉ
>    gọi `arm()` và `emit()`, không đụng tới `Settings`.
> 2. `/chat` không token vẫn trả 401 đúng chuẩn, vì `verify_bearer_token`
>    raise ở nhánh `if not authorization` trước khi đọc settings. Mã 401 này
>    dễ bị hiểu nhầm là bằng chứng token đã được cấu hình đúng.
>
> Chỉ `/readyz` lộ ra lỗi, vì đây là endpoint đầu tiên bắt buộc phải giải
> `Depends(get_store)` → `get_redis_client()` → `get_settings()`.
>
> Cách sửa: vào tab Environment của service trên Render, thêm biến
> `API_TOKEN` với giá trị sinh bằng `secrets.token_urlsafe(32)` rồi lưu lại.
> Render tự redeploy, sau đó `/readyz` trả `{"status":"ready","redis":true}`.
>
> Hai điểm rút ra. Thứ nhất, không nên suy đoán nguyên nhân từ triệu chứng
> bên ngoài khi đã có sẵn log, vì traceback chỉ thẳng vào dòng gây lỗi trong
> khi việc đoán TLS rồi region chỉ làm mất thời gian. Thứ hai, cơ chế
> fail-fast chỉ thực sự nhanh khi thứ cần kiểm tra được gọi lúc khởi động;
> dependency giải lười làm lỗi lộ ra muộn, nên muốn dừng ngay lúc boot thì
> phải gọi `get_settings()` trong `lifespan`.
