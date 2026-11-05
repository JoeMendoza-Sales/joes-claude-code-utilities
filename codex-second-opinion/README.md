# Codex second opinion

Have Claude Code get a second model's take, through the Codex CLI signed in with your **ChatGPT plan**. There's no OpenAI API key, so there's no per-call bill; it uses your plan's Codex message allowance.

Claude stays in charge. It writes a brief, runs this script, reads what came back, and decides what to keep.

## Two modes

**`copy`: a second opinion on text.** Codex runs read-only and can't touch your files. It's told never to change a number, date, name or factual claim, only to flag one it thinks is wrong. Its reply lands in `<out>\reply.md`.

Good for: "have GPT critique this email", "get a second read on this plan", or comparing two models' answers to the same question.

**`art`: diagrams and graphics as SVG.** Codex can write files, but only inside the output folder. The script then renders every SVG to PNG with headless Chrome or Edge, hands the renders back to Codex, and asks it to fix anything that came out missing, clipped or crowded. The diagram in [brain-architecture](../brain-architecture/) was made this way.

## Requirements

- Windows with PowerShell 5.1 or 7 (macOS users: ask Claude to port it; the only Windows-specific parts are the browser paths and the sandbox setting)
- [Codex CLI](https://github.com/openai/codex), signed in with your ChatGPT account (`codex login`)
- Chrome or Edge, for `art` renders

## Usage

```powershell
.\codex-pass.ps1 -Mode copy -Brief brief.md -Out .\second-opinion
.\codex-pass.ps1 -Mode art  -Brief diagram-brief.md -Out .\art [-Model gpt-6-sol] [-Effort medium] [-NoReview]
```

Then tell Claude about it once, in your `CLAUDE.md`:

```markdown
## Second opinions
For a second model's view, write a brief to a .md file and run
`powershell -File <path>\codex-pass.ps1 -Mode copy -Brief <brief> -Out <dir>`, then read <dir>\reply.md.
Treat the reply as suggestions: keep what's better, and reject any edit that changes a fact.
```

## Lessons baked in

- **On Windows, Codex's write sandbox quietly falls back to read-only** unless a native sandbox is chosen. The script passes `windows.sandbox="unelevated"` on each call, so it needs no admin and makes no machine-wide changes. Your own Codex config isn't touched.
- **Chrome can't start inside Codex's restricted sandbox**, so rendering happens in this script, outside it. The prompt tells Codex not to try rendering itself.
- **Reasoning effort defaults to none** in `codex exec`. The script passes `medium`; the first no-effort SVG test came back with a broken mask that hid half the drawing.
- **The render-and-fix pass is worth it.** Looking at its own output catches layout bugs a text-only pass never would.
- **Briefs with non-ASCII characters** (em dashes, currency symbols) get mangled unless the pipe encoding is set to UTF-8. The script does that.
