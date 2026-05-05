#!/usr/bin/env bash
# spawn-tab.sh — open a new terminal tab/window and run a command in a given cwd.
#
# Usage:
#   spawn-tab.sh <cwd> <command...>
#
# Auto-detects the host terminal in this priority order:
#   1. cmux         (env: $CMUX_BUNDLE_ID or $CMUX_PORT set, `cmux` CLI present)
#   2. iTerm2       ($TERM_PROGRAM == iTerm.app  OR  $LC_TERMINAL == iTerm2)
#   3. Terminal.app ($TERM_PROGRAM == Apple_Terminal)
#   4. tmux         ($TMUX set)
#   5. fallback     headless background (`nohup ... &`) with a logfile printed to stdout
#
# Override detection with $SUPABUILD_SPAWN_TARGET=cmux|iterm2|terminal|tmux|background.
#
# Prints one line to stdout describing where the job landed:
#   spawn-tab: target=<name> ref=<spawn-ref-or-pid> log=<path-or-tty>

set -u

if [ "$#" -lt 2 ]; then
  echo "usage: spawn-tab.sh <cwd> <command...>" >&2
  exit 2
fi

CWD="$1"; shift
CMD="$*"

if [ ! -d "$CWD" ]; then
  echo "spawn-tab: cwd does not exist: $CWD" >&2
  exit 2
fi

detect_target() {
  if [ -n "${SUPABUILD_SPAWN_TARGET:-}" ]; then
    echo "$SUPABUILD_SPAWN_TARGET"; return
  fi
  if { [ -n "${CMUX_BUNDLE_ID:-}" ] || [ -n "${CMUX_PORT:-}" ]; } \
     && command -v cmux >/dev/null 2>&1; then
    echo "cmux"; return
  fi
  case "${TERM_PROGRAM:-}" in
    iTerm.app)        echo "iterm2";   return ;;
    Apple_Terminal)   echo "terminal"; return ;;
  esac
  if [ "${LC_TERMINAL:-}" = "iTerm2" ]; then echo "iterm2"; return; fi
  if [ -n "${TMUX:-}" ]; then echo "tmux"; return; fi
  echo "background"
}

TARGET="$(detect_target)"

case "$TARGET" in
  cmux)
    # cmux opens a new workspace tab in the current window. The shell-quoted
    # cd ensures the spawned shell runs the command in $CWD even though
    # --cwd already sets it (defensive — early cmux versions ignored --cwd
    # for some shells).
    OUT=$(cmux new-workspace --cwd "$CWD" --command "cd $(printf %q "$CWD") && $CMD" 2>&1)
    RC=$?
    if [ $RC -ne 0 ]; then
      echo "spawn-tab: cmux new-workspace failed: $OUT" >&2
      exit $RC
    fi
    echo "spawn-tab: target=cmux ref=$(printf '%s' "$OUT" | tr -d '\n') log=<cmux-tab>"
    ;;
  iterm2)
    /usr/bin/osascript <<OSA >/dev/null
tell application "iTerm"
  tell current window
    set newTab to (create tab with default profile)
    tell current session of newTab
      write text "cd $(printf '%s' "$CWD" | sed 's/"/\\"/g') && $(printf '%s' "$CMD" | sed 's/"/\\"/g')"
    end tell
  end tell
end tell
OSA
    echo "spawn-tab: target=iterm2 ref=<new-tab> log=<iterm-tab>"
    ;;
  terminal)
    /usr/bin/osascript <<OSA >/dev/null
tell application "Terminal"
  activate
  tell application "System Events" to keystroke "t" using command down
  delay 0.3
  do script "cd $(printf '%s' "$CWD" | sed 's/"/\\"/g') && $(printf '%s' "$CMD" | sed 's/"/\\"/g')" in front window
end tell
OSA
    echo "spawn-tab: target=terminal ref=<new-tab> log=<terminal-tab>"
    ;;
  tmux)
    tmux new-window -c "$CWD" "$CMD"
    echo "spawn-tab: target=tmux ref=<new-window> log=<tmux-window>"
    ;;
  background)
    LOG_DIR="${TMPDIR:-/tmp}/supabuild-spawn"
    mkdir -p "$LOG_DIR"
    LOG="$LOG_DIR/job-$$-$(date +%s).log"
    ( cd "$CWD" && nohup bash -lc "$CMD" >"$LOG" 2>&1 & echo $! >"$LOG.pid" )
    PID=$(cat "$LOG.pid" 2>/dev/null || echo "?")
    echo "spawn-tab: target=background ref=pid:$PID log=$LOG"
    ;;
  *)
    echo "spawn-tab: unknown target '$TARGET' (set SUPABUILD_SPAWN_TARGET to override)" >&2
    exit 2
    ;;
esac
