#!/usr/bin/env bash
# ===========================================================================
# Functional smoke test for the Navidrome TOS package.
#
# Usage:  bash test/smoke.sh [http://127.0.0.1:8157]
#
#   SMOKE_USER / SMOKE_PASS   credentials used for the first admin and login
#                             (default: smoke / navidrome-smoke-2026)
#
# It proves what a music server must do after installation, not just that a port
# answers:
#   1. the heartbeat endpoint answers (the container healthcheck path),
#   2. the web UI is served and is not an empty shell,
#   3. the first admin account can be created (initial setup works),
#   4. a wrong password is rejected, so authentication is really enforced,
#   5. the documented login issues a JWT,
#   6. the native API accepts that JWT and answers from the database,
#   7. upstream's insights collector is disabled in this package,
#   8. the Subsonic API (the reason most users install Navidrome) authenticates
#      and answers a real query.
#
# Exit code 0 only when every check passes. Any non-zero exit fails the gate.
# No network access outside the NAS is needed.
# ===========================================================================
set -u

BASE="${1:-http://127.0.0.1:8157}"
BASE="${BASE%/}"
USER_NAME="${SMOKE_USER:-smoke}"
PASS_WORD="${SMOKE_PASS:-navidrome-smoke-2026}"
BODY="$(mktemp)"
FAIL=0
TOKEN=""
CODE=""

say() { printf '  [smoke] %s\n' "$*"; }
ok()  { printf '  [ OK ] %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; FAIL=1; }

cleanup() { rm -f "$BODY"; }
trap cleanup EXIT

# req_get <path> [curl args...]   -> sets $CODE, body in $BODY
req_get() {
    local path="$1"
    shift
    CODE="$(curl -sS -m 20 -o "$BODY" -w '%{http_code}' "$@" "$BASE$path" 2>/dev/null || printf '000')"
}

# req_post <path> <json>          -> sets $CODE, body in $BODY
req_post() {
    CODE="$(curl -sS -m 20 -o "$BODY" -w '%{http_code}' -X POST \
        -H 'Content-Type: application/json' --data-binary "$2" "$BASE$1" 2>/dev/null || printf '000')"
}

jget() {  # jget <python-expression over d>
    python3 - "$BODY" "$1" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(1)
v = eval(sys.argv[2],
         {"__builtins__": {"isinstance": isinstance, "len": len, "str": str,
                           "list": list, "dict": dict, "bool": bool}},
         {"d": d})
print("" if v is None else v)
PY
}

# --- 1. heartbeat (the healthcheck path) -------------------------------------
req_get /ping
if [ "$CODE" = "200" ]; then
    ok "heartbeat /ping answers (HTTP 200)"
else
    bad "heartbeat /ping returned HTTP ${CODE}"
fi

# --- 2. web UI ---------------------------------------------------------------
req_get /app
SIZE="$(wc -c < "$BODY" 2>/dev/null | tr -d ' ')"
if [ "$CODE" = "200" ] && [ "${SIZE:-0}" -gt 500 ] && grep -qi 'navidrome' "$BODY"; then
    ok "web UI served at /app (HTTP 200, ${SIZE} bytes)"
else
    bad "web UI /app missing or empty (HTTP ${CODE}, ${SIZE:-0} bytes)"
fi

# --- 3. first admin (initial setup) ------------------------------------------
req_post /auth/createAdmin "{\"username\":\"$USER_NAME\",\"password\":\"$PASS_WORD\"}"
if [ "$CODE" = "200" ]; then
    ok "initial admin created (username ${USER_NAME})"
elif [ "$CODE" = "403" ]; then
    say "instance already initialised, reusing the existing admin"
else
    bad "POST /auth/createAdmin returned HTTP ${CODE}: $(head -c 200 "$BODY")"
fi

# --- 4. authentication is enforced -------------------------------------------
req_post /auth/login "{\"username\":\"$USER_NAME\",\"password\":\"definitely-wrong\"}"
if [ "$CODE" = "401" ]; then
    ok "wrong password rejected (HTTP 401, auth is enforced)"
else
    bad "wrong password returned HTTP ${CODE} instead of 401"
fi

# --- 5. documented login -----------------------------------------------------
req_post /auth/login "{\"username\":\"$USER_NAME\",\"password\":\"$PASS_WORD\"}"
TOKEN="$(jget 'd.get("token")' || true)"
IS_ADMIN="$(jget 'd.get("isAdmin")' || true)"
if [ "$CODE" = "200" ] && [ -n "$TOKEN" ]; then
    ok "login issued a JWT (isAdmin=${IS_ADMIN})"
else
    bad "login failed (HTTP ${CODE}): $(head -c 200 "$BODY")"
    echo "SMOKE FAILED"
    exit 1
fi

AUTH=(-H "x-nd-authorization: Bearer $TOKEN")

# --- 6. native API answers from the database ---------------------------------
req_get /api/keepalive/ "${AUTH[@]}"
if [ "$CODE" = "200" ] && grep -q '"ok"' "$BODY"; then
    ok "native API accepted the JWT (/api/keepalive/)"
else
    bad "API /api/keepalive/ returned HTTP ${CODE}: $(head -c 200 "$BODY")"
fi

req_get '/api/album?_start=0&_end=1' "${AUTH[@]}"
if [ "$CODE" = "200" ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d,list) else 1)' "$BODY" 2>/dev/null; then
    ok "library query works (/api/album, database readable)"
else
    bad "library query /api/album returned HTTP ${CODE}: $(head -c 200 "$BODY")"
fi

# --- 7. insights telemetry is disabled in this package ------------------------
req_get /api/insights/ "${AUTH[@]}"
if [ "$CODE" = "200" ] && grep -q '"lastRun":"disabled"' "$BODY"; then
    ok "insights telemetry disabled (/api/insights/ reports disabled)"
else
    bad "insights collector is not disabled (HTTP ${CODE}: $(head -c 200 "$BODY"))"
fi

# --- 8. Subsonic API (what most clients use) ---------------------------------
req_get "/rest/ping?u=${USER_NAME}&p=${PASS_WORD}&v=1.16.1&c=tos-smoke&f=json"
if [ "$CODE" = "200" ] && grep -q '"status":"ok"' "$BODY"; then
    ok "Subsonic API authenticates (/rest/ping status ok)"
else
    bad "Subsonic /rest/ping returned HTTP ${CODE}: $(head -c 200 "$BODY")"
fi

req_get "/rest/getMusicFolders?u=${USER_NAME}&p=${PASS_WORD}&v=1.16.1&c=tos-smoke&f=json"
if [ "$CODE" = "200" ] && grep -q '"subsonic-response"' "$BODY"; then
    ok "Subsonic API answers a real query (/rest/getMusicFolders)"
else
    bad "Subsonic /rest/getMusicFolders returned HTTP ${CODE}: $(head -c 200 "$BODY")"
fi

if [ "$FAIL" = 0 ]; then
    echo "SMOKE OK"
    exit 0
fi
echo "SMOKE FAILED"
exit 1
