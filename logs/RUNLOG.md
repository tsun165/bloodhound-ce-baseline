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
