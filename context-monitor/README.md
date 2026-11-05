# Context Monitor

A live, color-coded context meter in your Claude Code status bar, plus alerts that Claude itself sees as the conversation fills up, so it saves what matters before anything gets compressed.

No `jq`, no `bc`, plain bash. Tested on Windows (Git Bash) and macOS.

## What you get

**Status bar meter**, always visible: `Context: 42.3% (148K/350K tokens) [OK]`

| Range | Color | Label | What to do |
|---|---|---|---|
| 0-25% | Blue | (none) | Normal |
| 25-50% | Blue to green | OK | Awareness |
| 50-75% | Yellow to orange | MODERATE | Be concise, hand long reading to subagents |
| 75-90% | Orange to red | HIGH: /compact | Compact soon |
| 90%+ | Red | WRAP NOW | Stop, save, compact or start fresh |

**Alerts Claude can see** at 25%, 50% and 75% (once each per session), and at 90% on every message until you compact. Claude is told to save findings to memory before going further.

**A post-compact reminder.** Right after `/compact`, Claude is told the summary is lossy and to re-read its notes before trusting exact numbers or names.

## How it works (and why it's built this way)

Two facts about Claude Code shape this:

1. **Hooks aren't told how full the context is.** The status line is. So `statusline-command.sh` leaves the current percentage in a tiny per-session file in your temp folder every time it redraws.
2. **Most hook output never reaches Claude.** Only a few events (`UserPromptSubmit` and `SessionStart` among them) add plain output to Claude's context. A `Stop` or `PreCompact` hook that just prints text goes to a debug log. So the alert runs on `UserPromptSubmit` and reads the saved percentage, and the reminder runs on `SessionStart` with the `compact` matcher.

The meter measures against **350K** by default, not the full 1M window, and that number comes from data rather than a guess. Across a month of my own sessions, I corrected Claude no more often past 200K than below it, corrections didn't bunch up late in sessions, and Claude almost never forgot what it had been told earlier, up to about 350K. I compact before going further, so nothing beyond that has been tested. Set `CLAUDE_CTX_SIZE` to change it (e.g. `200000` to be cautious, `1000000` for the full window).

## Install

### 1. Copy the files

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
mkdir -p ~/.claude/scripts
cp scripts/context-monitor.sh scripts/post-compact-reminder.sh ~/.claude/scripts/
chmod +x ~/.claude/statusline-command.sh ~/.claude/scripts/*.sh
```

### 2. Merge this into `~/.claude/settings.json`

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  },
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/scripts/context-monitor.sh" }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/scripts/post-compact-reminder.sh" }
        ]
      }
    ]
  }
}
```

If you already have a `settings.json`, merge the `statusLine` and `hooks` keys into it rather than replacing the file. If you already have `SessionStart` or `UserPromptSubmit` hooks, add these entries alongside them.

### 3. Start a new session

The meter shows up as soon as the first response comes back.

## Upgrading from the earlier version

The first version of this kit ran the alerts on a `Stop` hook and had a `PreCompact` reminder. Neither ever reached Claude, for the two reasons above. Remove `Stop` → `context-monitor.sh` and `PreCompact` → `pre-compact-memory.sh` from your settings, then follow the install steps.

## Files

```
context-monitor/
├── README.md
├── statusline-command.sh          → ~/.claude/  (meter; also saves the % for the alert)
└── scripts/
    ├── context-monitor.sh         → ~/.claude/scripts/  (UserPromptSubmit alerts)
    └── post-compact-reminder.sh   → ~/.claude/scripts/  (SessionStart "compact" reminder)
```
