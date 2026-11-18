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

### — ghi chú cho mục 9 (compose-up)
- vòng chờ trong mục 9 đợi `GET /api/version` trả 200, nhưng endpoint này cần auth (trả 401) nên vòng chờ chạy hết 60×5 s. Duration 318 s của mục 9 **không** phải thời gian khởi động CE. Theo log, container healthy và API đã phản hồi sớm hơn nhiều.

### — trạng thái máy trước nạp D0
- cắm sạc, Power mode = Best performance (như trên), không có việc nặng song song, chỉ chạy CE. Nạp qua **API** (`POST /api/v2/file-upload/start` → `POST /api/v2/file-upload/{id}` (Content-Type application/zip) → `POST /api/v2/file-upload/{id}/end`), poll 5 s `GET /api/v2/datapipe/status` + `GET /api/v2/file-upload?id=eq:<job>`.

### 13. stats-d0-before-ingest
- start: 2026-11-16T16:15:31+07:00 · end: 2026-11-16T16:15:33+07:00 · duration_s: 2.390 · exit: 0
- cmd: `docker stats --no-stream | tee logs/stats/d0/before_ingest.txt`
- output: logs/raw/013-stats-d0-before-ingest.log

### 14. ingest-d0
- start: 2026-11-16T16:15:34+07:00 · end: 2026-11-16T16:16:34+07:00 · duration_s: 59.795 · exit: 0
- cmd: `bash scripts/ingest.sh d0 data/d0/ad_sampledata.zip`
- output: logs/raw/014-ingest-d0.log
- ghi chú: Nạp D0 (ad_sampledata.zip) qua API vào database sạch (volume mới tạo ở mục 9)

### 15. collect-d0-after-analysis
- start: 2026-11-16T16:16:58+07:00 · end: 2026-11-16T16:17:04+07:00 · duration_s: 6.186 · exit: 0
- cmd: `
docker compose logs --timestamps bloodhound | perl scripts/redact.pl > logs/ingest/d0/bloodhound.log
docker compose logs --timestamps graph-db | perl scripts/redact.pl > logs/ingest/d0/graph-db.log
docker stats --no-stream | tee logs/stats/d0/after_analysis.txt
docker compose exec -T graph-db sh -c "ls -la /data/databases /data/transactions; du -sb /data/databases/neo4j /data/transactions/neo4j" | tee logs/stats/d0/store_size.txt`
- output: logs/raw/015-collect-d0-after-analysis.log
- ghi chú: Sau khi phân tích D0 xong: log bloodhound/graph-db, docker stats, dung lượng store Neo4j

### 17. export-d0-node_counts
- start: 2026-11-16T16:18:50+07:00 · end: 2026-11-16T16:18:52+07:00 · duration_s: 2.231 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_node_counts.cypher > results/d0/node_counts.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/node_counts.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/017-export-d0-node_counts.log

### 18. export-d0-edge_counts
- start: 2026-11-16T16:18:52+07:00 · end: 2026-11-16T16:18:54+07:00 · duration_s: 1.657 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_edge_counts.cypher > results/d0/edge_counts.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/edge_counts.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/018-export-d0-edge_counts.log

### 19. export-d0-nodes
- start: 2026-11-16T16:18:55+07:00 · end: 2026-11-16T16:18:56+07:00 · duration_s: 1.552 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_nodes.cypher > results/d0/nodes.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/nodes.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/019-export-d0-nodes.log

### 20. export-d0-edges_22
- start: 2026-11-16T16:18:56+07:00 · end: 2026-11-16T16:18:59+07:00 · duration_s: 2.068 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_edges_22.cypher > results/d0/edges_22.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/edges_22.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/020-export-d0-edges_22.log

### 21. export-d0-tier0
- start: 2026-11-16T16:18:59+07:00 · end: 2026-11-16T16:19:00+07:00 · duration_s: 1.442 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_tier0.cypher > results/d0/tier0.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/tier0.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/021-export-d0-tier0.log

### 22. export-d0-reach_22
- start: 2026-11-16T16:19:01+07:00 · end: 2026-11-16T16:19:07+07:00 · duration_s: 5.917 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_reach_22.cypher > results/d0/reach_22.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/reach_22.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/022-export-d0-reach_22.log

### 23. export-d0-reach_all
- start: 2026-11-16T16:19:07+07:00 · end: 2026-11-16T16:19:25+07:00 · duration_s: 17.513 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_reach_all.cypher > results/d0/reach_all.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/reach_all.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/023-export-d0-reach_all.log

### 24. export-d0-prebuilt_tier0
- start: 2026-11-16T16:19:25+07:00 · end: 2026-11-16T16:19:43+07:00 · duration_s: 17.875 · exit: 0
- cmd: `bash scripts/bh_api.sh login >/dev/null && perl -MJSON::PP -0e 'local $/; my $q=<STDIN>; $q =~ s/;\s*\z//; print JSON::PP->new->canonical->encode({query=>$q, include_properties=>JSON::PP::true})' < queries/q_prebuilt_tier0.cypher | bash scripts/bh_api.sh POST /api/v2/graphs/cypher -H 'Content-Type: application/json' --data-binary @- -o results/d0/prebuilt_tier0.json -w 'http=%{http_code} bytes=%{size_download}\n'`
- output: logs/raw/024-export-d0-prebuilt_tier0.log

### 16. export-d0-all
- start: 2026-11-16T16:18:49+07:00 · end: 2026-11-16T16:19:43+07:00 · duration_s: 53.697 · exit: 0
- cmd: `bash scripts/export_correctness.sh d0`
- output: logs/raw/016-export-d0-all.log
- ghi chú: Xuất kết quả tính đúng D0 (sau khi phân tích xong lúc 09:16:31Z)

### — trạng thái máy trước đo hiệu năng D0
- 2026-11-16T16:20 (ngay trước mục perf-d0): cắm sạc (BatteryStatus=2), Power mode Best performance (overlay ded574b5…), CPU load 5 %, RAM trống ~0,8 GB, không việc nặng song song. Datapipe CE idle (kiểm trước từng câu, xem logs/queries/d0/datapipe_checks.log). Các câu chạy tuần tự.

### 25. perf-d0
- start: 2026-11-16T16:20:46+07:00 · end: 2026-11-16T16:59:01+07:00 · duration_s: 2295.215 · exit: 0
- cmd: `bash scripts/perf.sh d0`
- output: logs/raw/025-perf-d0.log
- ghi chú: Đo hiệu năng D0: p1,p2,p5 (EXPLAIN, PROFILE, restart, 1 lạnh + 5 ấm), p3 skipped, p4 (1 session 4 lượt: lượt 1 lạnh, 2-4 ấm). Chi tiết: scripts/perf.sh

### 26. build-results-d0
- start: 2026-11-16T16:59:15+07:00 · end: 2026-11-16T16:59:17+07:00 · duration_s: 1.638 · exit: 0
- cmd: `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/w" -w /w python:3.11-slim python -I scripts/build_results.py d0`
- output: logs/raw/026-build-results-d0.log
- ghi chú: Dựng results/d0 từ log thô (python:3.11-slim, chỉ stdlib)

### 27. compose-down-v
- start: 2026-11-16T17:06:43+07:00 · end: 2026-11-16T17:06:48+07:00 · duration_s: 5.130 · exit: 0
- cmd: `set -a; . ./.env; set +a; docker compose down -v 2>&1; docker volume ls | grep attack_path || echo "no project volumes left"`
- output: logs/raw/027-compose-down-v.log
- ghi chú: User đồng ý: docker compose down -v (xoá volume neo4j-data, postgres-data của project) để D1 có database sạch

### 28. compose-up-d1
- start: 2026-11-16T17:06:49+07:00 · end: 2026-11-16T17:07:27+07:00 · duration_s: 38.572 · exit: 0
- cmd: `set -a; . ./.env; set +a; t0=$(date +%s); docker compose up -d 2>&1; for i in $(seq 1 120); do bash scripts/bh_api.sh login >/dev/null 2>&1 && break; sleep 2; done; echo "login ok after $(( $(date +%s) - t0 ))s (probes=$i)"; bash scripts/bh_api.sh GET /api/version; echo; bash scripts/bh_api.sh GET /api/v2/datapipe/status; echo; docker compose ps`
- output: logs/raw/028-compose-up-d1.log
- ghi chú: Dựng lại CE (cùng compose, cùng image digest) với volume mới cho D1; chờ tới khi login API thành công

### 29. d1-precheck
- start: 2026-11-16T17:07:36+07:00 · end: 2026-11-16T17:07:40+07:00 · duration_s: 4.097 · exit: 0
- cmd: `set -a; . ./.env; set +a; for i in $(seq 1 60); do s=$(bash scripts/bh_api.sh GET /api/v2/datapipe/status); echo "$s" | grep -q "\"status\":\"idle\"" && break; sleep 5; done; echo "$s"; echo "MATCH (n) RETURN count(n) AS nodes; MATCH ()-[r]->() RETURN count(r) AS rels;" | docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain; docker stats --no-stream | tee logs/stats/d1/before_ingest.txt`
- output: logs/raw/029-d1-precheck.log
- ghi chú: Chờ datapipe idle sau khởi động, xác nhận Neo4j rỗng (database sạch) trước ingest D1

### — trạng thái máy trước nạp D1
- 2026-11-16T17:07:52+07:00: cắm sạc (BatteryStatus=2), RAM trống ~724 MB. Lệnh kiểm Power mode lúc này **lỗi** (quoting PowerShell trong bash, in ra Guid rỗng 0000…, không phải số đo). Kiểm lại đúng cách ngay sau ingest lúc 2026-11-16T17:09:05+07:00: overlay=ded574b5-45a0-4f42-8737-46345c09c238 (Best performance). Không có dấu hiệu đổi chế độ giữa chừng nhưng không chứng minh được cho đúng thời điểm ingest. Không có việc nặng song song. Database sạch bằng `docker compose down -v` + `up -d` (mục 27, 28), Neo4j còn 1 node MigrationData, 0 cạnh (mục 29).

### 30. ingest-d1
- start: 2026-11-16T17:07:52+07:00 · end: 2026-11-16T17:08:56+07:00 · duration_s: 63.133 · exit: 0
- cmd: `bash scripts/ingest.sh d1 data/d1/ESSOS_20240410083816_BloodHound-2.3.3.zip data/d1/NORTH_20240410083414_BloodHound-2.3.3.zip data/d1/SEVENKINGDOMS_20240410083609_BloodHound-2.3.3.zip`
- output: logs/raw/030-ingest-d1.log
- ghi chú: Nạp D1: 3 zip SharpHound (ESSOS, NORTH, SEVENKINGDOMS) vào CÙNG một ingest job, database sạch

### 31. collect-d1-after-analysis
- start: 2026-11-16T17:09:30+07:00 · end: 2026-11-16T17:09:35+07:00 · duration_s: 4.041 · exit: 0
- cmd: `
docker compose logs --timestamps bloodhound | perl scripts/redact.pl > logs/ingest/d1/bloodhound.log
docker compose logs --timestamps graph-db | perl scripts/redact.pl > logs/ingest/d1/graph-db.log
docker stats --no-stream | tee logs/stats/d1/after_analysis.txt
docker compose exec -T graph-db sh -c "ls -la /data/databases /data/transactions; du -sb /data/databases/neo4j /data/transactions/neo4j" | tee logs/stats/d1/store_size.txt`
- output: logs/raw/031-collect-d1-after-analysis.log
- ghi chú: Sau khi phân tích D1 xong: log bloodhound/graph-db, docker stats, dung lượng store

### 33. export-d1-node_counts
- start: 2026-11-16T17:09:35+07:00 · end: 2026-11-16T17:09:37+07:00 · duration_s: 1.872 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_node_counts.cypher > results/d1/node_counts.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/node_counts.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/033-export-d1-node_counts.log

### 34. export-d1-edge_counts
- start: 2026-11-16T17:09:38+07:00 · end: 2026-11-16T17:09:39+07:00 · duration_s: 1.430 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_edge_counts.cypher > results/d1/edge_counts.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/edge_counts.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/034-export-d1-edge_counts.log

### 35. export-d1-nodes
- start: 2026-11-16T17:09:39+07:00 · end: 2026-11-16T17:09:41+07:00 · duration_s: 1.599 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_nodes.cypher > results/d1/nodes.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/nodes.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/035-export-d1-nodes.log

### 36. export-d1-edges_22
- start: 2026-11-16T17:09:41+07:00 · end: 2026-11-16T17:09:43+07:00 · duration_s: 1.952 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_edges_22.cypher > results/d1/edges_22.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/edges_22.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/036-export-d1-edges_22.log

### 37. export-d1-tier0
- start: 2026-11-16T17:09:44+07:00 · end: 2026-11-16T17:09:45+07:00 · duration_s: 1.417 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_tier0.cypher > results/d1/tier0.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/tier0.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/037-export-d1-tier0.log

### 38. export-d1-reach_22
- start: 2026-11-16T17:09:46+07:00 · end: 2026-11-16T17:09:49+07:00 · duration_s: 3.803 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_reach_22.cypher > results/d1/reach_22.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/reach_22.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/038-export-d1-reach_22.log

### 39. export-d1-reach_all
- start: 2026-11-16T17:09:50+07:00 · end: 2026-11-16T17:09:57+07:00 · duration_s: 7.551 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_reach_all.cypher > results/d1/reach_all.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/reach_all.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/039-export-d1-reach_all.log

### 40. export-d1-prebuilt_tier0
- start: 2026-11-16T17:09:58+07:00 · end: 2026-11-16T17:10:03+07:00 · duration_s: 4.948 · exit: 0
- cmd: `bash scripts/bh_api.sh login >/dev/null && perl -MJSON::PP -0e 'local $/; my $q=<STDIN>; $q =~ s/;\s*\z//; print JSON::PP->new->canonical->encode({query=>$q, include_properties=>JSON::PP::true})' < queries/q_prebuilt_tier0.cypher | bash scripts/bh_api.sh POST /api/v2/graphs/cypher -H 'Content-Type: application/json' --data-binary @- -o results/d1/prebuilt_tier0.json -w 'http=%{http_code} bytes=%{size_download}\n'`
- output: logs/raw/040-export-d1-prebuilt_tier0.log

### 32. export-d1-all
- start: 2026-11-16T17:09:35+07:00 · end: 2026-11-16T17:10:03+07:00 · duration_s: 27.774 · exit: 0
- cmd: `bash scripts/export_correctness.sh d1`
- output: logs/raw/032-export-d1-all.log
- ghi chú: Xuất kết quả tính đúng D1

### — trạng thái máy trước đo hiệu năng D1
- 2026-11-16T17:10:22+07:00: overlay=ded574b5-45a0-4f42-8737-46345c09c238 battery_status=2 free_ram_mb=680 cpu_load_pct=33 (scripts/power_state.ps1; ded574b5… = Best performance, battery_status 2 = cắm sạc). Không việc nặng song song; datapipe idle (logs/queries/d1/datapipe_checks.log).

### 41. perf-d1
- start: 2026-11-16T17:10:27+07:00 · end: 2026-11-16T17:48:02+07:00 · duration_s: 2255.521 · exit: 0
- cmd: `bash scripts/perf.sh d1`
- output: logs/raw/041-perf-d1.log
- ghi chú: Đo hiệu năng D1, cùng quy trình với D0 (scripts/perf.sh)

### — trạng thái máy trước cpu_ref (after)
- 2026-11-16T17:48:19+07:00: overlay=ded574b5-45a0-4f42-8737-46345c09c238 battery_status=2 free_ram_mb=559 cpu_load_pct=4. Đo hiệu năng D1 đã xong; CE vẫn chạy nhưng datapipe idle, không có query nào.

### 42. cpu-ref-after
- start: 2026-11-16T17:48:20+07:00 · end: 2026-11-16T17:48:35+07:00 · duration_s: 15.283 · exit: 0
- cmd: `for i in 1 2 3; do echo "run $i $(date --iso-8601=seconds)"; MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)/scripts:/s:ro" python:3.11-slim python /s/cpu_ref.py; done`
- output: logs/raw/042-cpu-ref-after.log
- ghi chú: cpu_ref 3 lần sau khi xong mọi phép đo (CE vẫn chạy, idle)

### 43. capture-env-after
- start: 2026-11-16T17:48:44+07:00 · end: 2026-11-16T17:49:05+07:00 · duration_s: 20.934 · exit: 0
- cmd: `bash scripts/capture_env.sh after all`
- output: logs/raw/043-capture-env-after.log
- ghi chú: Chụp môi trường after (host/docker/images/compose + neo4j với D1 đang nạp)

### 44. build-results-d1
- start: 2026-11-16T17:49:05+07:00 · end: 2026-11-16T17:49:07+07:00 · duration_s: 1.533 · exit: 0
- cmd: `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/w" -w /w python:3.11-slim python -I scripts/build_results.py d1`
- output: logs/raw/044-build-results-d1.log
- ghi chú: Dựng results/d1 từ log thô

### 45. build-results-d0-d1
- start: 2026-11-16T17:49:18+07:00 · end: 2026-11-16T17:49:21+07:00 · duration_s: 2.908 · exit: 0
- cmd: `for d in d0 d1; do MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/w" -w /w python:3.11-slim python -I scripts/build_results.py $d; done`
- output: logs/raw/045-build-results-d0-d1.log
- ghi chú: Dựng lại results d0, d1 (sửa câu chữ kiểm chéo p2 khi p2 timeout)

### 46. summarize
- start: 2026-11-16T17:49:21+07:00 · end: 2026-11-16T17:49:22+07:00 · duration_s: 0.904 · exit: 0
- cmd: `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/w" -w /w python:3.11-slim python -I scripts/summarize.py d0 d1`
- output: logs/raw/046-summarize.log

### 47. d1-store-after-checkpoint
- start: 2026-11-16T17:49:41+07:00 · end: 2026-11-16T17:49:44+07:00 · duration_s: 3.620 · exit: 0
- cmd: `set -a; . ./.env; set +a
C="docker compose exec -T graph-db"
echo "== before checkpoint"; $C sh -c "du -sb /data/databases/neo4j /data/transactions/neo4j; du -sk /data/databases/neo4j /data/transactions/neo4j; ls -la /data/transactions/neo4j"
echo "CALL db.checkpoint();" | docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain
echo "== after checkpoint"; $C sh -c "du -sb /data/databases/neo4j /data/transactions/neo4j; du -sk /data/databases/neo4j /data/transactions/neo4j; ls -la /data/databases/neo4j /data/transactions/neo4j"
echo "CALL dbms.queryJmx(\"org.neo4j:*\") YIELD name RETURN name;" | docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain`
- output: logs/raw/047-d1-store-after-checkpoint.log
- ghi chú: Kiểm lại dung lượng store D1: du ngay sau phân tích cho cùng số với DB rỗng. Ép CALL db.checkpoint() rồi đo du -sb (apparent) và du -sk (block thật), liệt kê file tx log

### 48. d1-store-after-restart
- start: 2026-11-16T17:53:29+07:00 · end: 2026-11-16T17:53:49+07:00 · duration_s: 20.078 · exit: 0
- cmd: `bash scripts/store_after_restart.sh d1`
- output: logs/raw/048-d1-store-after-restart.log
- ghi chú: D1: restart graph-db (checkpoint) rồi du, cùng phương pháp sẽ dùng cho D0 rerun

### 49. compose-down-v-2
- start: 2026-11-16T17:54:05+07:00 · end: 2026-11-16T17:54:11+07:00 · duration_s: 5.567 · exit: 0
- cmd: `set -a; . ./.env; set +a; docker compose down -v 2>&1; docker volume ls | grep attack_path || echo "no project volumes left"`
- output: logs/raw/049-compose-down-v-2.log
- ghi chú: User đồng ý: down -v lần 2 (xoá volume D1, D1 đã xuất đủ) để nạp lại D0 chỉ nhằm đo store sau checkpoint

### 50. compose-up-d0-rerun
- start: 2026-11-16T17:54:11+07:00 · end: 2026-11-16T17:55:46+07:00 · duration_s: 94.294 · exit: 0
- cmd: `set -a; . ./.env; set +a; docker compose up -d 2>&1; for i in $(seq 1 120); do bash scripts/bh_api.sh login >/dev/null 2>&1 && break; sleep 2; done; for i in $(seq 1 60); do bash scripts/bh_api.sh GET /api/v2/datapipe/status | grep -q "\"status\":\"idle\"" && break; sleep 5; done; bash scripts/bh_api.sh GET /api/v2/datapipe/status; echo; echo "MATCH (n) RETURN count(n) AS nodes;" | docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain`
- output: logs/raw/050-compose-up-d0-rerun.log

### 51. ingest-d0-store-rerun
- start: 2026-11-16T17:55:46+07:00 · end: 2026-11-16T17:57:22+07:00 · duration_s: 95.874 · exit: 0
- cmd: `bash scripts/ingest.sh d0_store_rerun data/d0/ad_sampledata.zip`
- output: logs/raw/051-ingest-d0-store-rerun.log
- ghi chú: Nạp lại D0 (cùng quy trình) chỉ để đo store; số ingest/perf chính thức của D0 vẫn là lần đầu (mục 14)

### 52. d0-store-after-restart
- start: 2026-11-16T17:57:23+07:00 · end: 2026-11-16T17:58:16+07:00 · duration_s: 52.326 · exit: 0
- cmd: `bash scripts/store_after_restart.sh d0`
- output: logs/raw/052-d0-store-after-restart.log
- ghi chú: D0 rerun: restart graph-db (checkpoint) rồi du

### 53. collect-d0-store-rerun
- start: 2026-11-16T17:58:26+07:00 · end: 2026-11-16T17:58:32+07:00 · duration_s: 5.056 · exit: 0
- cmd: `set -a; . ./.env; set +a; docker compose logs --timestamps bloodhound | perl scripts/redact.pl > logs/ingest/d0_store_rerun/bloodhound.log; echo "MATCH (n:Tag_Tier_Zero) RETURN count(n) AS t0;" | docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain; docker stats --no-stream`
- output: logs/raw/053-collect-d0-store-rerun.log

### 54. build-results-d0-d1-2
- start: 2026-11-16T17:58:49+07:00 · end: 2026-11-16T17:58:53+07:00 · duration_s: 4.528 · exit: 0
- cmd: `for d in d0 d1; do MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/w" -w /w python:3.11-slim python -I scripts/build_results.py $d; done`
- output: logs/raw/054-build-results-d0-d1-2.log
- ghi chú: Dựng lại results: store_bytes = số sau checkpoint (restart graph-db); giữ số chưa flush trong trường riêng

### 55. summarize-2
- start: 2026-11-16T17:58:54+07:00 · end: 2026-11-16T17:58:55+07:00 · duration_s: 1.294 · exit: 0
- cmd: `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/w" -w /w python:3.11-slim python -I scripts/summarize.py d0 d1 > logs/summary_tables.md`
- output: logs/raw/055-summarize-2.log

### 56. start-docker-desktop
- start: 2026-11-19T05:30:12+07:00 · end: 2026-11-19T05:31:54+07:00 · duration_s: 102.273 · exit: 0
- cmd: `("/c/Program Files/Docker/Docker/Docker Desktop.exe" >/dev/null 2>&1 &); for i in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 5; done; docker info --format "NCPU={{.NCPU}} MemTotal={{.MemTotal}} ServerVersion={{.ServerVersion}}"`
- output: logs/raw/056-start-docker-desktop.log
- ghi chú: Bắt đầu việc câu hỏi bổ sung 19/11: Docker Desktop đang tắt, bật lại và chờ daemon

### 57. compose-up-extra
- start: 2026-11-19T05:32:21+07:00 · end: 2026-11-19T05:33:43+07:00 · duration_s: 82.538 · exit: 0
- cmd: `set -a; . ./.env; set +a; docker compose up -d 2>&1; for i in $(seq 1 120); do bash scripts/bh_api.sh login >/dev/null 2>&1 && break; sleep 2; done; for i in $(seq 1 60); do bash scripts/bh_api.sh GET /api/v2/datapipe/status | grep -q "\"status\":\"idle\"" && break; sleep 5; done; bash scripts/bh_api.sh GET /api/v2/datapipe/status; echo; docker compose ps`
- output: logs/raw/057-compose-up-extra.log
- ghi chú: Bật lại stack (volume còn nguyên, DB chứa D0 lần nạp lại); graph-db lần trước Exited (137) khi Docker Desktop tắt

### 58. check-counts-d0
- start: 2026-11-19T05:34:11+07:00 · end: 2026-11-19T05:34:37+07:00 · duration_s: 25.183 · exit: 0
- cmd: `set -a; . ./.env; set +a; for q in node_counts edge_counts; do timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_$q.cypher > logs/extra/d0/$q.now.csv; echo "$q rc=$? rows(excl header)=$(($(wc -l < logs/extra/d0/$q.now.csv)-1))"; if diff <(sort results/d0/$q.csv) <(sort logs/extra/d0/$q.now.csv); then echo "$q: KHOP results/d0/$q.csv"; else echo "$q: KHAC"; fi; done`
- output: logs/raw/058-check-counts-d0.log
- ghi chú: Kiểm số node/cạnh hiện tại khớp results/d0 (DB đang chứa D0 lần nạp lại)

### 59. check-t0-e22-d0
- start: 2026-11-19T05:34:56+07:00 · end: 2026-11-19T05:35:10+07:00 · duration_s: 13.064 · exit: 0
- cmd: `set -a; . ./.env; set +a; for q in tier0 edges_22; do timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_$q.cypher > logs/extra/d0/$q.now.csv; echo "$q rc=$? rows(excl header)=$(($(wc -l < logs/extra/d0/$q.now.csv)-1))"; cmp -s results/d0/$q.csv logs/extra/d0/$q.now.csv && echo "$q: giong het results/d0/$q.csv" || echo "$q: KHAC"; done`
- output: logs/raw/059-check-t0-e22-d0.log
- ghi chú: Lệch edge_counts ở ADCSESC9a/9b/10a/10b: kiểm thêm Tier 0 và edges_22 so với results/d0

### 60. diff-t0-d0
- start: 2026-11-19T05:35:34+07:00 · end: 2026-11-19T05:35:35+07:00 · duration_s: 0.707 · exit: 0
- cmd: `norm(){ perl -ne 'if(/^(.*?)\[(.*)\]\s*$/){my @l=sort split /, /,$2; print "$1\[".join(", ",@l)."]\n"} else {print}' "$1"; }; diff <(cut -d, -f1 results/d0/tier0.csv) <(cut -d, -f1 logs/extra/d0/tier0.now.csv) && echo "objectid: giống hệt (280)"; diff <(norm results/d0/tier0.csv) <(norm logs/extra/d0/tier0.now.csv) && echo "tier0: chỉ khác thứ tự nhãn trong cột labels"; echo "edge_counts lệch:"; diff results/d0/edge_counts.csv logs/extra/d0/edge_counts.now.csv; for f in results/d0/edge_counts.csv logs/extra/d0/edge_counts.now.csv; do awk -F", " "NR>1{s+=\$2} END{print FILENAME, \"total\", s}" $f; done`
- output: logs/raw/060-diff-t0-d0.log
- ghi chú: tier0.csv khác byte: kiểm tập objectid và labels sau khi sắp xếp nhãn

### 61. q1-psql-dt
- start: 2026-11-19T05:36:44+07:00 · end: 2026-11-19T05:36:45+07:00 · duration_s: 1.224 · exit: 0
- cmd: `docker compose exec -T app-db sh -c "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -c \"\dt asset_group*\" -c \"\d asset_group_tag_selectors\" -c \"\d asset_group_tag_selector_nodes\""`
- output: logs/raw/061-q1-psql-dt.log
- ghi chú: Q1: liệt kê bảng asset_group* trong app-db (user/db từ compose: PGUSER/POSTGRES_DB, mặc định bloodhound)

### 62. q1-selectors-tier-zero
- start: 2026-11-19T05:36:58+07:00 · end: 2026-11-19T05:36:59+07:00 · duration_s: 1.152 · exit: 0
- cmd: `docker compose exec -T app-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" --csv -v ON_ERROR_STOP=1' < queries/extra/q1_selectors_tier_zero.sql > results/selectors_tier_zero.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/selectors_tier_zero.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/062-q1-selectors-tier-zero.log
- ghi chú: Q1: selector của tag Tier Zero (không phụ thuộc dataset)

### 63. q1-tier0-by-selector-d0
- start: 2026-11-19T05:37:00+07:00 · end: 2026-11-19T05:37:01+07:00 · duration_s: 0.983 · exit: 0
- cmd: `docker compose exec -T app-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" --csv -v ON_ERROR_STOP=1' < queries/extra/q1_tier0_by_selector.sql > results/d0/extra/tier0_by_selector.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/extra/tier0_by_selector.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/063-q1-tier0-by-selector-d0.log
- ghi chú: Q1: node được chọn bởi từng selector Tier Zero, DB đang chứa D0

### 64. check-tier0-by-selector-d0
- start: 2026-11-19T05:37:11+07:00 · end: 2026-11-19T05:37:15+07:00 · duration_s: 3.010 · exit: 0
- cmd: `A=$(mktemp); B=$(mktemp); tail -n +2 results/d0/extra/tier0_by_selector.csv | cut -d, -f1 | sort -u > $A; tail -n +2 results/d0/tier0.csv | cut -d, -f1 | tr -d "\"" | sort -u > $B; echo "distinct objectid in tier0_by_selector: $(wc -l < $A)"; echo "empty objectid rows: $(tail -n +2 results/d0/extra/tier0_by_selector.csv | grep -c "^,")"; echo "tier0.csv objectid: $(wc -l < $B)"; echo "only in selector_nodes: $(comm -23 $A $B | wc -l)"; comm -23 $A $B | head -20; echo "only in tier0.csv: $(comm -13 $A $B | wc -l)"; comm -13 $A $B | head -20; echo "rows per selector:"; tail -n +2 results/d0/extra/tier0_by_selector.csv | cut -d, -f2- | sort | uniq -c | sort -rn; rm -f $A $B`
- output: logs/raw/064-check-tier0-by-selector-d0.log
- ghi chú: Q1 kiểm: tập objectid trong tier0_by_selector so với tier0.csv D0 (280)

### 65. check-tier0-by-selector-d0-2
- start: 2026-11-19T05:37:28+07:00 · end: 2026-11-19T05:37:30+07:00 · duration_s: 1.693 · exit: 0
- cmd: `A=$(mktemp); B=$(mktemp); perl scripts/csvcol.pl 1 results/d0/extra/tier0_by_selector.csv | sort -u > $A; perl scripts/csvcol.pl 1 results/d0/tier0.csv | sort -u > $B; echo "distinct objectid in tier0_by_selector: $(wc -l < $A)"; echo "tier0.csv objectid: $(wc -l < $B)"; echo "only in selector_nodes: $(comm -23 $A $B | wc -l)"; echo "only in tier0.csv: $(comm -13 $A $B | wc -l)"; echo "rows: $(perl scripts/csvcol.pl 2 results/d0/extra/tier0_by_selector.csv | wc -l), selectors with >=1 node: $(perl scripts/csvcol.pl 2 results/d0/extra/tier0_by_selector.csv | sort -u | wc -l)"; rm -f $A $B`
- output: logs/raw/065-check-tier0-by-selector-d0-2.log
- ghi chú: Kiểm lại #64: objectid có dấu phẩy (DN trong ngoặc kép) bị cut tách sai; dùng scripts/csvcol.pl (Text::ParseWords)

### 67. extra-d0-local_to_computer
- start: 2026-11-19T05:38:03+07:00 · end: 2026-11-19T05:38:07+07:00 · duration_s: 4.251 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q2_local_to_computer.cypher > results/d0/extra/local_to_computer.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/extra/local_to_computer.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/067-extra-d0-local_to_computer.log

### 68. extra-d0-member_of_local_group
- start: 2026-11-19T05:38:08+07:00 · end: 2026-11-19T05:38:10+07:00 · duration_s: 2.268 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q2_member_of_local_group.cypher > results/d0/extra/member_of_local_group.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/extra/member_of_local_group.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/068-extra-d0-member_of_local_group.log

### 69. extra-d0-edges_all
- start: 2026-11-19T05:38:11+07:00 · end: 2026-11-19T05:38:14+07:00 · duration_s: 3.422 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q3_edges_all.cypher > results/d0/extra/edges_all.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/extra/edges_all.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/069-extra-d0-edges_all.log

### 70. extra-d0-ce_paths_22
- start: 2026-11-19T05:38:15+07:00 · end: 2026-11-19T05:38:25+07:00 · duration_s: 9.622 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q4_ce_paths_22.cypher > results/d0/extra/ce_paths_22.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/extra/ce_paths_22.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/070-extra-d0-ce_paths_22.log

### 71. extra-d0-ce_paths_22_run2
- start: 2026-11-19T05:38:26+07:00 · end: 2026-11-19T05:38:32+07:00 · duration_s: 6.651 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q4_ce_paths_22.cypher > results/d0/extra/ce_paths_22_run2.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d0/extra/ce_paths_22_run2.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/071-extra-d0-ce_paths_22_run2.log

### 66. extra-d0-all
- start: 2026-11-19T05:38:02+07:00 · end: 2026-11-19T05:38:33+07:00 · duration_s: 30.187 · exit: 0
- cmd: `bash scripts/export_extra.sh d0`
- output: logs/raw/066-extra-d0-all.log
- ghi chú: Q2-Q4 cho D0 (DB D0 lần nạp lại, 16 663 cạnh, xem #58-#60)

### 72. check-extra-d0
- start: 2026-11-19T05:39:00+07:00 · end: 2026-11-19T05:39:03+07:00 · duration_s: 2.830 · exit: 0
- cmd: `bash scripts/check_extra.sh d0`
- output: logs/raw/072-check-extra-d0.log
- ghi chú: Kiểm Q3 (22 loại trong edges_all = edges_22.csv), Q4 ((src,dist) = reach_22, diff 2 lần chạy) cho D0

### 73. compose-down-v-3
- start: 2026-11-19T05:39:29+07:00 · end: 2026-11-19T05:39:37+07:00 · duration_s: 8.170 · exit: 0
- cmd: `set -a; . ./.env; set +a; docker compose down -v 2>&1; docker volume ls | grep attack_path || echo "no project volumes left"`
- output: logs/raw/073-compose-down-v-3.log
- ghi chú: User đồng ý (19/11): down -v (xoá volume D0 lần nạp lại; kết quả extra D0 đã xuất đủ) để nạp D1 vào DB sạch

### 74. compose-up-d1-extra
- start: 2026-11-19T05:39:38+07:00 · end: 2026-11-19T05:41:47+07:00 · duration_s: 129.143 · exit: 0
- cmd: `set -a; . ./.env; set +a; t0=$(date +%s); docker compose up -d 2>&1; for i in $(seq 1 120); do bash scripts/bh_api.sh login >/dev/null 2>&1 && break; sleep 2; done; echo "login ok after $(( $(date +%s) - t0 ))s (probes=$i)"; bash scripts/bh_api.sh GET /api/version; echo; bash scripts/bh_api.sh GET /api/v2/datapipe/status; echo; docker compose ps`
- output: logs/raw/074-compose-up-d1-extra.log
- ghi chú: Dựng lại CE (cùng compose, cùng digest), volume mới cho D1

### 75. d1-extra-precheck
- start: 2026-11-19T05:41:49+07:00 · end: 2026-11-19T05:42:12+07:00 · duration_s: 23.181 · exit: 0
- cmd: `set -a; . ./.env; set +a; for i in $(seq 1 60); do s=$(bash scripts/bh_api.sh GET /api/v2/datapipe/status); echo "$s" | grep -q "\"status\":\"idle\"" && break; sleep 5; done; echo "$s"; echo "MATCH (n) RETURN count(n) AS nodes; MATCH ()-[r]->() RETURN count(r) AS rels;" | docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain`
- output: logs/raw/075-d1-extra-precheck.log
- ghi chú: Chờ datapipe idle, xác nhận Neo4j rỗng trước ingest D1

### 76. ingest-d1-extra
- start: 2026-11-19T05:42:27+07:00 · end: 2026-11-19T05:46:03+07:00 · duration_s: 215.516 · exit: 0
- cmd: `bash scripts/ingest.sh d1_extra data/d1/ESSOS_20240410083816_BloodHound-2.3.3.zip data/d1/NORTH_20240410083414_BloodHound-2.3.3.zip data/d1/SEVENKINGDOMS_20240410083609_BloodHound-2.3.3.zip`
- output: logs/raw/076-ingest-d1-extra.log
- ghi chú: Nạp D1 (3 zip, 1 job, DB sạch) cùng quy trình mục 30; ds=d1_extra để không ghi đè logs/ingest/d1

### 77. check-counts-d1
- start: 2026-11-19T05:46:30+07:00 · end: 2026-11-19T05:46:40+07:00 · duration_s: 9.599 · exit: 0
- cmd: `set -a; . ./.env; set +a; norm(){ perl -ne 'if(/^(.*?)\[(.*)\]\s*$/){my @l=sort split /, /,$2; print "$1\[".join(", ",@l)."]\n"} else {print}' "$1"; }; for q in node_counts edge_counts edges_22 tier0; do timeout 300 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/q_$q.cypher > logs/extra/d1/$q.now.csv; echo "$q rc=$? rows(excl header)=$(($(wc -l < logs/extra/d1/$q.now.csv)-1))"; if cmp -s results/d1/$q.csv logs/extra/d1/$q.now.csv; then echo "$q: giong het byte"; elif diff <(norm results/d1/$q.csv | sort) <(norm logs/extra/d1/$q.now.csv | sort) >/dev/null; then echo "$q: cung tap dong (chi khac thu tu dong/nhan)"; else echo "$q: KHAC"; diff <(norm results/d1/$q.csv | sort) <(norm logs/extra/d1/$q.now.csv | sort); fi; done; for f in results/d1/edge_counts.csv logs/extra/d1/edge_counts.now.csv; do awk -F", " "NR>1{s+=\$2} END{print FILENAME, \"total\", s}" $f; done`
- output: logs/raw/077-check-counts-d1.log
- ghi chú: Kiểm node/cạnh/edges_22/tier0 sau nạp D1 so với results/d1

### 79. extra-d1-local_to_computer
- start: 2026-11-19T05:46:56+07:00 · end: 2026-11-19T05:46:58+07:00 · duration_s: 1.922 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q2_local_to_computer.cypher > results/d1/extra/local_to_computer.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/extra/local_to_computer.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/079-extra-d1-local_to_computer.log

### 80. extra-d1-member_of_local_group
- start: 2026-11-19T05:46:59+07:00 · end: 2026-11-19T05:47:00+07:00 · duration_s: 1.427 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q2_member_of_local_group.cypher > results/d1/extra/member_of_local_group.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/extra/member_of_local_group.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/080-extra-d1-member_of_local_group.log

### 81. extra-d1-edges_all
- start: 2026-11-19T05:47:00+07:00 · end: 2026-11-19T05:47:02+07:00 · duration_s: 2.070 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q3_edges_all.cypher > results/d1/extra/edges_all.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/extra/edges_all.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/081-extra-d1-edges_all.log

### 82. extra-d1-ce_paths_22
- start: 2026-11-19T05:47:03+07:00 · end: 2026-11-19T05:47:07+07:00 · duration_s: 4.490 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q4_ce_paths_22.cypher > results/d1/extra/ce_paths_22.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/extra/ce_paths_22.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/082-extra-d1-ce_paths_22.log

### 83. extra-d1-ce_paths_22_run2
- start: 2026-11-19T05:47:08+07:00 · end: 2026-11-19T05:47:13+07:00 · duration_s: 4.801 · exit: 0
- cmd: `set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain < queries/extra/q4_ce_paths_22.cypher > results/d1/extra/ce_paths_22_run2.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/extra/ce_paths_22_run2.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/083-extra-d1-ce_paths_22_run2.log

### 78. extra-d1-all
- start: 2026-11-19T05:46:56+07:00 · end: 2026-11-19T05:47:14+07:00 · duration_s: 17.710 · exit: 0
- cmd: `bash scripts/export_extra.sh d1`
- output: logs/raw/078-extra-d1-all.log
- ghi chú: Q2-Q4 cho D1 (DB D1 sạch, khớp results/d1, #77)

### 84. q1-tier0-by-selector-d1
- start: 2026-11-19T05:47:15+07:00 · end: 2026-11-19T05:47:16+07:00 · duration_s: 1.725 · exit: 0
- cmd: `docker compose exec -T app-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" --csv -v ON_ERROR_STOP=1' < queries/extra/q1_tier0_by_selector.sql > results/d1/extra/tier0_by_selector.csv; rc=$?; echo "rows(excl header)=$(($(wc -l < results/d1/extra/tier0_by_selector.csv)-1)) rc=$rc"; exit $rc`
- output: logs/raw/084-q1-tier0-by-selector-d1.log
- ghi chú: Q1: node theo selector Tier Zero, DB đang chứa D1

### 85. q1-selectors-recheck-d1
- start: 2026-11-19T05:47:17+07:00 · end: 2026-11-19T05:47:19+07:00 · duration_s: 2.235 · exit: 0
- cmd: `docker compose exec -T app-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" --csv -v ON_ERROR_STOP=1' < queries/extra/q1_selectors_tier_zero.sql > logs/extra/d1/selectors_tier_zero.now.csv; cmp -s results/selectors_tier_zero.csv logs/extra/d1/selectors_tier_zero.now.csv && echo 'selectors: giong het' || diff results/selectors_tier_zero.csv logs/extra/d1/selectors_tier_zero.now.csv; A=$(mktemp); B=$(mktemp); perl scripts/csvcol.pl 1 results/d1/extra/tier0_by_selector.csv | sort -u > $A; perl scripts/csvcol.pl 1 results/d1/tier0.csv | sort -u > $B; echo "D1 distinct objectid=$(wc -l < $A) tier0=$(wc -l < $B) only_sel=$(comm -23 $A $B | wc -l) only_t0=$(comm -13 $A $B | wc -l) selectors_with_nodes=$(perl scripts/csvcol.pl 2 results/d1/extra/tier0_by_selector.csv | sort -u | wc -l)"; rm -f $A $B`
- output: logs/raw/085-q1-selectors-recheck-d1.log
- ghi chú: Q1: so danh sách selector Tier Zero sau down -v (app-db mới) với results/selectors_tier_zero.csv

### 86. check-extra-d1
- start: 2026-11-19T05:47:20+07:00 · end: 2026-11-19T05:47:23+07:00 · duration_s: 2.796 · exit: 0
- cmd: `bash scripts/check_extra.sh d1`
- output: logs/raw/086-check-extra-d1.log
- ghi chú: Kiểm Q3, Q4 cho D1
