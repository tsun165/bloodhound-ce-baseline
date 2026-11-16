"""Print the markdown tables used in REPORT.md from results/<ds>/ and logs/env/*/cpu_ref.txt.

  docker run --rm -v "$PWD:/w" -w /w python:3.11-slim python -I scripts/summarize.py d0 d1

Time of one run = neo4j_ready_ms + neo4j_consumed_ms (as reported by Neo4j through cypher-shell).
"""
import csv, json, re, statistics, sys


def pct(xs, p):  # nearest-rank percentile
    xs = sorted(xs)
    k = max(1, -(-p * len(xs) // 100))
    return xs[int(k) - 1]


def cpu_ref(phase):
    meds = [float(m) for m in re.findall(r"median_s=([\d.]+)", open(f"logs/env/{phase}/cpu_ref.txt", encoding="utf-8").read())]
    return meds, statistics.median(meds) if meds else None


out = []
b, a = cpu_ref("before"), None
try:
    a = cpu_ref("after")
except FileNotFoundError:
    pass
out.append("### cpu_ref (s, trung vị 5 vòng mỗi lần chạy)\n")
out.append("| | lần 1 | lần 2 | lần 3 | trung vị 3 lần |\n|---|---|---|---|---|")
for name, v in (("trước", b), ("sau", a)):
    if v:
        out.append(f"| {name} | " + " | ".join(f"{x:.3f}" for x in v[0]) + f" | **{v[1]:.3f}** |")
if a:
    out.append(f"\nLệch trung vị sau so với trước: {100 * (a[1] - b[1]) / b[1]:+.1f} %\n")

for ds in sys.argv[1:]:
    R = f"results/{ds}"
    ing = json.load(open(f"{R}/ingest.json", encoding="utf-8"))
    t0 = sum(1 for _ in open(f"{R}/tier0.csv", encoding="utf-8")) - 1
    reach = [r for r in csv.reader(open(f"{R}/reach_22.csv", encoding="utf-8"), skipinitialspace=True)][1:]
    reach_all = [r for r in csv.reader(open(f"{R}/reach_all.csv", encoding="utf-8"), skipinitialspace=True)][1:]
    nodes = {r[0]: r[2] for r in csv.reader(open(f"{R}/nodes.csv", encoding="utf-8"), skipinitialspace=True)}
    reach_users = sum(1 for r in reach if r[-1] != "NULL" and '"User"' in nodes.get(r[0], ""))
    out.append(f"\n## {ds}\n")
    out.append("| node | cạnh (tất cả) | cạnh 22 loại | Tier 0 | principal (User/Group/Computer ngoài T0) | tới được T0 theo `reach_22` | trong đó User | theo `reach_all` |")
    out.append("|---|---|---|---|---|---|---|---|")
    out.append(f"| {ing['node_count']} | {ing['edge_count']} | {ing['edge_count_22_kinds']} | {t0} | {len(reach)} | "
               f"{sum(1 for r in reach if r[-1] != 'NULL')} | {reach_users} | {sum(1 for r in reach_all if r[-1] != 'NULL')} |")
    out.append("")
    out.append("| ingest_s | analysis_s | upload→phân tích xong (s) | store_bytes | tx_log_bytes | RAM graph-db | RAM bloodhound |")
    out.append("|---|---|---|---|---|---|---|")
    out.append(f"| {ing['ingest_s']} | {ing['analysis_s']} | {ing['upload_to_analysis_complete_s']} | {ing['store_bytes']} | {ing['tx_log_bytes']} | "
               f"{ing['ram_graph_db_raw'].split('/')[0].strip()} | {ing['ram_bloodhound_raw'].split('/')[0].strip()} |")

    perf = list(csv.DictReader(open(f"{R}/perf.csv", encoding="utf-8")))
    t = lambda r: int(r["neo4j_ready_ms"]) + int(r["neo4j_consumed_ms"])
    out.append("\n| query_id | rows | result_value | db hits (PROFILE) | lạnh (ms) | trung vị ấm (ms) | min–max ấm (ms) | wall trung vị ấm (ms) | status |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    for q in ("p1_reach_per_source", "p2_exists_all", "p3_reverse_traversal", "p5_prebuilt"):
        rs = [r for r in perf if r["query_id"] == q]
        if q == "p3_reverse_traversal":
            out.append(f"| {q} | | | | | | | | skipped (CE không bật APOC) |"); continue
        prof = next(r for r in rs if r["run"] == "profile")
        cold = next(r for r in rs if r["cache"] == "cold")
        warm = [r for r in rs if r["cache"] == "warm"]
        ok = [r for r in warm if r["status"] == "ok"]
        st = sorted({r["status"] for r in rs if r["run"] != "explain"})
        if ok:
            ws = [t(r) for r in ok]
            wall = statistics.median(int(r["wall_ms"]) for r in ok)
            out.append(f"| {q} | {cold['rows']} | {cold['result_value']} | {prof['db_hits'] or '—'} | {t(cold) if cold['status']=='ok' else cold['status']} | "
                       f"{statistics.median(ws):.0f} | {min(ws)}–{max(ws)} | {wall:.0f} | {','.join(st)} |")
        else:
            out.append(f"| {q} | — | — | {prof['db_hits'] or '— (PROFILE ' + prof['status'] + ')'} | {cold['status']} (>{int(cold['wall_ms'])/1000:.0f} s wall) | "
                       f"{len(warm)}/{len(warm)} {warm[0]['status'] if warm else ''} | — | — | {','.join(st)} |")
    p4 = [r for r in perf if r["query_id"] == "p4_single_source" and r["cache"] in ("cold", "warm")]
    if p4:
        cold = [t(r) for r in p4 if r["cache"] == "cold"]
        warm = [t(r) for r in p4 if r["cache"] == "warm"]
        prof = [int(r["db_hits"]) for r in perf if r["query_id"] == "p4_single_source" and r["run"] == "profile"]
        sess = next(r for r in perf if r["run"] == "session_total" and r["query_id"] == "p4_single_source")
        out.append(f"\n`p4_single_source`: {len(cold)} user × (1 lạnh + 3 ấm) trong một phiên cypher-shell (wall cả phiên {sess['wall_ms']} ms). "
                   f"db hits PROFILE 5 user đầu: {prof}.\n")
        out.append("| lượt | n | p50 (ms) | p95 (ms) | max (ms) | trung bình (ms) |\n|---|---|---|---|---|---|")
        for name, xs in (("lạnh (lượt 1)", cold), ("ấm (lượt 2–4)", warm)):
            out.append(f"| {name} | {len(xs)} | {pct(xs, 50)} | {pct(xs, 95)} | {max(xs)} | {statistics.mean(xs):.1f} |")
print("\n".join(out))
