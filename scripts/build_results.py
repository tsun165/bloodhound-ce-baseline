"""Build results/<ds>/{perf.csv,p4_users.csv,ingest.json,env.json,queries.md} from raw logs.

Run (stdlib only, no measurements in progress):
  docker run --rm -v "$PWD:/w" -w /w python:3.11-slim python -I scripts/build_results.py d0
"""
import csv, glob, json, os, re, sys
from datetime import datetime

ds = sys.argv[1]
Q, S, I, R = f"logs/queries/{ds}", f"logs/stats/{ds}", f"logs/ingest/{ds}", f"results/{ds}"

TIMING = re.compile(r"ready to start consuming query after (\d+) ms, results consumed after another (\d+) ms")
ROWS = re.compile(r"^(\d+) rows?$")
SUMMARY = re.compile(r'^\| "(PROFILE|EXPLAIN)"\s*\|\s*"[^"]*"\s*\|\s*"[^"]*"\s*\|\s*"[^"]*"\s*\|\s*"([^"]*)"\s*\|(.*)\|\s*$')


def segments(path):
    """Split a verbose cypher-shell output into one segment per statement (ends at the timing line)."""
    seg, out = [], []
    for line in open(path, encoding="utf-8", errors="replace").read().splitlines():
        seg.append(line)
        if TIMING.search(line):
            out.append(seg)
            seg = []
    return out, seg  # seg = trailing lines without timing (error / timeout)


def parse_segment(seg):
    d = {"ready": "", "consumed": "", "rows": "", "db_hits": "", "table": [], "runtime": ""}
    m = TIMING.search(seg[-1])
    d["ready"], d["consumed"] = m.group(1), m.group(2)
    for line in seg:
        r = ROWS.match(line.strip())
        if r:
            d["rows"] = r.group(1)
        s = SUMMARY.match(line)
        if s:
            cells = [c.strip() for c in s.group(3).split("|")]
            d["runtime"] = s.group(2)  # Time | DbHits | Rows | Memory
            if s.group(1) == "PROFILE" and len(cells) >= 2:
                d["db_hits"] = cells[1]
    # first table = result table
    i = next((k for k, l in enumerate(seg) if l.startswith("+")), None)
    if i is not None and i + 2 < len(seg) and not SUMMARY.match(seg[i + 1]):
        for l in seg[i + 3:]:
            if l.startswith("+") or not l.startswith("|"):
                break
            d["table"].append([c.strip() for c in l.strip().strip("|").split("|")])
    return d


def result_value(qid, d):
    t = d["table"]
    if qid == "p1_reach_per_source":  # number of sources with non-null dist
        return str(sum(1 for r in t if r and r[-1] != "NULL"))
    if qid == "p2_exists_all":
        return t[0][0] if t else ""
    if qid == "p4_single_source":
        return "" if not t or t[0][-1] == "NULL" else t[0][-1]
    return d["rows"]


manifest = list(csv.DictReader(open(f"{Q}/manifest.tsv", encoding="utf-8"), delimiter="\t"))
rows, p4_pass = [], {}
users = [l.strip().strip('"') for l in open(f"{Q}/p4_users_list.txt", encoding="utf-8").read().splitlines()[1:] if l.strip()]
for m in manifest:
    qid, run, status, f = m["query_id"], m["run"], m["status"], m["file"]
    base = {"dataset": ds, "query_id": qid, "param": m["param"], "run": run, "cache": m["cache"],
            "neo4j_ready_ms": "", "neo4j_consumed_ms": "", "wall_ms": m["wall_ms"], "rows": "",
            "result_value": "", "db_hits": "", "status": status}
    if status == "skipped":
        rows.append(base); continue
    segs, tail = segments(f)
    if qid == "p4_single_source" and run in ("profile", "session"):
        params = users[:5] if run == "profile" else [u for _ in range(4) for u in users]
        for k, seg in enumerate(segs):
            d = parse_segment(seg)
            r = dict(base, param=params[k], neo4j_ready_ms=d["ready"], neo4j_consumed_ms=d["consumed"],
                     wall_ms="", rows=d["rows"], result_value=result_value(qid, d), status="ok")
            if run == "profile":
                r["db_hits"] = d["db_hits"]
            else:
                p = k // len(users) + 1
                r["run"], r["cache"] = str(p), ("cold" if p == 1 else "warm")
                p4_pass.setdefault(params[k], {})[p] = r["result_value"]
            rows.append(r)
        if run == "session":
            rows.append(dict(base, param="all_users", run="session_total",
                             rows=str(len(segs)), result_value=f"{len(segs)} statements",
                             status=status if len(segs) == 4 * len(users) else f"{status};incomplete"))
        continue
    if not segs:
        rows.append(base); continue
    d = parse_segment(segs[0])
    base.update(neo4j_ready_ms=d["ready"], neo4j_consumed_ms=d["consumed"], rows=d["rows"],
                result_value="" if run == "explain" else result_value(qid, d),
                db_hits=d["db_hits"] if run == "profile" else "")
    rows.append(base)

cols = "dataset,query_id,param,run,cache,neo4j_ready_ms,neo4j_consumed_ms,wall_ms,rows,result_value,db_hits,status".split(",")
with open(f"{R}/perf.csv", "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=cols, lineterminator="\n"); w.writeheader(); w.writerows(rows)

# p4_users.csv (dist from pass 1 = cold) + consistency checks
checks = []
with open(f"{R}/p4_users.csv", "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh, lineterminator="\n"); w.writerow(["objectid", "dist"])
    for u in users:
        w.writerow([u, p4_pass.get(u, {}).get(1, "")])
        vals = set(p4_pass.get(u, {}).values())
        if len(vals) != 1:
            checks.append(f"p4 passes disagree for {u}: {p4_pass.get(u)}")

reach = {}
for r in csv.reader(open(f"{R}/reach_22.csv", encoding="utf-8"), skipinitialspace=True):
    if r and r[0] != "objectid":
        reach[r[0]] = "" if r[-1] == "NULL" else r[-1]
p4_vs_reach = [u for u in users if p4_pass.get(u, {}).get(1, "") != reach.get(u, "MISSING")]
checks.append(f"p4 dist == reach_22 dist for all {len(users)} non-T0 users: {not p4_vs_reach}"
              + (f" (mismatch: {p4_vs_reach})" if p4_vs_reach else ""))
p2 = [r["result_value"] for r in rows if r["query_id"] == "p2_exists_all" and r["run"] not in ("explain",) and r["status"] == "ok"]
users_reach = sum(1 for u in users if reach.get(u, "") != "")
checks.append(f"p2 count values (profile/cold/warm): {sorted(set(p2))}; Users with non-null dist in reach_22.csv: {users_reach}; "
              f"equal: {set(p2) == {str(users_reach)}}")
p1 = sorted({r["result_value"] for r in rows if r["query_id"] == "p1_reach_per_source" and r["run"] != "explain"})
checks.append(f"p1 non-null dist counts: {p1}; reach_22.csv non-null: {sum(1 for v in reach.values() if v)}")
open(f"{R}/crosscheck.txt", "w", encoding="utf-8").write("\n".join(checks) + "\n")
print("\n".join(checks))


# ---------- ingest.json ----------
def bh_events():
    ev = []
    for line in open(f"{I}/bloodhound.log", encoding="utf-8", errors="replace"):
        j = line.find("{")
        if j < 0: continue
        try:
            ev.append(json.loads(line[j:]))
        except json.JSONDecodeError:
            pass
    return ev


def ts(s):
    s = s.rstrip("Z")
    if "." in s:
        a, b = s.split("."); s = f"{a}.{b[:6]}"
    return datetime.fromisoformat(s)


timeline = open(f"{I}/timeline.log", encoding="utf-8").read().splitlines()
def tl(key):
    return [l.split()[1] for l in timeline if l.split()[2].startswith(key)]
upload_begin = tl("upload_begin")
upload_end = tl("upload_end")
job_end_call = tl("job_end_call")[0]
done_line = [l for l in timeline if " done " in l][0]
dp_done = json.loads(re.search(r"datapipe=(\{.*?\}\}) job=", done_line).group(1))["data"]
job_done = json.loads(re.search(r"job=(\{.*\})$", done_line).group(1))["data"][0]

ev = [e for e in bh_events() if "time" in e and ts(e["time"]) >= ts(upload_begin[0])]
starts = [e for e in ev if e.get("message") == "Ingest run starting"]
fins = [e for e in ev if e.get("message") == "Ingest run finished"]
ga = [e for e in ev if e.get("message") == "Graph Analysis" and e.get("scope") == "summary"]
ga_start = next(e for e in ga if "elapsed" not in e)
ga_end = next(e for e in ga if "elapsed" in e)
tier0 = [e for e in ev if e.get("message") == "AGT: Completed in memory tagging" and e.get("tag_name") == "Tier Zero"]
steps = {e["message"]: round(e["elapsed"] / 1000, 3) for e in ev
         if e.get("namespace") == "analysis" and e.get("scope") == "step" and "elapsed" in e}


def mem_bytes(s):
    m = re.match(r"([\d.]+)\s*([KMGT]?i?B)", s)
    mult = {"B": 1, "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "TiB": 1024**4, "kB": 1000, "MB": 1000**2, "GB": 1000**3}
    return int(float(m.group(1)) * mult[m.group(2)])


stats = {}
for l in open(f"{S}/after_analysis.txt", encoding="utf-8"):
    p = re.split(r"\s{2,}", l.strip())
    if len(p) >= 4 and p[0] != "CONTAINER ID":
        stats[p[1]] = p[3]
def mem_of(svc):
    k = next(k for k in stats if k.endswith(f"-{svc}-1"))
    return mem_bytes(stats[k].split("/")[0].strip()), stats[k]

store = {}
for l in open(f"{S}/store_size.txt", encoding="utf-8"):
    m = re.match(r"^(\d+)\s+(/data/\S+)$", l.strip())
    if m:
        store[m.group(2)] = int(m.group(1))

node_count = sum(1 for _ in open(f"{R}/nodes.csv", encoding="utf-8")) - 1
edge_count = sum(int(r[1]) for r in csv.reader(open(f"{R}/edge_counts.csv", encoding="utf-8"), skipinitialspace=True) if r and r[0] != "kind")
edges22 = sum(1 for _ in open(f"{R}/edges_22.csv", encoding="utf-8")) - 1
ram_g, ram_g_raw = mem_of("graph-db"); ram_b, ram_b_raw = mem_of("bloodhound")

ingest = {
    "dataset": ds,
    "method": "CE API: POST /api/v2/file-upload/start -> POST /api/v2/file-upload/{id} (application/zip) per zip -> POST /api/v2/file-upload/{id}/end; poll every 5 s",
    "ingest_s": round(sum(e["duration"] for e in fins) / 1e9, 3),
    "ingest_s_definition": "sum of 'Ingest run finished'.duration (bloodhound log) = datapipe ingest work only, excludes upload and wait for datapipe tick",
    "analysis_s": round(ga_end["elapsed"] / 1000, 3),
    "analysis_s_definition": "'Graph Analysis' summary elapsed (bloodhound log) = post-processing + Tier Zero / asset group tagging",
    "upload_to_analysis_complete_s": round((ts(ga_end["time"]) - ts(upload_begin[0])).total_seconds(), 3),
    "store_bytes": store.get("/data/databases/neo4j"),
    "tx_log_bytes": store.get("/data/transactions/neo4j"),
    "store_paths": {"store": "/data/databases/neo4j", "tx_log": "/data/transactions/neo4j", "source": f"{S}/store_size.txt (du -sb inside graph-db)"},
    "ram_graph_db_bytes": ram_g, "ram_graph_db_raw": ram_g_raw,
    "ram_bloodhound_bytes": ram_b, "ram_bloodhound_raw": ram_b_raw,
    "ram_source": f"{S}/after_analysis.txt (docker stats --no-stream right after analysis; MiB/GiB = 2^20/2^30)",
    "node_count": node_count,
    "edge_count": edge_count,
    "edge_count_22_kinds": edges22,
    "tier_zero_tagged": tier0[-1].get("tagged") if tier0 else None,
    "analysis_steps_s": steps,
    "timestamps_utc": {
        "upload_begin": upload_begin, "upload_end": upload_end, "job_end_called": job_end_call,
        "ingest_run_starting": [e["time"] for e in starts],
        "ingest_run_finished": [e["time"] for e in fins],
        "graph_analysis_start": ga_start["time"], "graph_analysis_end": ga_end["time"],
        "job_record": {k: job_done[k] for k in ("id", "status", "status_message", "start_time", "end_time", "last_ingest", "total_files", "failed_files", "partial_failed_files")},
        "datapipe_at_done": dp_done,
    },
    "ingest_runs": [{"time": e["time"], "task_count": e.get("task_count"), "duration_s": round(e["duration"] / 1e9, 3)} for e in fins],
    "sources": [f"{I}/timeline.log", f"{I}/datapipe_poll.log", f"{I}/bloodhound.log"],
}
json.dump(ingest, open(f"{R}/ingest.json", "w", encoding="utf-8"), indent=2)

# ---------- env.json ----------
docker_txt = open("logs/env/before/docker.txt", encoding="utf-8").read()
neo = open("logs/env/before/neo4j.txt", encoding="utf-8").read()
hw = open("logs/env/before/hardware.txt", encoding="utf-8").read()
imgs = open("logs/env/before/images.txt", encoding="utf-8").read()
grab = lambda pat, txt: (re.search(pat, txt, re.M).group(1).strip() if re.search(pat, txt, re.M) else None)
zips = [dict(zip(["dataset", "url", "file", "size_bytes", "sha256"], l.split("\t")))
        for l in open("logs/env/datasets.txt", encoding="utf-8").read().splitlines() if l.startswith(ds + "\t")]
for z in zips: z["size_bytes"] = int(z["size_bytes"])
env = {
    "dataset": ds,
    "ce_version": "v9.9.2 (API /api/version server_version=v9.9.2, product_edition=community)",
    "ce_git_tag": "v9.9.2", "ce_git_commit": "93dcb33af324ef6b080f9bd110d65c8ee2ea8bc4",
    "images": {
        "bloodhound": "docker.io/specterops/bloodhound:9.9.2@sha256:47a21323d05185b284fff799c2b96bcc1d110f06f45b190f7ad83e69ef5e0d68",
        "graph-db": "docker.io/library/neo4j:4.4.42@sha256:73b5a47eb9952f47fcc42fcc80bdd6bd0d6b71eea9a1a345c216675498c790e4",
        "app-db": "docker.io/library/postgres:18@sha256:2ea8630df176ad090ec92136dee850397c5af8781e4bcf2e4162593691c61bbc",
    },
    "backend": "neo4j (bhe_graph_driver=neo4j)",
    "neo4j": {"version": grab(r'"Neo4j Kernel", \["([^"]+)"\]', neo), "edition": grab(r'"Neo4j Kernel", \[[^\]]*\], "(\w+)"', neo),
              "pagecache_size": grab(r'"dbms.memory.pagecache.size", "([^"]+)"', neo),
              "heap_initial_size_config": grab(r'"dbms.memory.heap.initial_size", "([^"]+)"', neo),
              "heap_max_size_config": grab(r'"dbms.memory.heap.max_size", "([^"]+)"', neo),
              "heap_jmx": grab(r"^(\{init: .*\})$", neo),
              "apoc_gds_procedures": "none (CALL dbms.procedures() returned no apoc.* / gds.*)"},
    "docker": {"cpus": int(grab(r"^\s*CPUs:\s*(\d+)", docker_txt)), "total_memory": grab(r"^\s*Total Memory:\s*(.+)$", docker_txt),
               "server_version": grab(r"^\s*Server Version:\s*(.+)$", docker_txt), "storage_driver": grab(r"^\s*Storage Driver:\s*(.+)$", docker_txt),
               "kernel": grab(r"^\s*Kernel Version:\s*(.+)$", docker_txt), "wslconfig": "memory=5GB swap=2GB"},
    "host": {"cpu": grab(r"^CPU model\s*:\s*(.+)$", hw), "cores": grab(r"^CPU cores\s*:\s*(.+)$", hw), "threads": grab(r"^CPU threads\s*:\s*(.+)$", hw),
             "ram_total_bytes": int(grab(r"^RAM total bytes:\s*(\d+)", hw)), "os": grab(r"^OS\s*:\s*(.+)$", hw),
             "disk": grab(r"^\s+(.*MediaType=.*)$", hw), "power_mode_ac": grab(r"^Power mode \(AC overlay\):\s*(.+)$", hw)},
    "run_date": ingest["timestamps_utc"]["upload_begin"][0][:10],
    "zips": zips,
    "analysis_complete_utc": ga_end["time"],
    "datapipe_last_complete_analysis_at": dp_done.get("last_complete_analysis_at"),
}
json.dump(env, open(f"{R}/env.json", "w", encoding="utf-8"), indent=2)

# ---------- queries.md ----------
def q(name):
    return open(f"queries/{name}", encoding="utf-8").read().rstrip()
md = [f"# Câu truy vấn đã chạy cho {ds}",
      "",
      "Chép nguyên văn từ `queries/`. Tất cả chạy bằng `docker compose exec -T -e NEO4J_PASSWORD graph-db cypher-shell -u neo4j --format plain < queries/<file>` (tính đúng) "
      "hoặc `--format verbose` (hiệu năng, xem `scripts/perf.sh`).",
      "",
      "- Bản CE 9.9.2 **có** nhãn `Tag_Tier_Zero` (kiểm `CALL db.labels()`), nên dùng đúng nhãn này, không cần điều kiện thay thế. "
      "`n.system_tags CONTAINS 'admin_tier_0'` cho cùng số node (280 với D0 lúc kiểm).",
      "- Tập 22 cạnh = đúng như đề bài. Tập transit đầy đủ (`reach_all`, `p5`) = `adTransitEdgeTypes` trong `commonSearchesAGT.ts` @ v9.9.2, 65 loại, xem `queries/ad_transit_edge_types.txt`.",
      "- `prebuilt_tier0.json`: câu \"Shortest paths to Tier Zero / High Value targets\" (`commonSearchesAGT.ts` dòng 189-191) với `${adTransitEdgeTypes}` và `${TAG_TIER_ZERO_AGT}`=`Tag_Tier_Zero` đã thay giá trị, `\\n` thành xuống dòng. "
      "Gửi qua **API của CE** `POST /api/v2/graphs/cypher` `{query, include_properties:true}` (endpoint mà ô Cypher của UI gọi), không bấm trên UI; file là JSON response nguyên vẹn. Câu gửi đi không có dấu `;` cuối.",
      "- `p2`: Neo4j 4.4 hỗ trợ `EXISTS { MATCH ... }` nên giữ nguyên cú pháp.",
      "- `p3`: bỏ qua, CE không bật APOC.",
      "- `p4`: `$id` truyền bằng `:param id => \"<objectid>\";` trong cùng phiên cypher-shell.",
      ""]
for name in ["q_node_counts", "q_edge_counts", "q_nodes", "q_edges_22", "q_tier0", "q_reach_22", "q_reach_all", "q_prebuilt_tier0",
             "p1_reach_per_source", "p2_exists_all", "p3_reverse_traversal", "p4_users_list", "p4_single_source", "p5_prebuilt"]:
    md += [f"## `{name}.cypher`", "", "```cypher", q(name + ".cypher"), "```", ""]
open(f"{R}/queries.md", "w", encoding="utf-8").write("\n".join(md))
print(f"built {R}: perf.csv ({len(rows)} rows), p4_users.csv, ingest.json, env.json, queries.md, crosscheck.txt")
