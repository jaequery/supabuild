#!/usr/bin/env bash
# supabuild walkthrough capture — default fallback flow.
#
# Boots the project's dev server, drives a generic playwright-cli
# walkthrough (or a per-build steps file if present), records a
# webm video + step screenshots, then tears the server down.
#
# Required env:
#   WT_PATH    — supabuild worktree path (artifacts go under
#                $WT_PATH/.supabuild/evidence/)
#
# Optional env:
#   PORT       — dev-server port (default per detection table)
#   URL        — full base URL (overrides $PORT-derived default)
#   STEPS_FILE — path to a per-build playwright-cli script. If
#                present, sourced after `video-start`. Otherwise the
#                generic scroll-and-screenshot tour runs.
#
# Conventions:
#   - first-match-wins detection table for the boot command
#   - cap dev-server boot wait at 30s
#   - SERVER_PID captured so we can kill on exit / trap
#   - exit 0 on success; non-zero with reason on failure
#
# Output artifacts:
#   $EVID/00-walkthrough.webm   (or .mp4)   — primary, hard-gates APPROVED
#   $EVID/0[1-3]-step.png                   — step stills (best-effort)

set -u  # fail on unset; do NOT set -e (we want explicit exit codes)

: "${WT_PATH:?WT_PATH must be set to the supabuild worktree path}"
EVID="$WT_PATH/.supabuild/evidence"
mkdir -p "$EVID"

cd "$WT_PATH" || { echo "capture: cd $WT_PATH failed"; exit 2; }

# --- Pre-flight: playwright-cli on PATH -----------------------------------
if ! command -v playwright-cli >/dev/null 2>&1; then
  echo "capture: installing @playwright/cli globally"
  npm i -g @playwright/cli >/dev/null 2>&1 || {
    echo "capture: playwright-cli install failed"
    exit 3
  }
fi

# --- Detect boot command (first match wins) -------------------------------
PORT="${PORT:-3000}"
BOOT=""
if   [ -f pnpm-lock.yaml ]; then
  BOOT="pnpm install --frozen-lockfile && (pnpm db:migrate 2>/dev/null; pnpm db:seed 2>/dev/null; pnpm dev)"
elif [ -f bun.lockb ]; then
  BOOT="bun install && bun run dev"
elif [ -f package.json ]; then
  BOOT="npm install && npm run dev"
elif [ -f composer.json ] && [ -f artisan ]; then
  BOOT="composer install && (php artisan migrate --seed 2>/dev/null; php artisan serve --port=$PORT)"
elif [ -f composer.json ]; then
  BOOT="composer install && php -S localhost:$PORT -t public"
elif [ -f manage.py ]; then
  BOOT="pip install -r requirements.txt 2>/dev/null; python manage.py migrate 2>/dev/null; python manage.py runserver $PORT"
elif [ -f Gemfile ] && [ -f bin/dev ]; then
  BOOT="bundle install && bin/dev"
elif [ -f Gemfile ]; then
  BOOT="bundle install && (bundle exec rails db:migrate 2>/dev/null; bundle exec rails server -p $PORT)"
elif [ -f go.mod ]; then
  BOOT="go run ./..."
elif [ -f Cargo.toml ]; then
  BOOT="cargo run"
else
  echo "capture: no boot command detected (no pnpm/bun/npm/composer/manage.py/Gemfile/go.mod/Cargo.toml)"
  exit 4
fi

URL="${URL:-http://localhost:$PORT}"
echo "capture: booting -> $BOOT (waiting for $URL)"

# --- Boot in background, poll until ready ---------------------------------
( eval "$BOOT" ) >"$EVID/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT

ready=0
for _ in $(seq 1 30); do
  if curl -sSf -o /dev/null --max-time 2 "$URL"; then
    ready=1; break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "capture: dev server did not respond within 30s — see $EVID/server.log"
  exit 5
fi
echo "capture: dev server ready"

# --- Drive playwright-cli session -----------------------------------------
SESS="sb-$$"
playwright-cli -s="$SESS" open "$URL"            || { echo "capture: open failed"; exit 6; }
playwright-cli -s="$SESS" resize 1440 900        || true
playwright-cli -s="$SESS" video-start "$EVID/00-walkthrough.webm" \
  || { echo "capture: video-start failed"; exit 7; }

if [ -n "${STEPS_FILE:-}" ] && [ -f "$STEPS_FILE" ]; then
  echo "capture: sourcing per-build steps from $STEPS_FILE"
  # shellcheck source=/dev/null
  SESS="$SESS" EVID="$EVID" . "$STEPS_FILE" || \
    echo "capture: per-build steps returned non-zero (continuing to teardown)"
else
  # Generic scroll-and-screenshot tour — proves the page renders.
  playwright-cli -s="$SESS" video-chapter "Top of page"
  playwright-cli -s="$SESS" screenshot "$EVID/01-step.png"
  playwright-cli -s="$SESS" eval "() => window.scrollTo({ top: 800, behavior: 'smooth' })"
  playwright-cli -s="$SESS" video-chapter "Mid-page"
  playwright-cli -s="$SESS" screenshot "$EVID/02-step.png"
  playwright-cli -s="$SESS" eval "() => window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' })"
  playwright-cli -s="$SESS" video-chapter "Bottom"
  playwright-cli -s="$SESS" screenshot "$EVID/03-step.png"
fi

playwright-cli -s="$SESS" video-stop  || true
playwright-cli -s="$SESS" close        || true

# Teardown happens via the EXIT trap.

# --- Verify the artifact ---------------------------------------------------
if [ ! -s "$EVID/00-walkthrough.webm" ] && [ ! -s "$EVID/00-walkthrough.mp4" ]; then
  echo "capture: walkthrough video missing or empty"
  exit 8
fi

bytes=$(wc -c < "$EVID/00-walkthrough.webm" 2>/dev/null \
        || wc -c < "$EVID/00-walkthrough.mp4" 2>/dev/null)
if [ "${bytes:-0}" -lt 50000 ]; then
  echo "capture: walkthrough video <50KB ($bytes bytes) — undersize"
  exit 9
fi

echo "capture: success — $EVID/00-walkthrough.* ($bytes bytes)"
exit 0
