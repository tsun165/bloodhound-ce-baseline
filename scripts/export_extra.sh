#!/usr/bin/env bash
# Follow-up questions 2026-11-19: export Q2-Q4 for one dataset into results/<ds>/extra/
# (each query = one run.sh entry). Q4 is run twice (ce_paths_22.csv, ce_paths_22_run2.csv).
# Usage: scripts/export_extra.sh <ds>
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
ds=$1; mkdir -p results/$ds/extra
q() {  # <query file stem> <output csv stem>
  bash scripts/run.sh "extra-$ds-$2" -- "set -a; . ./.env; set +a; timeout 600 docker compose exec -T -e NEO4J_PASSWORD=\"\$NEO4J_SECRET\" graph-db cypher-shell -u neo4j --format plain < queries/extra/$1.cypher > results/$ds/extra/$2.csv; rc=\$?; echo \"rows(excl header)=\$((\$(wc -l < results/$ds/extra/$2.csv)-1)) rc=\$rc\"; exit \$rc"
}
q q2_local_to_computer local_to_computer
q q2_member_of_local_group member_of_local_group
q q3_edges_all edges_all
q q4_ce_paths_22 ce_paths_22
q q4_ce_paths_22 ce_paths_22_run2
