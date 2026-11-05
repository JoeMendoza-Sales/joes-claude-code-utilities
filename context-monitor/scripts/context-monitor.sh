#!/bin/bash
# Context alerts. Runs on the UserPromptSubmit hook, where plain stdout is added to Claude's context.
# Hooks aren't told how full the context is, so this reads the percentage the status line saved
# (statusline-command.sh writes it to $TEMP/claude-ctx-<session_id> every time it redraws).
# 25/50/75 fire once per session; 90 repeats on every prompt until you compact.
# Portable: no jq required.

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
[ -z "$SESSION_ID" ] && exit 0

TMPDIR="${TEMP:-${TMP:-/tmp}}"
PCT_FILE="${TMPDIR}/claude-ctx-${SESSION_ID}"
STATE_FILE="${TMPDIR}/claude-context-monitor-${SESSION_ID}"

[ -f "$PCT_FILE" ] || exit 0
PCT=$(tr -dc '0-9' < "$PCT_FILE")
[ -z "$PCT" ] && exit 0

FIRED=""
[ -f "$STATE_FILE" ] && FIRED=$(cat "$STATE_FILE")

fire_once() {
  local level=$1 msg=$2
  if ! echo "$FIRED" | grep -q "^${level}$"; then
    echo "$msg"
    echo "$level" >> "$STATE_FILE"
  fi
}

if [ "$PCT" -ge 90 ]; then
  echo "CRITICAL: Context at ${PCT}%. Before anything else, save important findings and decisions to memory, then tell the user to run /compact (or /wrap and start fresh). Do not start new work until then."
elif [ "$PCT" -ge 75 ]; then
  fire_once 75 "WARNING: Context at ${PCT}%. Save key findings and decisions to memory now. Avoid large new operations; suggest /compact soon."
elif [ "$PCT" -ge 50 ]; then
  fire_once 50 "CONTEXT CHECK (${PCT}%): Halfway. Save any important discoveries or decisions to memory now."
elif [ "$PCT" -ge 25 ]; then
  fire_once 25 "CONTEXT CHECK (${PCT}%): Quarter mark. If you have findings worth keeping, save them to memory."
fi
exit 0
