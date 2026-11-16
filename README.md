# BloodHound CE baseline trên dữ liệu public D0, D1

Repo này ghi lại **một lần chạy BloodHound Community Edition (CE) local** trên hai bộ dữ liệu public. Mục đích là làm baseline để một hệ thống khác (graph lưu dạng mảng `.npy` trong RAM) so sánh:

1. **tính đúng**: tập node, tập cạnh, tập Tier 0, khoảng cách ngắn nhất tới Tier 0 của từng principal;
2. **hiệu năng**: số đo thô của Neo4j do CE nạp (thời gian ingest/phân tích, db hits, thời gian truy vấn lạnh/ấm, RAM, dung lượng store).

Repo **không kết luận so sánh**, chỉ ghi số. Báo cáo tóm tắt và các chỗ vướng: [`REPORT.md`](REPORT.md). Nhật ký từng lệnh: [`logs/RUNLOG.md`](logs/RUNLOG.md).

## Phiên bản

| Thành phần | Giá trị |
|---|---|
| BloodHound CE | `v9.9.2` (release ổn định mới nhất lúc chạy, 2026-11-16), git commit `93dcb33af324ef6b080f9bd110d65c8ee2ea8bc4` |
| image `bloodhound` | `docker.io/specterops/bloodhound:9.9.2@sha256:47a21323d05185b284fff799c2b96bcc1d110f06f45b190f7ad83e69ef5e0d68` |
| image `graph-db` | `docker.io/library/neo4j:4.4.42@sha256:73b5a47eb9952f47fcc42fcc80bdd6bd0d6b71eea9a1a345c216675498c790e4` (Community, heap không đặt, JVM tự chọn max ≈ 1,29 GB; pagecache 512M do `neo4j.conf` của image) |
| image `app-db` | `docker.io/library/postgres:18@sha256:2ea8630df176ad090ec92136dee850397c5af8781e4bcf2e4162593691c61bbc` |
| backend graph | Neo4j (mặc định), **không** APOC/GDS |
| Máy | Intel i5-11400H (6C/12T), RAM 8 GB, NVMe SSD, Windows 11 + Docker Desktop 29.8.0 (WSL2, giới hạn 5 GB RAM + 2 GB swap qua `~/.wslconfig`, 12 CPU) |

Chi tiết: `logs/env/before/`, `logs/env/after/`, `results/<ds>/env.json`.

## Dữ liệu

| Mã | Nguồn | File |
|---|---|---|
| D0 | Trang [CE Quickstart](https://bloodhound.specterops.io/get-started/quickstart/community-edition-quickstart), link "Active Directory" ở mục *Download sample data* | `ad_sampledata.zip` |
| D1 | [m4lwhere/Bloodhound-CE-Sample-Data](https://github.com/m4lwhere/Bloodhound-CE-Sample-Data), **chỉ** 3 zip SharpHound, nạp chung một database | `ESSOS_…`, `NORTH_…`, `SEVENKINGDOMS_…` |

URL, kích thước, SHA-256: [`logs/env/datasets.txt`](logs/env/datasets.txt). Zip không nằm trong repo (`data/` bị gitignore).

## Cấu trúc

```
docker-compose.yml   compose chính thức @v9.9.2; chỉ đổi: ghim tag@digest, bỏ mật khẩu mặc định (lấy từ .env),
                     thêm bhe_default_admin_password. Không đổi cấu hình bộ nhớ Neo4j.
scripts/             run.sh (chạy 1 lệnh + ghi log/RUNLOG, redact), redact.pl, capture_env.sh, cpu_ref.py (nguyên văn đề bài),
                     bh_api.sh (gọi API CE), ingest.sh (nạp + poll), export_correctness.sh, perf.sh (đo),
                     build_results.py (dựng perf.csv / ingest.json / env.json / queries.md), summarize.py (bảng cho REPORT),
                     power_state.ps1 (chế độ nguồn Windows)
queries/             q_*.cypher (tính đúng), p_*.cypher (hiệu năng), ad_transit_edge_types.txt (65 loại cạnh transit của CE)
logs/RUNLOG.md       mỗi lệnh một mục: start/end/duration/exit/cmd/output
logs/raw/            stdout+stderr từng lệnh (NNN-<tên>.log), kể cả lần lỗi
logs/env/            before/, after/ (hardware, docker, images, compose.resolved.yml, neo4j, cpu_ref), datasets.txt, ce_source.txt
logs/ingest/<ds>/    timeline.log (mốc upload), datapipe_poll.log (mỗi lần poll 5 s), bloodhound.log, graph-db.log
logs/stats/<ds>/     docker stats trước/sau ingest, sau phân tích, trước/sau từng query; store_size.txt
logs/queries/<ds>/   *.explain.txt, *.profile.txt, *.cold.txt, *.warmN.txt, p4 session, *.restart.txt, manifest.tsv
results/<ds>/        env.json, queries.md, ingest.json, node_counts.csv, edge_counts.csv, nodes.csv, edges_22.csv, tier0.csv,
                     reach_22.csv, reach_all.csv, prebuilt_tier0.json, perf.csv, p4_users.csv, crosscheck.txt
```

## Định dạng kết quả

- Các file `*.csv` ở `results/<ds>/` (trừ `perf.csv`, `p4_users.csv`) là đầu ra **nguyên văn** của `cypher-shell --format plain`: dòng đầu là header, phân tách `, `, chuỗi trong `"…"`, list dạng `["User", "Base"]`, giá trị rỗng là `NULL`. Sắp xếp theo `ORDER BY` trong câu truy vấn.
- `reach_22.csv`: `objectid, name, dist`. `dist` = `NULL` nghĩa là không tới được Tier 0 theo 22 loại cạnh.
- `perf.csv`: `dataset,query_id,param,run,cache,neo4j_ready_ms,neo4j_consumed_ms,wall_ms,rows,result_value,db_hits,status`
  - `neo4j_ready_ms` / `neo4j_consumed_ms`: số Neo4j báo qua cypher-shell (`ready to start consuming query after X ms, results consumed after another Y ms`). Thời gian một lần chạy = X + Y.
  - `wall_ms`: đo trên host quanh `docker compose exec … cypher-shell`, gồm cả thời gian khởi động JVM cypher-shell (~1,3–2 s). Chỉ để tham khảo.
  - `run`: `explain`, `profile`, `1` (cold), `1..5` (warm); với p4 `run` = số lượt (1 = lạnh, 2–4 = ấm) và `param` = objectid; dòng `session_total` = wall cả phiên p4.
  - `db_hits`: chỉ ở dòng `run=profile` (lấy từ bảng tóm tắt PROFILE).
  - `status`: `ok`, `timeout` (300 s, query đã bị kill trên server bằng `dbms.killQuery`), `skipped`.
- `ingest.json`: `ingest_s` = tổng `Ingest run finished.duration` trong log bloodhound (phần datapipe ingest). `analysis_s` = `Graph Analysis` elapsed (post-processing + gắn Tier Zero). Kèm các mốc gốc.

## Chạy lại từ đầu

Yêu cầu: Docker (Compose v2), bash (Git Bash trên Windows), perl, curl, unzip. Các script Python chạy trong `python:3.11-slim`.

```bash
# 1. secrets (không commit)
cp .env.example .env   # điền POSTGRES_PASSWORD, NEO4J_SECRET, BH_ADMIN_PASSWORD (chữ+số, không ký tự đặc biệt cho 2 cái đầu)
# 2. dữ liệu: tải về data/d0, data/d1 theo logs/env/datasets.txt, kiểm SHA-256
# 3. môi trường + cpu_ref
bash scripts/run.sh capture-env-before -- 'bash scripts/capture_env.sh before host'
bash scripts/run.sh cpu-ref -- 'for i in 1 2 3; do docker run --rm -v "$PWD/scripts:/s:ro" python:3.11-slim python /s/cpu_ref.py; done'
# 4. dựng CE, chờ login được
docker compose up -d
bash scripts/capture_env.sh before neo4j
# 5. mỗi dataset (database sạch: docker compose down -v && docker compose up -d giữa hai dataset)
bash scripts/ingest.sh d0 data/d0/ad_sampledata.zip
#    -> thu log: xem mục "collect-d0-after-analysis" trong logs/RUNLOG.md
bash scripts/export_correctness.sh d0
bash scripts/perf.sh d0
docker run --rm -v "$PWD:/w" -w /w python:3.11-slim python -I scripts/build_results.py d0
# 6. bảng tóm tắt
docker run --rm -v "$PWD:/w" -w /w python:3.11-slim python -I scripts/summarize.py d0 d1
```

Trên Git Bash/Windows cần `MSYS_NO_PATHCONV=1` và `$(pwd -W)` thay cho `$PWD` trong `docker run -v` (xem lệnh thật trong RUNLOG).

## Bảo mật / riêng tư

Mật khẩu chỉ nằm trong `.env` (gitignore). Mọi log đã qua `scripts/redact.pl`: thay giá trị bí mật trong `.env`, token phiên, tên máy (`<host>`), tên user hệ điều hành (`<user>`), đường dẫn home (`~`). Cổng CE và Neo4j chỉ mở trên `127.0.0.1`.
