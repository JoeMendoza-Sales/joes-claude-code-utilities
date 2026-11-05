---
description: End-of-session wrap-up — summarize the work, update Notion, log to the project brain, update the changelog, and sync the repo
---

You are closing out this Claude Code session. This is a **universal wrap** — it works across
every project, because it reads its instructions from a per-project config file rather than
having anything hardcoded.

---

## Step 0: Figure out which project this is

Find the active project by looking for a `.wrap.json` config file:

1. **Walk up from the current folder** looking for `.wrap.json`. It lives at the root of each
   project, e.g.:
   - `~/Documents/projects/client-work/.wrap.json`
   - `~/Documents/projects/social-content/.wrap.json`
2. **If that finds nothing, use the conversation.** If the session was obviously about one
   project, use that project's config.
3. **If it's ambiguous**, ask: "Which project should I wrap? I found configs for: [list]"
4. **If there's no `.wrap.json` anywhere**, say: "No `.wrap.json` found for this project. Want
   me to create one?" and offer to generate it from the template.

Once identified, read the `.wrap.json` and let it drive every step below.

Print: `Wrapping session for **{display_name}**`

---

## Step 1: Summarize the session

Review the whole conversation and pull out:

- **What was made, changed, or decided** — drafts, documents, posts, spreadsheets, configs,
  research, process changes
- **Decisions** — approaches agreed on, things ruled out, and why
- **Open items** — unfinished work, things waiting on someone else, blockers, things I said
  I'd come back to

Write it as **5–10 bullet points, maximum.** This is a log entry, not a transcript.

### Privacy filter

If `privacy_filter.enabled` is `true` in the config, strip everything listed in
`privacy_filter.strip` before this summary is written anywhere — Notion, git, or the changelog.
That typically means client names, individuals' names, dollar amounts, and anything
confidential. Log **what was built**, not **who it was for**.

If you're unsure whether a detail is sensitive: **ask before writing it.**

---

## Step 2: Update Notion

**Only if `notion.enabled` is `true`.**

Using the Notion tools:

- Search for a page matching `page_title_format`, substituting `{date}` with today's date and
  `{project}` with `display_name`
- If `append_mode` is `true` — find that page (create it if missing) and append a new entry
- If `append_mode` is `false` — create a fresh page every time
- Write into the database at `database_id`
- Fill the properties named in `entry_fields`:
  - `date` → today's date
  - `summary` → the bullets from Step 1
  - `files_changed` → the list of new and modified files
  - `status` → what's working, what needs follow-up

**If `database_id` is `null`:** say "Notion database ID isn't set in `.wrap.json` — skipping.
Add the `database_id` once the Notion database exists." Then move on.

**If Notion errors or is unreachable:** write the summary to `fallback.local_path` as
`session-log-YYYYMMDD.json` and say it will sync next time.

---

## Step 3: Log to the project brain

**Only if `brain.enabled` is `true`.**

Append one line to `{brain.log_path}` (JSON Lines — one JSON object per line, no commas
between them):

```json
{"date": "YYYY-MM-DD", "type": "{brain.entry_type}", "project": "{project}", "summary": "one-line summary", "learnings": ["..."], "tags": ["{brain.tags}"]}
```

The `learnings` array is the valuable part — put anything here that should change how future
sessions behave: preferences discovered, mistakes made, patterns that worked.

If any learning is a **correction I made to you**, also write it as a proper feedback memory in
the memory folder, not just here.

---

## Step 4: Update the changelog

**Only if `changelog.enabled` is `true`.**

Append to the file at `changelog.path` (relative to the repo root). For `keep-a-changelog`
format:

```markdown
## [Unreleased]

### YYYY-MM-DD
- Summary bullet
- Summary bullet
```

Create the file with a header if it doesn't exist yet.

---

## Step 5: Sync the repo

**Only if `git.enabled` is `true`.**

Check for uncommitted changes in `git.repo_path`:

```bash
git -C "{git.repo_path}" status --short
```

If there are changes:

- **Show me what changed** before doing anything
- If `ask_before_push` is `true` — ask whether to commit and push, and wait
- If `auto_push` is `true` — commit and push without asking
- Commit using `commit_format`, substituting `{date}` and `{summary}`
- Push to origin only after approval

Never force-push. Never commit anything the privacy filter was supposed to strip.

---

## Step 6: Confirm

Print a final checklist:

```
Session: {display_name}
[x] Notion updated          (or the reason it was skipped)
[x] Brain logged            (or the reason it was skipped)
[x] Changelog updated       (or the reason it was skipped)
[x] Repo synced             (or the reason it was skipped)
[x] Open items flagged
```

Use `[x]` for done, `[!]` for failed with the reason, `[-]` for skipped because it isn't
enabled.

Then list the **open items** one more time in plain text, so they're the last thing on screen
when the session closes.

---

## Config reference

`.wrap.json` lives at the root of each project folder. Copy `templates/wrap.json.template`
to `.wrap.json` and edit it.

| Key | Meaning |
|---|---|
| `project` | Short unique id, lowercase, no spaces |
| `display_name` | Human-readable name used in output |
| `notion.enabled` | Turn the Notion step on or off |
| `notion.database_id` | The Notion database to log into; `null` until it exists |
| `notion.page_title_format` | Supports `{date}` and `{project}` |
| `notion.append_mode` | `true` = append to one page, `false` = new page each session |
| `notion.entry_fields` | Maps this command's fields to your Notion property names |
| `git.enabled` | Turn the git step on or off |
| `git.repo_path` | Path to the repo folder |
| `git.commit_format` | Commit message template; supports `{date}` and `{summary}` |
| `git.auto_push` | Push with no confirmation |
| `git.ask_before_push` | Ask first (recommended: `true`) |
| `brain.enabled` | Turn the brain log on or off |
| `brain.log_path` | Path to the `.jsonl` log file |
| `brain.entry_type` | Label for the entry, e.g. `session-log` |
| `brain.tags` | Array of tags applied to every entry |
| `changelog.enabled` | Turn the changelog step on or off |
| `changelog.path` | Path relative to the repo root |
| `changelog.format` | `keep-a-changelog` |
| `privacy_filter.enabled` | Strip sensitive detail before writing anywhere |
| `privacy_filter.strip` | Array of categories to strip |
| `fallback.local_path` | Where to save the summary if Notion is down |
