#!/usr/bin/env bash
input=$(cat)
used_tokens=$(echo "$input" | jq -r '
  (.context_window.current_usage.input_tokens // 0) +
  (.context_window.current_usage.cache_creation_input_tokens // 0) +
  (.context_window.current_usage.cache_read_input_tokens // 0)
')
ctx_size=200000
used_pct_raw=$(echo "scale=2; $used_tokens * 100 / $ctx_size" | bc 2>/dev/null || echo 0)

RESET='\033[0m'

gradient_color() {
  local pct=$1
  if [ "$pct" -ge 90 ]; then echo '\033[38;5;196m'
  elif [ "$pct" -ge 85 ]; then echo '\033[38;5;196m'
  elif [ "$pct" -ge 80 ]; then echo '\033[38;5;202m'
  elif [ "$pct" -ge 75 ]; then echo '\033[38;5;208m'
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

format_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then printf "%.1fM" "$(echo "scale=1; $n / 1000000" | bc)"
  elif [ "$n" -ge 1000 ]; then printf "%.0fK" "$(echo "scale=0; $n / 1000" | bc)"
  else echo "$n"; fi
}

ctx_size_fmt=$(format_tokens "$ctx_size")

if [ -n "$used_pct_raw" ] && [ "$used_pct_raw" != "null" ] && [ "$(echo "$used_pct_raw > 0" | bc)" -eq 1 ] 2>/dev/null; then
  used_pct=$(printf "%.1f" "$used_pct_raw")
  used_pct_int=$(printf "%.0f" "$used_pct_raw")
  used_tokens_fmt=$(format_tokens "$used_tokens")
  color=$(gradient_color "$used_pct_int")
  if [ "$used_pct_int" -ge 90 ]; then label="WRAP NOW"
  elif [ "$used_pct_int" -ge 75 ]; then label="HIGH — /compact"
  elif [ "$used_pct_int" -ge 50 ]; then label="MODERATE"
  elif [ "$used_pct_int" -ge 25 ]; then label="OK"
  else label=""; fi
  if [ -n "$label" ]; then
    printf "${color}Context: %s%% (%s/%s tokens) [%s]${RESET}" "$used_pct" "$used_tokens_fmt" "$ctx_size_fmt" "$label"
  else
    printf "${color}Context: %s%% (%s/%s tokens)${RESET}" "$used_pct" "$used_tokens_fmt" "$ctx_size_fmt"
  fi
else
  echo "Context: --"
fi
