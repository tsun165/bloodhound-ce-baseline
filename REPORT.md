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

## 6. Câu hỏi bổ sung 19/11

Chạy ngày 2026-11-19, RUNLOG mục 56–86. Cùng stack, cùng image digest. Câu truy vấn nằm ở `queries/extra/` (chép nguyên văn vào `results/<ds>/queries.md`). Script mới gồm `scripts/export_extra.sh` (Q2–Q4), `scripts/check_extra.sh` (kiểm Q3, Q4) và `scripts/csvcol.pl` (đọc cột CSV có ngoặc kép). Script và kết quả cũ không bị sửa.

**Chuẩn bị.** Docker Desktop đang tắt nên mình bật lại (mục 56), rồi `docker compose up -d` với volume cũ (mục 57). DB lúc đó chứa D0, bản nạp lại ngày 16/11. So với `results/d0/` (mục 58–60):
- node và `edges_22.csv` khớp, `edges_22.csv` giống từng byte;
- Tier 0 cùng 280 objectid, chỉ khác thứ tự nhãn trong cột `labels`;
- **tổng cạnh lệch: 16 663, lần chính 16 654**, xem Vướng 19/11 số 1.

Theo lựa chọn của người dùng, mình chạy tiếp trên DB này. Sau D0, `docker compose down -v` (người dùng đồng ý, mục 73), dựng lại (74), xác nhận DB rỗng (75), rồi nạp D1 bằng `scripts/ingest.sh` với 3 zip trong 1 job (mục 76, log ở `logs/ingest/d1_extra/`). D1 sau khi nạp khớp `results/d1/` hoàn toàn (mục 77): node, 8 268 cạnh, `edges_22.csv` giống từng byte, 187 Tier 0. Các file khác chỉ khác thứ tự dòng khi bằng nhau hoặc thứ tự nhãn.

### Q1. Selector Tier Zero

- Lệnh: `queries/extra/q1_selectors_tier_zero.sql` qua `psql --csv` trong `app-db` (mục 62) → `results/selectors_tier_zero.csv`, **44 dòng**. Cả 44 đều `is_default=t`, `enabled=t`; `allow_disable`: 17 `f`, 27 `t`. Sau `down -v`, app-db mới cho danh sách giống từng byte (mục 85).
- **Có** bảng `asset_group_tag_selector_nodes` (`\dt`, mục 61; cột `selector_id, node_id, node_object_id, …`). Câu `queries/extra/q1_tier0_by_selector.sql` → `results/<ds>/extra/tier0_by_selector.csv` (`objectid, selector_name`; một node có thể thuộc nhiều selector):
  - D0 (mục 63): **438 dòng**, 280 objectid khác nhau = đúng tập `results/d0/tier0.csv`, 31/44 selector có node.
  - D1 (mục 84, xuất thêm vì app-db đã tạo mới): **255 dòng**, 187 objectid = đúng tập `results/d1/tier0.csv`, 28/44 selector có node.
- Vướng: lần kiểm đầu (mục 64) báo lệch 1 objectid. Lỗi nằm ở câu kiểm: `cut -d,` tách sai objectid dạng DN có dấu phẩy (`CN=ENTERPRISE ADMINS,OU=GROUPS,…`). Kiểm lại bằng parser CSV (mục 65) thì 0 lệch.

### Q2. `LocalToComputer`, `MemberOfLocalGroup`

| | `local_to_computer.csv` | `member_of_local_group.csv` |
|---|---|---|
| D0 (mục 67, 68) | 29 dòng | 52 dòng |
| D1 (mục 79, 80) | 22 dòng | 50 dòng |

Cột đúng như đề. Không có kiểm chéo nào được yêu cầu. Lưu ý: thứ tự phần tử trong `labels(...)` có thể đổi sau khi restart Neo4j, nên so các cột nhãn theo tập hợp (Vướng 19/11 số 2).

### Q3. Mọi cạnh thuộc 65 loại transit

- `queries/extra/q3_edges_all.cypher` (danh sách sinh từ `queries/ad_transit_edge_types.txt`, 65 chuỗi) → `results/<ds>/extra/edges_all.csv`. D0 có **12 213 dòng** (40 loại có cạnh), D1 có **5 882 dòng** (29 loại). Số cạnh theo loại nằm trong `logs/raw/072-check-extra-d0.log` và `086-check-extra-d1.log`.
- **Kiểm** (mục 72, 86): các dòng có `kind` thuộc 22 loại, lọc từ `edges_all.csv`, **giống từng byte `edges_22.csv`** (cùng dòng, cùng thứ tự). D0 có 11 862 = 11 862, D1 có 5 745 = 5 745.
- D0: `edges_all.csv` lấy từ DB D0 nạp lại. Các loại ADCSESC9a/9b/10a/10b là 17/12/9/10, khác lần chính (Vướng 19/11 số 1).

### Q4. Đường ngắn nhất theo từng cặp (nguồn, Tier 0), 22 loại

- `queries/extra/q4_ce_paths_22.cypher` → `results/<ds>/extra/ce_paths_22.csv`, chạy lần 2 → `ce_paths_22_run2.csv`.

| | dòng | `src` khác nhau | số đường mỗi `src` (min/max) | lần 1 / lần 2 (wall, s) |
|---|---|---|---|---|
| D0 (mục 70, 71) | 446 | 65 | 1 / 9 | 9.6 / 6.7 |
| D1 (mục 82, 83) | 36 | 19 | 1 / 18 | 4.5 / 4.8 |

- **Kiểm với `reach_22.csv`** (mục 72, 86): tập `(src, dist)` khác nhau của `ce_paths_22.csv` **trùng khớp** tập `(objectid, dist)` của các dòng có `dist` khác `NULL` trong `reach_22.csv`. D0 có 65 = 65, D1 có 19 = 19.
- **Độ ổn định**: `diff ce_paths_22.csv ce_paths_22_run2.csv` cho kết quả **giống từng byte** ở cả D0 và D1 (0 `src` có đường khác). Hai lần chạy liên tiếp, không restart Neo4j. Trong câu này `shortestPath` chỉ trả **một** đường cho mỗi cặp (s, t), nên "ổn định" ở đây nghĩa là Neo4j chọn cùng một đường trong hai lần chạy. Chưa thử qua restart hay nạp lại.
- **UI CE khi bấm một node** (đọc source `vendor/BloodHound` @ v9.9.2, không chạy):
  - Bảng thông tin node (Entity panel) **không có mục nào hiện đường tới Tier 0**. Với AD User có các mục: Sessions, Member Of, Local Admin Privileges, Execution Privileges, Outbound/Inbound Object Control (`packages/javascript/bh-shared-ui/src/utils/content.ts:1080-1137`). Trong `content.ts` không có `label` nào chứa "path". Mục duy nhất có "Tier Zero" là "Tier Zero Objects" của GPO (danh sách object bị GPO tác động, không phải đường đi; `content.ts:936-937`). Mình mới đọc kỹ nhóm mục của User. Với các loại node khác thì chỉ dựa vào việc grep nhãn.
  - Đường đi trong UI có từ menu chuột phải "Set as starting node" / "Set as ending node" (`packages/javascript/bh-shared-ui/src/views/Explore/ContextMenu/ContextMenuPrivilegeZonesEnabled.tsx:94-95`, bản cũ ở `cmd/ui/src/views/Explore/ContextMenu/ContextMenu.tsx:77-78`). Luồng gọi:
    1. tab Pathfinding gọi `getShortestPathV2` (`packages/javascript/bh-shared-ui/src/hooks/useExploreGraph/queries/pathfindingSearch.ts:61,77`);
    2. hàm này gửi `GET /api/v2/graphs/shortest-path?start_node=&end_node=&relationship_kinds=&only_traversable=true` (`packages/javascript/js-client-library/src/client.ts:2923-2935`);
    3. route ở `cmd/api/src/api/registration/v2.go:163`, xử lý bởi `GetShortestPath` (`cmd/api/src/api/v2/pathfinding.go:126`);
    4. rồi tới `GraphQuery.GetAllShortestPaths`, dùng `FetchAllShortestPaths` giữa **một** start node và **một** end node cụ thể (`cmd/api/src/queries/graph.go:259-292`).
  - Như vậy endpoint này cần người dùng chọn một node đích cụ thể, không tìm "tới bất kỳ node Tier 0 nào". Nó trả **mọi** đường ngắn nhất giữa cặp đó (all shortest paths), còn Q4 dùng `shortestPath` (một đường mỗi cặp).
  - Câu Cypher cụ thể mà driver dawgs sinh ra cho `FetchAllShortestPaths`: **chưa kiểm**.

### Vướng 19/11

1. **DB D0 nạp lại lệch +9 cạnh so với lần chính**. ADCSESC9a 14→17, ADCSESC9b 10→12, ADCSESC10a 7→9, ADCSESC10b 8→10; các loại khác cùng số (mục 58, 60). Nguyên nhân **chưa rõ**, có hai khả năng chưa tách được:
   - CE tự chạy lại analysis khi khởi động (`last_analysis_run_at` 2026-11-18T22:32:50Z, mục 57);
   - lần nạp lại D0 hôm 16/11 đã cho số này từ trước (hôm đó chỉ đếm node và Tier 0, không đếm cạnh).

   Người dùng chọn chạy tiếp. Ảnh hưởng: Q2 và Q4 không bị ảnh hưởng (`edges_22` giống từng byte, `reach_22` khớp). `results/d0/extra/edges_all.csv` phản ánh DB nạp lại, không phải lần chính. D1 nạp mới không lệch.
2. **Thứ tự nhãn trong `labels()` không cố định** giữa các lần khởi động Neo4j: `tier0.csv` D0 khác byte chỉ vì thứ tự nhãn (mục 60). Các file có cột nhãn (`local_to_computer.csv`, `member_of_local_group.csv`) nên so theo tập hợp.
3. Trạng thái cuối: stack đang chạy, DB chứa **D1**. Bản D0 nạp lại đã bị xoá bằng `down -v` (mục 73).
