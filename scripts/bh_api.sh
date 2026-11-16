#!/usr/bin/env bash
# Minimal BloodHound CE API helper (session-token auth).
# Usage: scripts/bh_api.sh login
#        scripts/bh_api.sh <METHOD> <path> [curl args...]   e.g. scripts/bh_api.sh GET /api/v2/datapipe/status
# Token is cached in .bh_token (gitignored). Credentials come from .env.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
set -a; . ./.env; set +a
BASE=${BH_BASE:-http://127.0.0.1:8080}
if [ "$1" = login ]; then
  body=$(printf '{"login_method":"secret","username":"%s","secret":"%s"}' "$BH_ADMIN_USER" "$BH_ADMIN_PASSWORD")
  resp=$(curl -s -X POST "$BASE/api/v2/login" -H 'Content-Type: application/json' --data-binary @- <<<"$body")
  tok=$(printf '%s' "$resp" | sed -n 's/.*"session_token":"\([^"]*\)".*/\1/p')
  if [ -z "$tok" ]; then echo "login failed: $resp" | perl scripts/redact.pl; exit 1; fi
  umask 077; printf '%s' "$tok" > .bh_token
  echo "login ok: $(printf '%s' "$resp" | perl scripts/redact.pl)"
  exit 0
fi
m=$1; p=$2; shift 2
curl -s -X "$m" "$BASE$p" -H "Authorization: Bearer $(cat .bh_token)" "$@"
