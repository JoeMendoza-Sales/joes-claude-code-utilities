# Context Window Monitor for Claude Code

Shows a live, color-coded context usage meter in your Claude Code status bar and alerts you at key thresholds so you never lose work to context overflow.

## What You Get

**Status bar** — always-visible meter: `Context: 42.3% (85K/200K tokens) [OK]`

**Color gradient** — changes as usage climbs:

| Range   | Color         | Label            | What to do                    |
|---------|---------------|------------------|-------------------------------|
| 0-25%   | Blue          | (none)           | Normal                        |
| 25-50%  | Blue → Green  | OK               | Awareness                     |
| 50-75%  | Yellow-Orange | MODERATE         | Be concise, use subagents     |
| 75-90%  | Orange-Red    | HIGH — /compact  | Run `/compact` to reclaim space |
| 90%+    | Deep Red      | WRAP NOW         | Stop — compact or start fresh |

**Threshold alerts** — one-time reminders injected at 25/50/75/90% so you can save important work before context gets compressed.

**Pre-compact reminder** — before `/compact` runs, reminds you to save anything important.

## Prerequisites

- `jq` and `bc` (both come with most Macs, or `brew install jq bc`)

## Install

### 1. Copy files into place

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
mkdir -p ~/.claude/scripts
cp scripts/context-monitor.sh ~/.claude/scripts/context-monitor.sh
cp scripts/pre-compact-memory.sh ~/.claude/scripts/pre-compact-memory.sh
chmod +x ~/.claude/statusline-command.sh ~/.claude/scripts/*.sh
```

### 2. Update settings.json

Open (or create) `~/.claude/settings.json` and add/merge these keys:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/context-monitor.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/pre-compact-memory.sh"
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

> **If you already have a `settings.json`**: merge the `hooks` and `statusLine` keys into your existing file — don't overwrite the whole thing.

### 3. Restart Claude Code

Start a new session. You should see the context meter in the status bar right away.

## Files

```
context-monitor-kit/
├── README.md                        ← you are here
├── statusline-command.sh            ← status bar script (→ ~/.claude/)
└── scripts/
    ├── context-monitor.sh           ← threshold alerts (→ ~/.claude/scripts/)
    └── pre-compact-memory.sh        ← pre-compact reminder (→ ~/.claude/scripts/)
```
