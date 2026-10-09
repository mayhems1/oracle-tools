#!/bin/bash
# Quick first-look diagnostics: runs diag_* scripts in order. Read-only.
# Usage: diag_quick.sh [hours=1] [--log]
#   --log  also save output to $DIAG_LOG_DIR/diag_YYYYMMDD_HHMM.log (default $HOME/diag-logs)

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

DIR=$(cd "$(dirname "$0")" && pwd)
HOURS=1
LOG=0
for a in "$@"; do
  case "$a" in
    --log) LOG=1 ;;
    *) HOURS=$a ;;
  esac
done
if ! [[ "$HOURS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Error: hours must be a number, e.g. 2 or 0.5"
  exit 1
fi

run() {
  echo
  echo "################ $* ################"
  "$DIR/$@"
}

all() {
  echo "diag_quick: $(date '+%d.%m.%Y %H:%M:%S'), period $HOURS h"
  run diag_now_overview.sh
  run diag_now_active.sh
  run diag_now_blocking.sh
  run diag_now_long_running.sh 5
  run diag_ash_load_timeline.sh "$HOURS"
  run diag_ash_top_sql.sh "$HOURS" 10
  run diag_ash_top_users.sh "$HOURS" 10
  run diag_ash_top_sessions.sh "$HOURS" 10
  run diag_ash_top_events.sh "$HOURS"
  run diag_ash_blocking.sh "$HOURS"
}

if [ "$LOG" -eq 1 ]; then
  LOG_DIR=${DIAG_LOG_DIR:-$HOME/diag-logs}
  mkdir -p "$LOG_DIR"
  F="$LOG_DIR/diag_$(date +%Y%m%d_%H%M).log"
  all 2>&1 | tee "$F"
  echo
  echo "Saved: $F"
else
  all
fi
