# REPORT: BloodHound CE 9.9.2 trên D0, D1 (chạy 2026-11-16)

Toàn bộ số dưới đây sinh từ file trong repo: bảng do `scripts/summarize.py` in ra (bản đầy đủ ở `logs/summary_tables.md`), số gốc nằm ở `results/<ds>/`. Không có số nào được sửa tay. Repo **không** kết luận so sánh.

## 1. Môi trường

| | |
|---|---|
| CE | `v9.9.2` (`/api/version`: `server_version v9.9.2`, `community`), git `93dcb33af324ef6b080f9bd110d65c8ee2ea8bc4` |
| `bloodhound` | `specterops/bloodhound:9.9.2@sha256:47a21323d05185b284fff799c2b96bcc1d110f06f45b190f7ad83e69ef5e0d68` |
| `graph-db` | `neo4j:4.4.42@sha256:73b5a47eb9952f47fcc42fcc80bdd6bd0d6b71eea9a1a345c216675498c790e4`, Community, runtime `INTERPRETED` (theo PROFILE) |
| `app-db` | `postgres:18@sha256:2ea8630df176ad090ec92136dee850397c5af8781e4bcf2e4162593691c61bbc` |
| Bộ nhớ Neo4j | giữ như compose gốc: heap **không đặt**, JVM tự chọn `max = 1 289 748 480 B` (≈ 1/4 RAM Docker), `init = 81 788 928 B`; `dbms.memory.pagecache.size=512M` (đặt sẵn trong `neo4j.conf` của image); `pagecache.warmup.enable=true`. Không APOC, không GDS |
| Máy | Intel Core i5-11400H (6 core / 12 thread, base 2,69 GHz), RAM 8 GB (8 277 123 072 B), NVMe SSD Kingston 512 GB, Windows 11 Home 10.0.26200 |
| Docker | Docker Desktop, Engine 29.8.0, WSL2 kernel 6.18.58.1, `CPUs: 12`, `Total Memory: 4.803GiB` (sau khi đặt `~/.wslconfig` memory=5GB, swap=2GB; ban đầu 3,68 GiB), storage driver overlay2 |
| Điều kiện đo | cắm sạc, Power mode = Best performance (đã tắt Energy saver), không chạy việc nặng song song, chạy tuần tự. RAM trống của máy chỉ khoảng 0,6–1,0 GB (xem Vướng 4) |

### cpu_ref (`scripts/cpu_ref.py` trong `python:3.11-slim`, Python 3.11.18)

| | lần 1 | lần 2 | lần 3 | trung vị 3 lần |
|---|---|---|---|---|
| trước khi chạy CE (16:07) | 0.834 | 0.858 | 0.819 | **0.834 s** |
| sau khi xong mọi phép đo (17:48) | 0.854 | 0.815 | 0.837 | **0.837 s** |

Lệch +0,4 % (< 10 %): không thấy dấu hiệu CPU hạ xung giữa đợt đo.

## 2. Tính đúng

Nạp qua API CE, mỗi dataset một database sạch (`docker compose down -v` rồi dựng lại). Chỉ xuất khi phân tích đã xong (`datapipe=idle`, job `Complete`, `last_complete_analysis_at` sau lúc kết thúc job).

| | node | cạnh (mọi loại) | cạnh 22 loại (`edges_22.csv`) | Tier 0 (`tier0.csv`) | principal ngoài T0 (User/Group/Computer) | tới được T0 theo `reach_22` | … trong đó User | tới được T0 theo `reach_all` (65 loại) |
|---|---|---|---|---|---|---|---|---|
| **D0** | 1 520 | 16 654 | 11 862 | 280 | 277 | **65** | 34 | 72 |
| **D1** | 784 | 8 268 | 5 745 | 187 | 173 | **19** | 14 | 25 |

Số cạnh theo loại trong tập 22 (D0 / D1): MemberOf 304/199 · Contains 1416/729 · **AdminTo 24/19** · HasSession 29/5 · GenericAll 3292/1008 · GenericWrite 579/323 · WriteDacl 2221/1317 · WriteOwner 2187/1316 · Owns 1439/722 · ForceChangePassword 52/1 · AddMember 93/1 · AllowedToDelegate 1/0 · **DCSync 8/6** · GPLink 27/8 · AllExtendedRights 187/88 · ReadLAPSPassword 1/0 · AddSelf 1/1 · AllowedToAct 1/0 · CanRDP 0/0 · CanPSRemote 0/0 · ExecuteDCOM 0/0 · SQLAdmin 0/2.

- `AdminTo` và `DCSync` là cạnh do bước phân tích của CE sinh ra; cả hai dataset đều có. D1 cũng có `AdminTo` (19).
- `prebuilt_tier0.json` ("Shortest paths to Tier Zero / High Value targets", `LIMIT 1000`): D0 có 286 node / 440 cạnh, D1 có 194 node / 315 cạnh trong đồ thị trả về.
- Kiểm chéo (`results/<ds>/crosscheck.txt`): `dist` của `p4` (từng user) trùng `reach_22.csv` cho **mọi** user ngoài T0 (D0: 68/68, D1: 28/28). `p1` cho đúng 65 (D0) / 19 (D1) nguồn có `dist`, khớp `reach_22.csv`. `p2` không kiểm được (timeout, xem Vướng 1).

## 3. Hiệu năng

Thời gian một lần chạy = `neo4j_ready_ms + neo4j_consumed_ms`, do Neo4j báo qua `cypher-shell --format verbose`. `wall` gồm cả khởi động JVM cypher-shell + `docker exec` (~1,3–2 s), chỉ để tham khảo. "Lạnh" = lần đầu ngay sau `docker compose restart graph-db` (xem Vướng 6). Mỗi câu chạy 1 PROFILE + 1 lạnh + 5 ấm, timeout 300 s.

### Nạp và phân tích

| | ingest_s | analysis_s | upload → phân tích xong (s) | store_bytes (sau checkpoint) | tx_log_bytes | RAM graph-db sau phân tích | RAM bloodhound sau phân tích |
|---|---|---|---|---|---|---|---|
| **D0** | 14.607 | 11.220 | 51.227 | 22 989 123 ¹ | 262 148 352 ² | 1020 MiB | 1.223 GiB |
| **D1** | 17.671 | 6.890 | 57.419 | 21 289 821 | 262 149 120 ² | 820.7 MiB | 2.31 GiB |

- `ingest_s` = `Ingest run finished.duration` (log bloodhound), chỉ phần datapipe ingest. `analysis_s` = `Graph Analysis` elapsed (post-processing AD + Azure + gắn Tier Zero / asset group). "upload → phân tích xong" có cả thời gian chờ chu kỳ datapipe (~25–30 s). Chi tiết từng bước: `results/<ds>/ingest.json`.
- ¹ D0 store đo trên **lần nạp lại** D0 vào DB sạch (xem Vướng 2). ² tx log là file preallocate 262 144 000 B, không phản ánh lượng dữ liệu ghi.
- RAM là một lần chụp `docker stats` (MiB/GiB nhị phân), không phải đỉnh.

### Truy vấn

**D0**

| query_id | rows | result_value | db hits (PROFILE) | lạnh (ms) | trung vị ấm (ms) | min–max ấm (ms) | wall trung vị ấm (ms) | status |
|---|---|---|---|---|---|---|---|---|
| p1_reach_per_source | 277 | 65 | 174 371 | 4 627 | 3 275 | 3 254–3 314 | 4 661 | ok |
| p2_exists_all | — | — | — (PROFILE timeout) | timeout (>300 s) | 5/5 timeout | — | — | timeout |
| p3_reverse_traversal | | | | | | | | skipped (CE không bật APOC) |
| p5_prebuilt | 1000 | 1000 | 117 633 | 1 155 | 385 | 338–452 | 2 334 | ok |

`p4_single_source`: 68 user × (1 lạnh + 3 ấm) trong một phiên cypher-shell (wall cả phiên 8 845 ms). db hits PROFILE 5 user đầu: 563, 563, 839, 839, 839.

| p4 lượt | n | p50 (ms) | p95 (ms) | max (ms) | trung bình (ms) |
|---|---|---|---|---|---|
| lạnh (lượt 1) | 68 | 26 | 61 | 475 | 35.0 |
| ấm (lượt 2–4) | 204 | 17 | 34 | 58 | 20.5 |

**D1**

| query_id | rows | result_value | db hits (PROFILE) | lạnh (ms) | trung vị ấm (ms) | min–max ấm (ms) | wall trung vị ấm (ms) | status |
|---|---|---|---|---|---|---|---|---|
| p1_reach_per_source | 173 | 19 | 67 134 | 2 319 | 884 | 851–1 075 | 2 188 | ok |
| p2_exists_all | — | — | — (PROFILE timeout) | timeout (>300 s) | 5/5 timeout | — | — | timeout |
| p3_reverse_traversal | | | | | | | | skipped (CE không bật APOC) |
| p5_prebuilt | 1000 | 1000 | 127 742 | 1 915 | 947 | 905–1 046 | 2 919 | ok |

`p4_single_source`: 28 user × (1 lạnh + 3 ấm), wall cả phiên 4 411 ms. db hits PROFILE 5 user đầu: 479 × 5.

| p4 lượt | n | p50 (ms) | p95 (ms) | max (ms) | trung bình (ms) |
|---|---|---|---|---|---|
| lạnh (lượt 1) | 28 | 15 | 71 | 638 | 45.8 |
| ấm (lượt 2–4) | 84 | 12 | 29 | 36 | 15.6 |

Thời gian chờ Neo4j nhận truy vấn sau `restart graph-db`: 14–31 s (`logs/queries/<ds>/*.restart.txt`).

## 4. Vướng

1. **`p2_exists_all` timeout ở mọi lần chạy, cả hai dataset** (PROFILE, lạnh, 5 ấm, mỗi lần 300 s; query bị kill trên server bằng `dbms.killQuery`, kiểm bằng `dbms.listQueries`). Câu chạy nguyên văn theo đề, Neo4j 4.4 chấp nhận `EXISTS { }` (EXPLAIN chạy được, có trong `logs/queries/<ds>/p2_exists_all.explain.txt`). Pattern `[:…*1..]` trong `EXISTS` không dùng shortestPath. Nó liệt kê đường đi (chỉ cấm lặp cạnh, không cấm lặp đỉnh), nên bùng nổ trên các chu trình ACL. Graph-db ăn ~100 % một core suốt 300 s. Hệ quả:
   - không có db hits cho p2;
   - **không kiểm chéo được p2 với p1**. Giá trị cần khớp là số User tới được T0 theo `reach_22`: D0 = 34, D1 = 14. Mình không thay câu truy vấn nên không có số p2 nào khác.
   - người dùng đã chọn chạy đủ 7 lần mỗi dataset dù biết sẽ timeout.
2. **`store_bytes` đo ngay sau phân tích không có nghĩa**: `du -sb` lúc đó = 18 184 908 B, đúng bằng DB rỗng, vì Neo4j chưa checkpoint. Neo4j 4.4 Community không có `db.checkpoint()` nên mình ép checkpoint bằng `docker compose restart graph-db` (shutdown sạch) rồi đo lại (`scripts/store_after_restart.sh`).
   - D1: đo trên chính DB D1 sau các phép đo.
   - D0: DB gốc đã bị xoá (`down -v`) trước khi phát hiện, nên **nạp lại D0** vào DB sạch (người dùng đồng ý, `down -v` lần 2) chỉ để đo store: `logs/ingest/d0_store_rerun/`, RUNLOG mục 49–53. Lần nạp lại cho cùng 1 520 node / 16 654 cạnh / 280 Tier 0.
   - Lần nạp lại có `ingest` 17,0 s, `analysis` 20,2 s, so với lần chính 14,6 s / 11,2 s. **Số ingest/phân tích chỉ có một mẫu chính thức mỗi dataset và dao động lớn giữa các lần**. `results/d0/ingest.json` vẫn dùng lần chính.
   - Số chưa flush vẫn giữ trong `ingest.json` (`store_bytes_right_after_analysis_unflushed`).
3. **`tx_log_bytes`** = kích thước file `neostore.transaction.db.0` được preallocate (262 144 000 B) + file checkpoint. Không phải lượng log thật.
4. **RAM trống của máy < 5 GB** suốt đợt chạy (0,56–0,97 GB theo `Win32_OperatingSystem.FreePhysicalMemory`). Máy 8 GB và WSL được cấp 5 GB nên không thể đạt mức 5 GB trống. Không thấy dấu hiệu OOM: không có `137`/`OOMKilled`/`OutOfMemory` trong `logs/`, container cuối cùng đều `OOMKilled=false`. Container của các lần dựng trước đã bị xoá nên không kiểm `State` của chúng được.
5. **Chế độ nguồn**: lần chụp `hardware.txt` đầu tiên (RUNLOG mục 6) diễn ra khi Energy saver đang bật (Best power efficiency). Người dùng đã tắt rồi chọn Best performance **trước** cpu_ref và mọi phép đo (mục 7). Trước ingest D1, lệnh kiểm chế độ nguồn bị lỗi quoting, nên trạng thái đúng lúc đó không có số đo. Kiểm lại 1 phút sau ingest là Best performance (RUNLOG có ghi). Từ đó dùng `scripts/power_state.ps1`.
6. **"Lạnh" không lạnh hoàn toàn**: cold = ngay sau restart container Neo4j (JVM mới, page cache rỗng), nhưng `dbms.memory.pagecache.warmup.enable=true` (mặc định) có thể nạp lại trang từ profile, và page cache của OS trong WSL không bị xoá.
7. **`prebuilt_tier0.json`** được lấy qua **API CE** `POST /api/v2/graphs/cypher` (endpoint mà ô Cypher của UI gọi) với câu prebuilt đã thay biến, chứ **không** bấm trên UI. File là response JSON nguyên vẹn. `p5_prebuilt` thì chạy thẳng trên Neo4j bằng cypher-shell, không đi qua lớp API/translator của CE.
8. **p4**: các user chạy trong **một** phiên cypher-shell, nên timeout tính cho cả phiên (1 200 s = 4 × 300 s), không tính cho từng câu. Không có câu nào lâu hơn 638 ms nên không ảnh hưởng.
9. **Sửa compose so với bản gốc**: ghim `tag@digest` (bản gốc dùng `latest`), bỏ mật khẩu mặc định (lấy từ `.env`), thêm `bhe_default_admin_password` để login API. Không đổi gì về bộ nhớ hay port.
10. **Lỗi đã gặp và xử lý**: tag image Docker Hub là `9.9.2`, không có `v` như git tag (mục 1 lỗi, mục 4 kéo lại). Mục 9 `compose-up` chờ `/api/version` vốn cần auth (401), nên "duration 318 s" không phải thời gian khởi động CE. Lần dựng sau (mục 28) chờ bằng login, mất 36 s.
11. Danh sách `p4_users` gồm cả principal well-known như `GHOST.CORP-S-1-5-20` (có nhãn `User`), đúng theo câu `MATCH (u:User) WHERE NOT u:Tag_Tier_Zero`.
12. `logs/env/after/neo4j.txt` chụp khi DB đang chứa D1. Trạng thái stack cuối cùng: DB chứa D0 (lần nạp lại để đo store).

## 5. Checklist

- [x] Docker + compose CE chạy, image ghim phiên bản, cổng chỉ trên 127.0.0.1; source CE đúng tag ở `vendor/` (`logs/env/ce_source.txt`)
- [x] `logs/env/before` và `after` đủ file; `cpu_ref` chạy 3 lần trước + 3 lần sau
- [x] D0, D1 nạp vào hai database sạch riêng; phân tích xong trước khi xuất; mốc thời gian đã ghi
- [x] Mỗi dataset đủ file ở `results/<ds>/`; `edges_22.csv` có cạnh dẫn xuất (`DCSync` 8/6, `AdminTo` 24/19); `tier0.csv` không rỗng (280/187)
- [x] `perf.csv` có dòng PROFILE (db hits; p2 PROFILE timeout nên trống) và đủ 1 lạnh + 5 ấm cho `p1`, `p2`, `p5` (`p4`: 1 + 3 mỗi user; `p3`: một dòng skipped)
- [x] `RUNLOG.md` có mọi lệnh, kể cả lần lỗi; `logs/raw/` đủ đầu ra
- [x] Không có mật khẩu, `.env`, tên máy, tên user, đường dẫn home, zip dữ liệu trong repo (grep lại trước khi push)
