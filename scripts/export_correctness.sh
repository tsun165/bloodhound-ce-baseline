#!/usr/bin/env bash
# Export correctness results for one dataset into results/<ds>/ (each query = one run.sh entry).
# Usage: scripts/export_correctness.sh <ds>
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
ds=$1; mkdir -p results/$ds
for q in node_counts edge_counts nodes edges_22 tier0 reach_22 reach_all; do
  bash scripts/run.sh "export-$ds-$q" -- "set -a; . ./.env; set +a; timeout 300 docker compose exec -T -e NEO4J_PASSWORD=\"\$NEO4J_SECRET\" graph-db cypher-shell -u neo4j --format plain < queries/q_$q.cypher > results/$ds/$q.csv; rc=\$?; echo \"rows(excl header)=\$((\$(wc -l < results/$ds/$q.csv)-1)) rc=\$rc\"; exit \$rc"
done
# Prebuilt "Shortest paths to Tier Zero / High Value targets": sent through the CE API endpoint the UI
# cypher search uses (POST /api/v2/graphs/cypher), query text = queries/q_prebuilt_tier0.cypher (without trailing ';').
bash scripts/run.sh "export-$ds-prebuilt_tier0" -- "bash scripts/bh_api.sh login >/dev/null && perl -MJSON::PP -0e 'local \$/; my \$q=<STDIN>; \$q =~ s/;\s*\z//; print JSON::PP->new->canonical->encode({query=>\$q, include_properties=>JSON::PP::true})' < queries/q_prebuilt_tier0.cypher | bash scripts/bh_api.sh POST /api/v2/graphs/cypher -H 'Content-Type: application/json' --data-binary @- -o results/$ds/prebuilt_tier0.json -w 'http=%{http_code} bytes=%{size_download}\n'"
