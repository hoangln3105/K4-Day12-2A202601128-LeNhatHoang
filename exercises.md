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

> Em gặp đúng tình huống này khi deploy lên Render ở CP5. Blueprint khai
> `API_TOKEN` với `sync: false`, đáng lẽ Render phải hỏi giá trị lúc tạo
> service, nhưng bước đó bị bỏ qua nên trên cloud không có biến này.
>
> Vì `api_token` không có mặc định, `Settings()` ném `ValidationError` ngay:
>
> ```
> pydantic_core.ValidationError: 1 validation error for Settings
> api_token
>   Field required [type=missing, input_value={'port': '10000', 'redis_...}]
> ```
>
> Nếu em để `api_token: str = "changeme"` thì service vẫn khởi động bình
> thường, `/healthz` vẫn 200, Render vẫn báo "Your service is live 🎉" — và
> em sẽ đóng máy đi ngủ với một API công khai mà **bất kỳ ai gõ đúng chữ
> `changeme` cũng gọi được**. Chuỗi đó nằm sẵn trong file `.env.example`
> trên GitHub nên không cần đoán. Em chỉ phát hiện khi thấy hóa đơn hoặc
> log đầy request lạ, tức là sau khi thiệt hại đã xảy ra.
>
> Một điều em học thêm khi debug: fail-fast của em **lộ ra muộn hơn mong
> muốn**. App vẫn boot được vì `get_settings()` có `@lru_cache` và chỉ chạy
> lần đầu khi có request cần tới nó — mà `lifespan` chỉ gọi `arm()` với
> `emit()`, không đụng vào `Settings`. Nên `/healthz` (không có dependency)
> vẫn trả 200, chỉ `/readyz` mới lộ lỗi vì nó phải giải `Depends(get_store)`.
> Muốn chết đúng lúc khởi động thì phải gọi `get_settings()` ngay trong
> `lifespan`. Dù sao thì việc không có mặc định vẫn cứu em: service không
> bao giờ chạy được với một token ai cũng biết.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/chat` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log em lấy được khi gọi `/chat` trên bản deploy Render:
>
> ```json
> {"event": "chat_completed", "severity": "INFO", "ts": "2026-08-10T08:20:14.882431+00:00", "client_id": "sv-test", "prompt_tokens": 3, "completion_tokens": 37, "usd_cost": 2.265e-05}
> ```
>
> **Việc 1 — lọc và đếm theo trường.** Vì mỗi thông tin là một field riêng,
> em query được kiểu `severity="ERROR" AND client_id="sv-test"` để xem riêng
> lỗi của một client, hoặc cộng `usd_cost` của cả ngày để biết đã tiêu bao
> nhiêu tiền. Với `print("đã trả lời xong")` thì em chỉ có một chuỗi chữ,
> muốn biết client nào tiêu bao nhiêu phải ngồi đọc bằng mắt.
>
> **Việc 2 — đặt cảnh báo tự động.** Em có thể tạo alert kiểu "nếu tổng
> `usd_cost` trong 1 giờ vượt 0.5 thì gửi thông báo", vì `usd_cost` là số
> chứ không phải chữ. Dòng `print` không có số nào để so sánh nên không đặt
> ngưỡng được, chỉ có người đọc mới hiểu.
>
> Ngoài ra `ts` theo ISO-8601 có múi giờ UTC nên khi ghép log của nhiều
> container lại vẫn sắp đúng thứ tự thời gian.

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

> Số 289MB là em đo thật:
>
> ```
> $ docker images day12-chat:cp2-test --format "{{.Size}}"
> 289MB
> ```
>
> Bản 1 stage em không build lại được vì mạng đứt liên tục khi kéo image
> `python:3.11` từ Docker Hub (lỗi `EOF` giữa chừng, thử 2 lần đều hỏng),
> nên em ghi lại con số ~1.8GB mà đề bài nêu chứ không tự đo được.
>
> Phần chênh lệch khoảng 1.5GB đến từ hai nguồn:
>
> **1. Base image.** `python:3.11` bản đầy đủ khoảng 1GB vì mang theo cả bộ
> công cụ biên dịch: gcc, make, header file của C, git, và nhiều thư viện
> phát triển. `python:3.11-slim` chỉ khoảng 120MB vì bỏ hết những thứ đó,
> chỉ giữ lại Python và vài thư viện tối thiểu để chạy.
>
> **2. Rác của bước cài đặt.** Trong bản 1 stage, `pip install` để lại cache
> wheel và file tạm ngay trong image. Bản multi-stage của em cài bằng
> `pip install --no-cache-dir --user` ở stage `builder`, rồi stage runtime
> chỉ `COPY --from=builder /root/.local` sang. Nghĩa là chỉ có thư viện đã
> cài xong được mang qua, còn toàn bộ pip cache và công cụ build bị vứt lại
> ở stage builder — chúng không bao giờ xuất hiện trong image cuối.
>
> Điều em thấy đáng nhớ: image nhỏ không chỉ tiết kiệm ổ đĩa. Nó còn làm
> deploy nhanh hơn (đẩy/kéo ít byte hơn) và **an toàn hơn** — không có gcc
> trong image thì kẻ tấn công vào được cũng không biên dịch được exploit.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Em thử thật: sửa `SERVICE_VERSION` từ `"1.0.0"` thành `"1.0.1"` trong
> `app/main.py` rồi build lại. Kết quả:
>
> **Layer được dùng lại từ cache (đều báo `CACHED`):**
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
> **Layer phải chạy lại:** chỉ hai layer cuối là `COPY app/ ./app/` và
> `COPY utils/ ./utils/`. Build lại xong trong khoảng 3 giây.
>
> Lý do: Docker cache theo từng layer và **một layer hỏng cache thì mọi
> layer sau nó cũng hỏng theo**. Vì `COPY requirements.txt` đứng trước và
> file đó không đổi, nên layer `pip install` vẫn còn nguyên giá trị cache.
> Source code được copy ở layer cuối cùng — đúng chỗ, vì nó là thứ em sửa
> thường xuyên nhất.
>
> **Nếu đặt `COPY . .` lên trước `RUN pip install`:** mỗi lần sửa một ký tự
> trong bất kỳ file nào cũng làm layer `COPY` đổi, kéo theo layer
> `pip install` phía sau mất cache và phải **cài lại toàn bộ 31 thư viện**
> từ đầu. Thay vì 3 giây, mỗi lần build mất vài phút. Nhân với số lần build
> trong một buổi làm việc thì đó là rất nhiều thời gian bị đốt vô ích, và
> trên CI/CD thì còn tốn cả tiền máy chạy.
>
> Nguyên tắc em rút ra: **xếp layer theo thứ tự từ ít thay đổi nhất tới hay
> thay đổi nhất.** Base image → thư viện hệ thống → dependency Python →
> source code.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Em kiểm chứng container của mình chạy bằng user thường:
>
> ```
> $ docker run --rm day12-chat:cp2-test id
> uid=10001(appuser) gid=10001(appuser) groups=10001(appuser)
> ```
>
> **Chuỗi sự kiện nếu chạy bằng root:**
>
> 1. Code Python có lỗ hổng — ví dụ một chỗ nhận dữ liệu người dùng rồi đưa
>    vào `eval()`, `subprocess`, hoặc thư viện deserialize không an toàn.
> 2. Kẻ tấn công gửi payload khai thác lỗ hổng đó và chạy được lệnh tùy ý
>    **bên trong container**, với quyền của process — tức là **root**.
> 3. Là root trong container, họ làm được nhiều thứ: đọc/ghi mọi file kể cả
>    `/etc`, cài thêm công cụ, đọc biến môi trường chứa secret, ghi vào
>    volume được mount từ host, và quan trọng nhất là **có đủ quyền để thử
>    các kỹ thuật thoát container** (lạm dụng capability, mount `/proc`,
>    hoặc khai thác lỗ hổng kernel/runtime).
> 4. Vì container dùng chung kernel với host, thoát ra thành công nghĩa là
>    họ thành **root trên máy host** — và host thường chạy nhiều container
>    khác của nhiều dịch vụ khác.
>
> **`USER` cắt ở bước 3.** Sau `USER appuser`, code chạy với uid 10001 nên
> khi kẻ tấn công vào được thì họ chỉ có quyền của một user thường: không
> ghi được `/etc`, không cài được gói, không bind được cổng dưới 1024, và
> thiếu hầu hết capability cần cho việc thoát container. Bước 1 và 2 vẫn
> xảy ra — `USER` không vá lỗ hổng code — nhưng thiệt hại bị giới hạn trong
> container thay vì lan ra host.
>
> Đây là nguyên tắc **defense in depth**: giả định rằng lớp bảo vệ trước đó
> sẽ thủng, và dựng sẵn lớp tiếp theo để hạn chế hậu quả. Em cũng để ý là
> image slim còn giúp thêm ở đây — không có gcc trong image thì kẻ tấn công
> cũng khó biên dịch exploit ngay tại chỗ.

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

> **Vì sao 401 phải kèm `WWW-Authenticate: Bearer`:** đây là yêu cầu của
> chuẩn HTTP (RFC 7235). Response 401 nghĩa là "bạn chưa xác thực", và
> header này trả lời câu hỏi tiếp theo: *xác thực bằng cách nào*. Nhờ nó,
> client biết phải gửi token theo scheme Bearer chứ không phải Basic hay
> Digest — thư viện HTTP tự đọc được và xử lý đúng, không phải đoán mò hay
> đọc tài liệu riêng của từng API.
>
> Em kiểm chứng trên bản deploy:
> ```
> $ curl -i -X POST https://day12-chat-wt2j.onrender.com/chat \
>     -H "Content-Type: application/json" -d '{"message":"Hello"}'
> HTTP/1.1 401 Unauthorized
> www-authenticate: Bearer
> ```
>
> **Vì sao dùng chung một thông báo cho cả ba trường hợp:** vì nói rõ sai ở
> đâu là giúp người đang dò tìm thu hẹp phạm vi. Nếu em trả lời khác nhau:
>
> - "thiếu header" → họ biết cần thêm header
> - "sai scheme" → họ biết đã đúng cách gửi, **chỉ còn phải đoán token**
> - "token không đúng" → họ biết scheme đã chuẩn, chỉ sai giá trị
>
> Mỗi câu trả lời chi tiết là một manh mối miễn phí. Trả lời giống hệt nhau
> thì kẻ tấn công không phân biệt được mình sai ở khâu nào, phải dò cả không
> gian lớn hơn nhiều.
>
> Điều đánh đổi là lập trình viên thật cũng khó debug hơn. Nhưng người dùng
> hợp lệ có tài liệu API và token trong tay, còn kẻ tấn công thì không — nên
> cái giá đó đáng trả. Trong code em dùng đúng **một** object `unauthorized`
> dùng lại cho cả ba nhánh để chắc chắn không lỡ tay viết khác nhau.

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

> Em viết một script nhỏ chạy thử cả hai phiên bản thay vì chỉ tính nhẩm:
>
> ```
> CO min(): gui duoc 10 request roi 429
> BO min(): gui duoc 109 request roi 429
> ```
>
> **Có `min(capacity, ...)` → 10 request.** Client im lặng 10 phút thì về lý
> thuyết tích được 10 phút × 10 token/phút = 100 token, nhưng `min()` cắt
> xuống đúng sức chứa của xô là 10. Đây chính là ý nghĩa của "sức chứa":
> xô đầy rồi thì token nhỏ thêm vào sẽ tràn ra ngoài, không tích lại được.
>
> **Bỏ `min()` đi → 109 request.** Con số này em cũng bất ngờ, em tưởng
> khoảng 100. Chạy thử mới thấy: 100 token tích được trong 10 phút, cộng
> thêm phần token tiếp tục nhỏ vào **trong lúc đang bắn** — vì mỗi lần
> `consume` đều cập nhật `ts` và tính lại phần nạp thêm. Nên client bắn được
> nhiều hơn cả con số tích lũy ban đầu.
>
> Tệ hơn nữa: con số này tăng theo thời gian im lặng. Nếu client im lặng
> **một ngày** thì tích được 14.400 token và bắn hết trong vài giây — đúng
> lúc hệ thống không ngờ tới nhất. Rate limit khi đó gần như vô nghĩa.
>
> Vậy nên một dòng `min()` là thứ phân biệt giữa "cho phép burst hợp lý"
> (người dùng thật hay im một lúc rồi bấm vài lần liên tiếp) và "không giới
> hạn gì cả". Sức chứa xô chính là mức burst tối đa mà mình chấp nhận.

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

> **Hạn mức $30/tháng.** Sự cố bắt đầu 2h sáng ngày 1, không ai thức để phát
> hiện. Client gọi liên tục và đốt hết $30 — có thể chỉ trong vài giờ nếu
> gọi nhanh. Thiệt hại tối đa: **$30**, tức là toàn bộ ngân sách tháng. Sau
> đó service trả 402 cho client đó và **nằm im tới ngày 1 tháng sau** mới
> tự hồi phục. Nếu đây là client thật thì họ mất dịch vụ gần 30 ngày vì một
> sự cố kéo dài vài giờ.
>
> **Hạn mức $1/ngày.** Cùng sự cố đó, client đốt tối đa **$1** rồi bị chặn.
> Service tự hồi phục lúc **00:00 UTC hôm sau** — không cần ai can thiệp,
> không cần reset tay. Nếu sự cố vẫn tiếp diễn thì mỗi ngày mất thêm $1,
> nhưng mình có cả ngày để phát hiện và xử lý trước khi con số lớn lên.
>
> **So sánh:**
>
> | | $30/tháng | $1/ngày |
> |---|---|---|
> | Thiệt hại tối đa một sự cố | $30 | $1 |
> | Thời gian gián đoạn | tới 30 ngày | tới 24 giờ |
> | Cần người can thiệp | Có | Không |
>
> Điểm em thấy hay: **tổng ngân sách cả tháng gần như bằng nhau** ($30 so
> với $1 × 30 = $30), nhưng cách chia nhỏ theo ngày làm thiệt hại tối đa
> của một sự cố giảm 30 lần và thời gian gián đoạn giảm từ hàng tuần xuống
> hàng giờ. Cùng số tiền, nhưng rủi ro khác hẳn.
>
> Trong code em dùng key Redis dạng `spend:{client_id}:{ngày}` với TTL 3
> ngày, nên hạn mức tự reset theo ngày UTC mà không cần job dọn dẹp nào.

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> **Thứ tự sự kiện nếu gộp hai endpoint và cho nó check Redis:**
>
> 1. **t=0s** — Redis mất kết nối. Cả 3 container cùng gọi Redis thất bại,
>    nên health check của cả 3 cùng trả lỗi. Điểm mấu chốt: chúng hỏng
>    **đồng thời**, vì cùng phụ thuộc một Redis.
> 2. **t≈5–15s** — Sau vài lần probe liên tiếp thất bại, platform kết luận
>    "3 process này đã chết" và gửi SIGTERM để **restart toàn bộ cụm**.
> 3. **t≈20s** — Container mới khởi động, nhưng Redis vẫn chưa lên. Health
>    check lại thất bại → lại bị đánh dấu chết → lại restart. Cụm rơi vào
>    **vòng lặp crash-restart**.
> 4. **t=30s** — Redis lên lại. Nhưng cụm vẫn đang trong chu kỳ restart,
>    container phải khởi động lại từ đầu (kéo image, boot app, chờ probe
>    lần đầu), nên chưa phục vụ được ngay.
> 5. **t≈60–90s** — Cụm mới thật sự ổn định trở lại.
>
> **Kết quả:** một sự cố lẽ ra chỉ làm mất tính năng lưu lịch sử trong 30
> giây đã thành **sập toàn bộ dịch vụ trong 1–2 phút**, và tệ hơn là mất
> luôn cả những request không cần Redis.
>
> **Nếu tách đúng như bài lab yêu cầu:**
>
> - `/healthz` không đụng tới Redis → vẫn trả 200 suốt → **không container
>   nào bị restart**, process vẫn khỏe thật mà.
> - `/readyz` check Redis → trả 503 → load balancer tạm ngừng đẩy traffic
>   vào, nhưng không giết container.
> - Redis lên lại ở t=30s → `/readyz` trả 200 ngay lần probe kế tiếp → cụm
>   phục vụ tiếp, **không cần khởi động lại gì cả**.
>
> Em thấy đây là lý do hai endpoint tồn tại riêng: chúng trả lời hai câu
> hỏi khác nhau. `/healthz` = *"có cần restart tôi không?"*, `/readyz` =
> *"có nên gửi request cho tôi lúc này không?"*. Gộp lại là biến một câu trả
> lời "tạm thời chưa sẵn sàng" thành "hãy giết tôi đi" — mà restart thì
> không sửa được vấn đề nằm ở Redis.
>
> Trong code em còn để `/healthz` **không nhận tham số nào** để chắc chắn
> nó không vô tình phụ thuộc dependency nào qua `Depends()`.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Triệu chứng:** Render báo "Your service is live 🎉", `/healthz` trả 200,
> `/chat` không token trả 401 đúng như mong đợi — nhìn qua tưởng mọi thứ ổn.
> Nhưng `/readyz` trả **500 Internal Server Error**, trong khi code của em
> chỉ có thể trả 200 hoặc 503. Nghĩa là exception xảy ra **trước khi** vào
> được thân hàm.
>
> **Thông báo lỗi** (lấy từ tab Logs trên dashboard Render):
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
> **Cách tìm ra nguyên nhân:** ban đầu em đoán sai hai lần — nghĩ là Redis
> cần TLS (`rediss://`), rồi nghĩ là web service và Key Value bị lệch region.
> Cả hai đều sai. Chỉ khi mở **tab Logs** và đọc traceback thì mới thấy sự
> thật: **thiếu biến `API_TOKEN`** trên cloud. Chi tiết `input_value` trong
> lỗi còn cho thấy Render đã truyền `port`, `redis_url`, `log_level`... đầy
> đủ, chỉ thiếu đúng `api_token` — nên Redis vốn không có vấn đề gì cả.
>
> Nguyên nhân gốc: `render.yaml` khai `API_TOKEN` với `sync: false` để không
> lưu secret vào repo, đáng lẽ Render phải hỏi giá trị lúc tạo Blueprint,
> nhưng bước đó bị bỏ qua.
>
> **Hai thứ che lỗi này đi, khiến em đoán sai:**
>
> 1. App **không crash lúc khởi động** dù thiếu secret, vì `get_settings()`
>    có `@lru_cache` và chỉ chạy lần đầu khi có request cần tới. `lifespan`
>    chỉ gọi `arm()` và `emit()`, không đụng `Settings`.
> 2. `/chat` không token vẫn trả **401 đúng**, vì `verify_bearer_token` raise
>    ở nhánh `if not authorization` *trước khi* đọc settings. Em đã nhìn cái
>    401 đó và kết luận nhầm rằng token đã cấu hình đúng.
>
> Chỉ `/readyz` lộ ra lỗi, vì nó là endpoint đầu tiên bắt buộc phải giải
> `Depends(get_store)` → `get_redis_client()` → `get_settings()`.
>
> **Cách sửa:** vào tab Environment của service trên Render, thêm biến
> `API_TOKEN` với giá trị sinh bằng `secrets.token_urlsafe(32)`, lưu lại.
> Render tự redeploy. Sau đó `/readyz` trả `{"status":"ready","redis":true}`.
>
> **Bài học lớn nhất:** đừng suy đoán nguyên nhân từ triệu chứng bên ngoài
> khi có sẵn log. Em mất thời gian đoán TLS rồi region, trong khi traceback
> chỉ thẳng vào dòng lỗi ngay từ đầu. Bài học thứ hai: fail-fast chỉ "fast"
> khi thứ cần kiểm tra được gọi lúc khởi động — dependency giải lười (lazy)
> làm lỗi lộ ra muộn. Nếu muốn chết ngay lúc boot thì phải gọi
> `get_settings()` trong `lifespan`.
