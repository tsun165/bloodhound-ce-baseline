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
