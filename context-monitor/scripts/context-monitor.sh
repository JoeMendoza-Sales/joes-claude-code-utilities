#!/bin/bash
# Context window monitor — fires on Stop hook
# Checks usage % and injects reminders at 25/50/75/90% thresholds
# Each threshold fires only once per session (tracked via state file)

INPUT=$(cat)
PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1 2>/dev/null)

if [ -z "$PCT" ] || [ "$PCT" = "null" ] || [ "$PCT" = "0" ]; then exit 0; fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
STATE_FILE="/tmp/claude-context-monitor-${SESSION_ID}"
FIRED=""
if [ -f "$STATE_FILE" ]; then FIRED=$(cat "$STATE_FILE"); fi

fire_threshold() {
  local level=$1 msg=$2
  if ! echo "$FIRED" | grep -q "^${level}$"; then
    echo "$msg"
    echo "$level" >> "$STATE_FILE"
  fi
}

if [ "$PCT" -ge 90 ]; then
  echo "CRITICAL: Context at ${PCT}%. Save findings to memory NOW, then run /compact immediately."
elif [ "$PCT" -ge 75 ]; then
  fire_threshold 75 "WARNING: Context at ${PCT}%. Save key findings to memory. Plan to /compact soon."
elif [ "$PCT" -ge 50 ]; then
  fire_threshold 50 "CONTEXT CHECK (${PCT}%): Halfway through. Save important discoveries to memory."
elif [ "$PCT" -ge 25 ]; then
  fire_threshold 25 "CONTEXT CHECK (${PCT}%): Quarter mark. Save important findings to memory if needed."
fi
