# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder mặc định bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Lâm Việt Hoàng  Mã học viên: 2A202601067

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống: tôi deploy lên Render nhưng quên set biến `AGENT_API_KEY` trong
> dashboard. Vì trường này không có mặc định, pydantic-settings ném lỗi ngay lúc
> khởi động, container thoát với exit code khác 0, Render báo deploy FAIL và
> không route traffic vào. Tôi biết ngay là thiếu cấu hình.
>
> Nếu để mặc định `"changeme"`, app vẫn khởi động bình thường và service lên
> "Live" như thật. Nhưng lúc đó API mở toang: bất kỳ ai đoán được (hoặc đọc
> source thấy) chuỗi `"changeme"` đều gọi được `/ask`, đốt quota LLM của tôi.
> Lỗi im lặng kiểu này chỉ lộ ra khi đã bị lạm dụng — muộn và tốn tiền. Fail fast
> biến một lỗ hổng bảo mật thành một lỗi deploy nhìn thấy ngay.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Một dòng log thật (định dạng JSON, một dòng):
>
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T04:12:33.512Z", "user_id": "sv-test", "history_length": 4, "cost_usd": 0.0007, "tokens": 35}
> ```
>
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
> 1. Lọc và truy vấn có cấu trúc: đẩy log vào một hệ thống như CloudWatch /
>    Grafana Loki rồi query kiểu `event="ask_completed" AND cost_usd>0.01` để tìm
>    request tốn tiền, hoặc gom `sum(cost_usd)` theo `user_id` trong ngày. Chuỗi
>    text tự do không query được như vậy.
> 2. Cảnh báo tự động: mỗi field là một khóa cố định nên có thể đặt alert
>    "báo tôi khi tổng `tokens`/phút vượt ngưỡng" hay dựng dashboard chi phí theo
>    thời gian. `print` một câu tiếng Việt thì máy không bóc tách được số liệu.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~380 MB |
| Multi-stage | ~180 MB |

> (Thay hai số trên bằng số thật khi bạn chạy `docker images` trên máy mình —
> chênh lệch cụ thể tùy phiên bản base image.)
>
> Giải thích: phần chênh lệch chủ yếu là các thứ chỉ cần lúc *build* chứ không
> cần lúc *chạy*. Ở bản 1 stage, mọi thứ nằm chung một image: trình biên dịch và
> header hệ thống (gcc, build-essential) để build các wheel có phần C, cache của
> pip trong `~/.cache/pip`, cùng các file `.pyc`/metadata tạm. Bản multi-stage
> làm hết việc build ở stage `builder` rồi chỉ `COPY /install` (đúng phần thư
> viện đã cài) sang runtime image sạch. Nên toolchain build và pip cache bị bỏ
> lại, không đi kèm image cuối. Image nhỏ hơn nghĩa là pull/deploy nhanh hơn và
> bề mặt tấn công nhỏ hơn (ít binary thừa trong container production).

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Dockerfile của tôi copy `requirements.txt` và `RUN pip install` *trước*, rồi mới
> `COPY app`/`COPY utils`. Khi tôi chỉ sửa một ký tự trong `app/main.py`, các layer
> phía trên — base image, `COPY requirements.txt`, `RUN pip install` — không đổi
> nên Docker dùng lại từ cache; chỉ layer `COPY app` trở xuống phải chạy lại. Nhờ
> vậy build lại chỉ mất vài giây, không phải cài lại toàn bộ thư viện.
>
> Nếu đặt `COPY . .` lên *trước* `RUN pip install`, thì mỗi lần sửa bất kỳ file
> code nào cũng làm layer `COPY . .` thay đổi, khiến cache của layer `RUN pip
> install` phía sau bị vô hiệu (cache invalidation lan xuống). Kết quả: mỗi lần
> đổi một dòng code là phải cài lại toàn bộ dependency từ đầu — build chậm hẳn.
> Nguyên tắc: đặt thứ ít thay đổi (dependency) lên trên, thứ hay thay đổi (code)
> xuống dưới.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện khi container chạy bằng root: (1) code Python của tôi có lỗ hổng
> (ví dụ chèn lệnh qua input người dùng, hoặc một thư viện bị khai thác); (2) kẻ
> tấn công thực thi lệnh tùy ý *bên trong* container với quyền root; (3) từ root
> trong container, chúng dễ dàng ghi đè file hệ thống, cài công cụ, và nếu có thêm
> một lỗ hổng thoát container (kernel/misconfig) hoặc volume mount nhạy cảm, chúng
> leo quyền ra máy host với tư cách root — toàn quyền.
>
> Trong Dockerfile tôi tạo user `appuser` (uid 10001) và đặt `USER appuser` trước
> khi chạy app. Việc này cắt chuỗi ở bước (2)→(3): lệnh mà kẻ tấn công chạy được
> chỉ có quyền của `appuser`, không phải root. Chúng không ghi được vào file hệ
> thống, không cài được gói, và bề mặt để leo quyền ra host bị thu hẹp rất nhiều.
> Đây là nguyên tắc least privilege — cho tiến trình đúng mức quyền tối thiểu nó cần.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Với cách đếm theo phút đồng hồ (reset lúc giây :00), người dùng có thể gửi tối
> đa **20 request trong 2 giây** khi hạn mức là 10/phút. Cách đạt: gửi 10 request
> ngay trước mốc reset (ví dụ lúc 12:00:59.5) — đủ hạn mức phút đó; rồi ngay sau
> khi đồng hồ nhảy sang 12:01:00, bộ đếm reset về 0, gửi thêm 10 request nữa
> (lúc 12:01:00.5). Tổng 20 request dồn vào ~1 giây quanh mốc phút, gấp đôi hạn
> mức thực. Đây là lỗ hổng "burst ở biên cửa sổ" của fixed-window.
>
> Sliding window mà tôi dùng (Redis Sorted Set, xoá các entry cũ hơn now-60s bằng
> `zremrangebyscore` rồi `zcard` để đếm) không có biên cố định: tại mọi thời điểm
> nó luôn đếm đúng số request trong 60 giây *vừa qua*, nên tối đa vẫn là 10 trong
> bất kỳ cửa sổ 60s trượt nào — không bị nhân đôi ở biên.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Khác nhau ở **thứ nguyên** chúng bảo vệ. Rate limit giới hạn *tần suất* (số
> request trong một khoảng thời gian, ở đây 10/phút) — chống spam/lạm dụng và bảo
> vệ tài nguyên tính toán, trả lỗi 429. Cost guard giới hạn *tổng chi phí tích luỹ*
> trong tháng (ngân sách USD, key `cost:<user>:<YYYY-MM>`) — chống cháy túi tiền
> API, trả lỗi 402. Rate limit reset liên tục theo cửa sổ 60s; cost guard tích luỹ
> cả tháng.
>
> Rate limit cho qua nhưng cost guard chặn: người dùng gửi câu hỏi thứ 3 trong
> phút (dưới 10/phút, rate limit OK) nhưng trong tháng đã tiêu gần hết ngân sách
> $10, câu này đẩy tổng vượt budget → cost guard trả 402.
>
> Ngược lại — cost guard cho qua nhưng rate limit chặn: đầu tháng ngân sách còn
> nguyên (cost guard OK), nhưng người dùng bấm gửi 11 lần trong 10 giây → request
> thứ 11 vượt 10/phút → rate limit trả 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Giả sử gộp thành một endpoint duy nhất có kiểm Redis, và orchestrator (Docker
> Swarm/K8s/Render) dùng nó làm **liveness probe** (probe fail → restart container).
> Thứ tự sự kiện khi Redis mất kết nối 30 giây:
> 1. Redis chết. Cả 3 container gọi probe → probe kiểm Redis → fail.
> 2. Orchestrator hiểu "liveness fail = container hỏng" → **kill và restart cả 3
>    container** cùng lúc.
> 3. Trong lúc restart, không container nào phục vụ được request → service
>    downtime toàn phần, kể cả những việc không cần Redis.
> 4. Container mới khởi động lại vẫn không nối được Redis (Redis vẫn đang chết) →
>    probe lại fail → **restart lặp vô hạn (crash loop)**.
> 5. Redis hồi phục sau 30s, nhưng cụm có thể vẫn đang loạn vì restart dồn dập.
>
> Tách hai endpoint tránh được điều này: `/health` (liveness) chỉ báo "tiến trình
> còn sống", không đụng Redis → không bị restart oan khi Redis chập chờn. `/ready`
> (readiness) mới kiểm Redis → khi Redis chết, container chỉ bị *rút khỏi load
> balancer* (ngừng nhận traffic) chứ không bị giết; Redis hồi phục thì `/ready`
> xanh lại và traffic tự quay về. Không có container nào phải restart, không crash
> loop.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Với Redis (như hiện tại): cả 3 container dùng chung một kho lịch sử. Dù mỗi
> request bị nginx routing sang container khác nhau, chúng đều đọc/ghi cùng list
> `history:<user_id>` trong Redis. Nên `history_length` tăng **đều đặn và nhất
> quán** theo số lần gọi: 2, 4, 6, 8... (mỗi lượt thêm 1 câu hỏi + 1 câu trả lời),
> bất kể request rơi vào container nào.
>
> Nếu lưu trong một dict Python trong bộ nhớ tiến trình: mỗi container có dict
> *riêng*, không chia sẻ. Khi nginx xoay vòng request qua 3 container, mỗi con chỉ
> thấy những lượt tình cờ rơi vào nó. `history_length` sẽ **nhảy lung tung và thấp
> hơn nhiều** — ví dụ 2, 2, 4, 2, 6... tùy load balancer chọn container nào, và
> "reset" mỗi khi request đổi container. Lịch sử hội thoại vỡ vụn. Đó chính là lý
> do state phải để ngoài tiến trình (Redis) — để service *stateless* và scale
> ngang được. Ngoài ra dict trong RAM còn mất sạch mỗi lần container restart.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Sau khi Render báo "Deploy live", tôi mở thẳng URL gốc
> `https://day12-agent-9f60.onrender.com/` trên trình duyệt và nhận về
> `{"detail":"Not Found"}`. Ban đầu tôi tưởng deploy hỏng.
>
> Tôi tìm nguyên nhân bằng cách xem lại `app/main.py`: app chỉ khai báo các route
> `/health`, `/ready`, `/ask` — không có handler cho đường dẫn gốc `/`. FastAPI trả
> 404 `{"detail":"Not Found"}` cho route không tồn tại là hành vi *đúng*, không
> phải service chết. Để xác nhận, tôi gọi đúng endpoint `/health` → nhận
> `{"status":"ok",...}` và `/ready` → `{"status":"ready","redis":true}`, chứng tỏ
> app và cả kết nối Redis đều ổn.
>
> Cách "sửa": không phải sửa code — mà sửa cách tôi kiểm tra. Tôi test đúng các
> endpoint đã định nghĩa thay vì gõ URL gốc. (Nếu muốn URL gốc không trả 404, có
> thể thêm một route `/` trả thông tin service, nhưng lab không yêu cầu.) Bài học:
> "Not Found" ở path không khai báo là bình thường, cần phân biệt với service thực
> sự lỗi — luôn kiểm tra bằng health/readiness probe, không phán đoán qua trang gốc.
