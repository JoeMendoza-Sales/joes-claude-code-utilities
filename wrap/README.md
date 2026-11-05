# /wrap

An end-of-session command that closes out a Claude Code session and saves your place, for whichever project you're in. It reads a small `.wrap.json` in each project folder, so one command works everywhere and nothing is hardcoded.

Type `/wrap` when you're done. Claude:

1. **Works out which project this is** (walks up from the current folder looking for `.wrap.json`, then falls back to the conversation, then asks)
2. **Writes a 5-10 bullet summary**: what changed, what was decided and why, what's still open
3. **Strips sensitive detail** if the project's privacy filter is on (client names, people, dollar amounts)
4. **Logs it** wherever that project wants: a Notion database, a JSON Lines "brain" log of learnings, a changelog
5. **Shows you the git changes** and commits and pushes only if you say so
6. **Prints a checklist** and ends with the open items, so they're the last thing on screen

Each step can be turned on or off per project.

## Install

```bash
mkdir -p ~/.claude/commands
cp commands/wrap.md ~/.claude/commands/wrap.md
```

Then, in each project folder:

```bash
cp <this repo>/wrap/templates/wrap.json.template .wrap.json
```

Edit `.wrap.json`: set `project` and `display_name`, and turn on the steps you want. Or just run `/wrap` in a project without one and Claude will offer to create it.

## Tips

- **The `learnings` field is the valuable part.** Anything that should change how future sessions behave (a preference, a mistake, a pattern that worked) goes there, and corrections also become memories.
- **Keep `ask_before_push: true`.** You want to see the diff before anything leaves your machine.
- **Notion is optional.** Leave `notion.enabled: false` and the rest still works. If Notion is down, the summary is saved locally to sync later.
