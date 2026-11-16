#!/usr/bin/env bash
# Upload zips of one dataset as ONE ingest job via the CE API, then poll every 5 s until
# ingest + analysis are done. Writes logs/ingest/<ds>/{timeline.log,datapipe_poll.log}.
# Usage: scripts/ingest.sh <ds> <zip>...
# Done = job status terminal (2 complete / 8 partially complete / 5 failed / 3 canceled / 4 timed out)
#        AND datapipe status "idle" AND last_complete_analysis_at > time the job was ended.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
ds=$1; shift
D=logs/ingest/$ds; mkdir -p "$D"
T=$D/timeline.log; P=$D/datapipe_poll.log
now() { echo "$(date --iso-8601=ns) $(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"; }   # local, UTC
mark() { echo "$(now) $*" | tee -a "$T"; }
api() { bash scripts/bh_api.sh "$@"; }

bash scripts/bh_api.sh login >/dev/null || exit 1
mark "pre datapipe=$(api GET /api/v2/datapipe/status)"
resp=$(api POST /api/v2/file-upload/start)
job=$(printf '%s' "$resp" | sed -n 's/.*"id":\([0-9]*\).*/\1/p' | head -1)
mark "job_start id=$job resp=$resp"
[ -n "$job" ] || exit 1
for z in "$@"; do
  n=$(basename "$z")
  mark "upload_begin file=$n bytes=$(stat -c %s "$z")"
  r=$(api POST "/api/v2/file-upload/$job" -H 'Content-Type: application/zip' -H "X-File-Upload-Name: $n" --data-binary @"$z" -w ' http=%{http_code}')
  mark "upload_end file=$n resp=$r"
done
mark "job_end_call resp=$(api POST /api/v2/file-upload/$job/end -w ' http=%{http_code}')"
end_utc=$(date -u +%Y-%m-%dT%H:%M:%S)

for i in $(seq 1 720); do   # max 60 min
  dp=$(api GET /api/v2/datapipe/status)
  jb=$(api GET "/api/v2/file-upload?id=eq:$job")
  echo "$(now) poll=$i datapipe=$dp job=$jb" >> "$P"
  st=$(printf '%s' "$dp" | sed -n 's/.*"status":"\([a-z]*\)".*/\1/p')
  js=$(printf '%s' "$jb" | sed -n 's/.*"status":\(-\{0,1\}[0-9]*\).*/\1/p' | head -1)
  lca=$(printf '%s' "$dp" | sed -n 's/.*"last_complete_analysis_at":"\([^"]*\)".*/\1/p')
  case "$js" in 2|3|4|5|8)
    if [ "$st" = idle ] && [[ "$lca" > "$end_utc" ]]; then
      mark "done poll=$i job_status=$js datapipe=$dp job=$jb"; exit 0
    fi;;
  esac
  sleep 5
done
mark "gave_up after 60 min"; exit 1
