# RUNLOG

Nhật ký theo thời gian. Mỗi mục do `scripts/run.sh` ghi khi lệnh **kết thúc** (lệnh chạy nền có thể xuất hiện sau mục có số lớn hơn). Số thứ tự = thứ tự bắt đầu. stdout+stderr đã redact ở `logs/raw/<số>-<tên>.log`. Thời gian ISO 8601 (+07:00), thời lượng giây.
Mục không có `cmd` là thao tác thủ công / ghi chú (ví dụ chế độ nguồn, thao tác trên UI).

### 2. download-datasets
- start: 2026-11-16T15:50:44+07:00 · end: 2026-11-16T15:51:00+07:00 · duration_s: 15.518 · exit: 0
- cmd: `
set -e
B=https://raw.githubusercontent.com/m4lwhere/Bloodhound-CE-Sample-Data/main
curl -fsSL -o data/d0/ad_sampledata.zip https://raw.githubusercontent.com/SpecterOps/BloodHound-Docs/main/docs/assets/sample-data/ad_sampledata.zip
for f in ESSOS_20240410083816_BloodHound-2.3.3.zip NORTH_20240410083414_BloodHound-2.3.3.zip SEVENKINGDOMS_20240410083609_BloodHound-2.3.3.zip; do curl -fsSL -o data/d1/$f $B/$f; done
ls -l data/d0 data/d1; sha256sum data/d0/*.zip data/d1/*.zip; for z in data/d0/*.zip data/d1/*.zip; do echo "== $z"; unzip -l "$z"; done`
- output: logs/raw/002-download-datasets.log
- ghi chú: D0 từ link Quickstart (BloodHound-Docs, commit cuối của file 0c52292); D1 3 zip SharpHound từ m4lwhere repo (HEAD 4d365b8)

### 1. pull-images
- start: 2026-11-16T15:48:23+07:00 · end: 2026-11-16T15:51:53+07:00 · duration_s: 209.444 · exit: 0
- cmd: `for i in docker.io/library/postgres:18 docker.io/library/neo4j:4.4.42 docker.io/specterops/bloodhound:v9.9.2 docker.io/library/python:3.11-slim; do docker pull -q $i; done`
- output: logs/raw/001-pull-images.log
- ghi chú: Kéo 3 image CE (tag theo compose v9.9.2) + python:3.11-slim
- ghi chú (thêm sau): exit 0 là của vòng `for`, nhưng `specterops/bloodhound:v9.9.2` **lỗi** "manifest unknown" (xem log). Tag image Docker Hub là `9.9.2`, không có `v`. Kéo lại ở mục 4. Mục này chạy nền nên được ghi sau mục 2.

### 3. clone-ce-source
- start: 2026-11-16T15:51:21+07:00 · end: 2026-11-16T15:54:31+07:00 · duration_s: 190.357 · exit: 0
- cmd: `git -c advice.detachedHead=false clone -q --depth 1 --branch v9.9.2 https://github.com/SpecterOps/BloodHound.git vendor/BloodHound && git -C vendor/BloodHound rev-parse HEAD && git -C vendor/BloodHound describe --tags`
- output: logs/raw/003-clone-ce-source.log
- ghi chú: Clone SpecterOps/BloodHound ở tag v9.9.2 (shallow) để đọc câu truy vấn có sẵn

### 4. pull-bloodhound-image
- start: 2026-11-16T15:56:47+07:00 · end: 2026-11-16T15:57:21+07:00 · duration_s: 34.364 · exit: 0
- cmd: `docker pull docker.io/specterops/bloodhound:9.9.2 && docker image ls --digests specterops/bloodhound`
- output: logs/raw/004-pull-bloodhound-image.log
- ghi chú: Lần #1 lỗi: tag image là 9.9.2 (không có tiền tố v như git tag v9.9.2)

### 5. wslconfig-and-restart
- start: 2026-11-16T15:57:45+07:00 · end: 2026-11-16T15:58:48+07:00 · duration_s: 62.814 · exit: 0
- cmd: `
docker info --format "before: NCPU={{.NCPU}} MemTotal={{.MemTotal}}"
printf "[wsl2]\r\nmemory=5GB\r\nswap=2GB\r\n" > "$USERPROFILE/.wslconfig"; cat "$USERPROFILE/.wslconfig"
taskkill.exe //IM "Docker Desktop.exe" //F; wsl.exe --shutdown; echo "wsl shutdown rc=$?"
sleep 8; "/c/Program Files/Docker/Docker/Docker Desktop.exe" >/dev/null 2>&1 &
for i in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 5; done
docker info --format "after: NCPU={{.NCPU}} MemTotal={{.MemTotal}}"`
- output: logs/raw/005-wslconfig-and-restart.log
- ghi chú: User đồng ý: Total Memory Docker 3.68 GiB < 4 GB nên đặt memory=5GB swap=2GB trong ~/.wslconfig (trước đó chưa có file), wsl --shutdown, mở lại Docker Desktop

### 6. capture-env-before-host
- start: 2026-11-16T16:04:09+07:00 · end: 2026-11-16T16:04:20+07:00 · duration_s: 10.593 · exit: 0
- cmd: `bash scripts/capture_env.sh before host`
- output: logs/raw/006-capture-env-before-host.log
- ghi chú: Chụp môi trường before (host/docker/images/compose), trước khi dựng CE

### 7. capture-env-before-host-2
- start: 2026-11-16T16:07:12+07:00 · end: 2026-11-16T16:07:20+07:00 · duration_s: 7.811 · exit: 0
- cmd: `bash scripts/capture_env.sh before host`
- output: logs/raw/007-capture-env-before-host-2.log
- ghi chú: Chụp lại before sau khi user tắt Energy saver và đặt Power mode (plugged in) = Best performance. Lần #6 bị ghi khi đang Best power efficiency (Energy saver On) nên bị thay thế; log #6 vẫn giữ.

### — trạng thái máy trước đo cpu_ref (before)
- thời điểm: 2026-11-16T16:07+07:00 (ngay trước mục 8)
- cắm sạc: có (Win32_Battery.BatteryStatus=2). Power mode khi cắm sạc: Best performance (overlay ded574b5-45a0-4f42-8737-46345c09c238, kiểm bằng PowerGetEffectiveOverlayScheme). Energy saver: user đã tắt.
- việc nặng song song: không (user đã đóng bớt ứng dụng; Claude desktop app + Docker Desktop vẫn chạy). Chưa dựng CE.
- RAM trống của máy: ~0,87 GB (< 5 GB khuyến nghị; máy 8 GB và WSL/Docker được cấp 5 GB). Xem logs/env/before/hardware.txt.

### 8. cpu-ref-before
- start: 2026-11-16T16:07:20+07:00 · end: 2026-11-16T16:07:36+07:00 · duration_s: 15.432 · exit: 0
- cmd: `for i in 1 2 3; do echo "run $i $(date --iso-8601=seconds)"; MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)/scripts:/s:ro" python:3.11-slim python /s/cpu_ref.py; done`
- output: logs/raw/008-cpu-ref-before.log
- ghi chú: cpu_ref 3 lần trước khi chạy CE (mỗi lần = 1 container python:3.11-slim, 5 vòng work())

### 9. compose-up
- start: 2026-11-16T16:07:48+07:00 · end: 2026-11-16T16:13:07+07:00 · duration_s: 318.554 · exit: 0
- cmd: `set -a; . ./.env; set +a; docker compose up -d 2>&1; for i in $(seq 1 60); do c=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/api/version); [ "$c" = 200 ] && break; sleep 5; done; echo "api/version http=$c after ~$((i*5))s"; curl -s http://127.0.0.1:8080/api/version; echo; docker compose ps`
- output: logs/raw/009-compose-up.log
- ghi chú: Dựng CE v9.9.2 (database sạch, volume mới) cho D0

### 10. api-login
- start: 2026-11-16T16:13:19+07:00 · end: 2026-11-16T16:13:21+07:00 · duration_s: 2.631 · exit: 0
- cmd: `bash scripts/bh_api.sh login && bash scripts/bh_api.sh GET /api/version; echo; bash scripts/bh_api.sh GET /api/v2/self`
- output: logs/raw/010-api-login.log

### 11. capture-env-before-neo4j
- start: 2026-11-16T16:13:30+07:00 · end: 2026-11-16T16:13:39+07:00 · duration_s: 9.143 · exit: 0
- cmd: `bash scripts/capture_env.sh before neo4j`
- output: logs/raw/011-capture-env-before-neo4j.log
- ghi chú: neo4j.txt before: stack vừa dựng, DB rỗng, trước ingest D0

### 12. capture-env-before-neo4j-2
- start: 2026-11-16T16:14:07+07:00 · end: 2026-11-16T16:14:17+07:00 · duration_s: 10.285 · exit: 0
- cmd: `bash scripts/capture_env.sh before neo4j`
- output: logs/raw/012-capture-env-before-neo4j-2.log
- ghi chú: Chụp lại neo4j.txt before để thêm heap thực tế qua JMX (lần #11 thiếu)
