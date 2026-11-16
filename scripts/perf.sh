#!/usr/bin/env bash
# Performance runs on the Neo4j that CE loaded. Raw verbose outputs -> logs/queries/<ds>/,
# docker stats -> logs/stats/<ds>/<query_id>.txt, one manifest line per run -> logs/queries/<ds>/manifest.tsv.
# perf.csv is built afterwards by scripts/build_results.py from these files.
# Usage: scripts/perf.sh <ds>
#
# Per query p1, p2, p5: EXPLAIN once, PROFILE once, `docker compose restart graph-db`, wait until
# Neo4j answers, 1 cold run, 5 warm runs. Each run = its own `cypher-shell --format verbose` call;
# the timing used is the one Neo4j reports ("ready to start consuming query after X ms, results
# consumed after another Y ms"); wall_ms (incl. cypher-shell JVM start + docker exec) is kept too.
# p4: EXPLAIN 1 user, PROFILE first 5 users, restart, then ONE cypher-shell session with 4 passes
# over all users (pass 1 = cold, passes 2-4 = warm). p3: skipped (no APOC in CE).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
ds=$1
Q=logs/queries/$ds; S=logs/stats/$ds; mkdir -p "$Q" "$S"
set -a; . ./.env; set +a
M=$Q/manifest.tsv
[ -f "$M" ] || printf 'dataset\tquery_id\tparam\trun\tcache\twall_ms\tstatus\texit\tstarted\tfile\n' > "$M"
TIMEOUT=300

cs() { docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format "$1"; }
ms() { echo $(( $(date +%s%N) / 1000000 )); }
stats() { { echo "## $1 $(date --iso-8601=seconds)"; docker stats --no-stream; echo; } >> "$S/$2.txt"; }
datapipe() { bash scripts/bh_api.sh GET /api/v2/datapipe/status; echo; }
kill_running() {
  echo 'CALL dbms.listQueries() YIELD queryId, query WHERE NOT query CONTAINS "listQueries" CALL dbms.killQuery(queryId) YIELD message RETURN queryId, message;' | cs plain
}
# run_one <query_id> <run> <cache> <outfile> <param> : reads statement(s) on stdin
run_one() {
  local qid=$1 run=$2 cache=$3 out=$4 param=$5 to=${6:-$TIMEOUT}
  local st; st=$(date --iso-8601=seconds); local t0; t0=$(ms)
  timeout "$to" docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format verbose > "$out" 2>&1
  local rc=$?; local t1; t1=$(ms)
  local status=ok
  if [ $rc -eq 124 ]; then status=timeout; echo "### TIMEOUT after ${to}s" >> "$out"; kill_running >> "$out" 2>&1
  elif [ $rc -ne 0 ]; then status=error; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ds" "$qid" "$param" "$run" "$cache" "$((t1 - t0))" "$status" "$rc" "$st" "$out" >> "$M"
  echo "  $qid run=$run cache=$cache wall_ms=$((t1 - t0)) status=$status"
}
restart_wait() {
  local f=$1; local t0; t0=$(ms)
  { echo "restart_begin $(date --iso-8601=ns)"; docker compose restart graph-db 2>&1; echo "restart_cmd_done $(date --iso-8601=ns) after_ms=$(( $(ms) - t0 ))"; } > "$f"
  local i
  for i in $(seq 1 600); do
    if echo 'RETURN 1;' | cs plain >/dev/null 2>&1; then break; fi
    sleep 0.5
  done
  echo "neo4j_ready $(date --iso-8601=ns) total_wait_ms_since_restart_begin=$(( $(ms) - t0 )) probes=$i" >> "$f"
  echo "  restart+ready: $(tail -1 "$f")"
}

for qid in p1_reach_per_source p2_exists_all p5_prebuilt; do
  echo "== $ds $qid"
  { echo "datapipe before $qid: $(datapipe)"; } >> "$Q/datapipe_checks.log"
  stats "before" "$qid"
  { printf 'EXPLAIN '; cat "queries/$qid.cypher"; } | run_one "$qid" explain - "$Q/$qid.explain.txt" ""
  { printf 'PROFILE '; cat "queries/$qid.cypher"; } | run_one "$qid" profile - "$Q/$qid.profile.txt" ""
  restart_wait "$Q/$qid.restart.txt"
  run_one "$qid" 1 cold "$Q/$qid.cold.txt" "" < "queries/$qid.cypher"
  for k in 1 2 3 4 5; do run_one "$qid" "$k" warm "$Q/$qid.warm$k.txt" "" < "queries/$qid.cypher"; done
  stats "after" "$qid"
done

qid=p3_reverse_traversal
printf '%s\t%s\t\t-\t-\t\tskipped\t\t%s\tqueries/p3_reverse_traversal.cypher\n' "$ds" "$qid" "$(date --iso-8601=seconds)" >> "$M"
echo "== $ds $qid skipped"

qid=p4_single_source
echo "== $ds $qid"
echo "datapipe before $qid: $(datapipe)" >> "$Q/datapipe_checks.log"
cs plain < queries/p4_users_list.cypher > "$Q/p4_users_list.txt" 2>&1
mapfile -t USERS < <(tail -n +2 "$Q/p4_users_list.txt" | tr -d '\r' | sed 's/^"//; s/"$//')
echo "  users: ${#USERS[@]}"
body=$(grep -v '^//' "queries/$qid.cypher")
{ printf ':param id => "%s";\nEXPLAIN %s\n' "${USERS[0]}" "$body"; } | run_one "$qid" explain - "$Q/$qid.explain.txt" "${USERS[0]}"
{ for u in "${USERS[@]:0:5}"; do printf ':param id => "%s";\nPROFILE %s\n' "$u" "$body"; done; } \
  | run_one "$qid" profile - "$Q/$qid.profile.txt" "first5"
stats "before" "$qid"
restart_wait "$Q/$qid.restart.txt"
{ for pass in 1 2 3 4; do for u in "${USERS[@]}"; do printf ':param id => "%s";\n%s\n' "$u" "$body"; done; done; } > "$Q/$qid.session.cypher"
run_one "$qid" session "pass1=cold,pass2-4=warm" "$Q/$qid.session.txt" "all_users" $(( TIMEOUT * 4 )) < "$Q/$qid.session.cypher"
stats "after" "$qid"
echo "datapipe after all: $(datapipe)" >> "$Q/datapipe_checks.log"
