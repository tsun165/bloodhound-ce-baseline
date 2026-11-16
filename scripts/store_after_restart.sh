#!/usr/bin/env bash
# Store size after a forced checkpoint: Neo4j 4.4 Community has no db.checkpoint(); a clean
# `docker compose restart graph-db` checkpoints on shutdown. Then du inside the container.
# Usage: scripts/store_after_restart.sh <ds>   -> logs/stats/<ds>/store_size_after_restart.txt
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"; ds=$1
set -a; . ./.env; set +a
out=logs/stats/$ds/store_size_after_restart.txt
{
  echo "# $(date --iso-8601=seconds) restart graph-db (checkpoint on clean shutdown), wait until Neo4j answers, then du"
  docker compose restart graph-db 2>&1
  for i in $(seq 1 120); do echo 'RETURN 1;' | docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain >/dev/null 2>&1 && break; sleep 1; done
  echo "MATCH (n) RETURN count(n) AS nodes; MATCH ()-[r]->() RETURN count(r) AS rels;" | docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain
  docker compose exec -T graph-db sh -c 'echo "## du -sb (apparent bytes)"; du -sb /data/databases/neo4j /data/transactions/neo4j; echo "## du -sk (allocated KiB)"; du -sk /data/databases/neo4j /data/transactions/neo4j; echo "## files"; ls -la /data/databases/neo4j /data/databases/neo4j/schema/index/* /data/transactions/neo4j'
} > "$out" 2>&1
grep -A2 "du -sb" "$out"
