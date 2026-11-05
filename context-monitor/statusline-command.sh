#!/usr/bin/env bash
# Statusline: context usage with color gradient
# Portable — no jq or bc required

input=$(cat)

# Parse JSON values with grep/sed (handles both quoted and unquoted numbers)
extract_num() {
  local key=$1
  local val
  val=$(echo "$input" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[0-9]*" | head -1 | grep -o '[0-9]*$')
  echo "${val:-0}"
}

input_tokens=$(extract_num "input_tokens")
cache_creation=$(extract_num "cache_creation_input_tokens")
cache_read=$(extract_num "cache_read_input_tokens")
used_tokens=$(( input_tokens + cache_creation + cache_read ))

# Window the meter measures against. Default 200K; override with CLAUDE_CTX_SIZE (e.g. 1000000).
ctx_size="${CLAUDE_CTX_SIZE:-200000}"

# Integer percentage (shell arithmetic, no bc)
if [ "$used_tokens" -gt 0 ] 2>/dev/null; then
  used_pct_x10=$(( used_tokens * 1000 / ctx_size ))
  used_pct_int=$(( used_pct_x10 / 10 ))
  used_pct_frac=$(( used_pct_x10 % 10 ))
  used_pct="${used_pct_int}.${used_pct_frac}"
else
  echo "Context: --"
  exit 0
fi

# Hand the number to the alert hook (scripts/context-monitor.sh). Hooks aren't told how full the
# context is, but the status line is, so it leaves the percentage in a small per-session file.
session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
if [ -n "$session_id" ]; then
  echo "$used_pct_int" > "${TEMP:-${TMP:-/tmp}}/claude-ctx-${session_id}" 2>/dev/null
fi

# ANSI
RESET='\033[0m'

# Gradient color by percentage
gradient_color() {
  local pct=$1
  if [ "$pct" -ge 90 ]; then
    echo '\033[38;5;196m'
  elif [ "$pct" -ge 85 ]; then
    echo '\033[38;5;196m'
  elif [ "$pct" -ge 80 ]; then
    echo '\033[38;5;202m'
  elif [ "$pct" -ge 75 ]; then
    echo '\033[38;5;208m'
  elif [ "$pct" -ge 50 ]; then
    local step=$(( (pct - 50) * 100 / 25 ))
    if [ "$step" -ge 80 ]; then echo '\033[38;5;208m'
    elif [ "$step" -ge 60 ]; then echo '\033[38;5;214m'
    elif [ "$step" -ge 40 ]; then echo '\033[38;5;220m'
    elif [ "$step" -ge 20 ]; then echo '\033[38;5;226m'
    else echo '\033[38;5;154m'; fi
  elif [ "$pct" -ge 25 ]; then
    local step=$(( (pct - 25) * 100 / 25 ))
    if [ "$step" -ge 80 ]; then echo '\033[38;5;82m'
    elif [ "$step" -ge 60 ]; then echo '\033[38;5;48m'
    elif [ "$step" -ge 40 ]; then echo '\033[38;5;43m'
    elif [ "$step" -ge 20 ]; then echo '\033[38;5;38m'
    else echo '\033[38;5;33m'; fi
  else
    local step=$(( pct * 100 / 25 ))
    if [ "$step" -ge 75 ]; then echo '\033[38;5;33m'
    elif [ "$step" -ge 50 ]; then echo '\033[38;5;39m'
    elif [ "$step" -ge 25 ]; then echo '\033[38;5;75m'
    else echo '\033[38;5;69m'; fi
  fi
}

# Format token counts in compact K/M notation (pure shell arithmetic)
format_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    local whole=$(( n / 1000000 ))
    local frac=$(( (n % 1000000) / 100000 ))
    printf "%d.%dM" "$whole" "$frac"
  elif [ "$n" -ge 1000 ]; then
    local whole=$(( n / 1000 ))
    printf "%dK" "$whole"
  else
    echo "$n"
  fi
}

ctx_size_fmt=$(format_tokens "$ctx_size")
used_tokens_fmt=$(format_tokens "$used_tokens")

color=$(gradient_color "$used_pct_int")
if [ "$used_pct_int" -ge 90 ]; then
  label="WRAP NOW"
elif [ "$used_pct_int" -ge 75 ]; then
  label="HIGH — /compact"
elif [ "$used_pct_int" -ge 50 ]; then
  label="MODERATE"
elif [ "$used_pct_int" -ge 25 ]; then
  label="OK"
else
  label=""
fi

if [ -n "$label" ]; then
  printf "${color}Context: %s%% (%s/%s tokens) [%s]${RESET}" "$used_pct" "$used_tokens_fmt" "$ctx_size_fmt" "$label"
else
  printf "${color}Context: %s%% (%s/%s tokens)${RESET}" "$used_pct" "$used_tokens_fmt" "$ctx_size_fmt"
fi
