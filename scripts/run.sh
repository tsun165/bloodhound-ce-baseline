#!/usr/bin/env bash
# Run one command, save redacted stdout+stderr to logs/raw/NNN-<name>.log and append an entry to logs/RUNLOG.md.
# Usage: scripts/run.sh <name> [--note "text"] -- '<shell command string>'
# The command string is run with `bash -c` from the repo root (pipes / redirects allowed).
# Secrets must be referenced as env vars (e.g. $NEO4J_PASSWORD), never literally.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
name=$1; shift
note=""
if [ "${1:-}" = "--note" ]; then note=$2; shift 2; fi
[ "${1:-}" = "--" ] && shift
cmd="$*"

export REDACT_HOST=${REDACT_HOST:-$(hostname)}
export REDACT_USER=${REDACT_USER:-${USERNAME:-${USER:-}}}
export REDACT_EMAIL=${REDACT_EMAIL:-$(git config user.email 2>/dev/null)}

mkdir -p logs/raw
n=$(cat logs/.seq 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > logs/.seq
num=$(printf '%03d' "$n")
out="logs/raw/$num-$name.log"

start=$(date --iso-8601=seconds); t0=$(date +%s.%N)
bash -c "$cmd" > "$out.tmp" 2>&1
rc=$?
t1=$(date +%s.%N); end=$(date --iso-8601=seconds)
dur=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')

perl scripts/redact.pl < "$out.tmp" > "$out"; rm -f "$out.tmp"
cmd_red=$(printf '%s' "$cmd" | perl scripts/redact.pl)

{
  echo ""
  echo "### $n. $name"
  echo "- start: $start · end: $end · duration_s: $dur · exit: $rc"
  echo "- cmd: \`$cmd_red\`"
  echo "- output: $out"
  [ -n "$note" ] && echo "- ghi chú: $(printf '%s' "$note" | perl scripts/redact.pl)"
} >> logs/RUNLOG.md

echo "[run.sh] #$n $name exit=$rc dur=${dur}s -> $out"
exit $rc
