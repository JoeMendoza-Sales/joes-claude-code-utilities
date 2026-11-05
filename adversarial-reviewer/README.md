# Adversarial reviewer

A subagent template for reviewing anything that has to follow written rules and stay true to a source of truth: resumes, proposals, client emails, docs, copy.

## Why it's built this way

I built this after reviews kept passing work that broke rules I'd written down. Three things were going wrong:

1. **The reviewer reviewed from a summary of the rules.** When the main conversation spawns a reviewer and paraphrases the rules for it, the paraphrase drops the small rules. So this agent is required to read every rules file **in full, itself, every run**, and to say it isn't qualified to report if it hasn't.
2. **Hard rules got scored like opinions.** A rule saying "never X" would lose to a confidence threshold and get filtered out as a nitpick. So findings are split into two tiers. Violations of written rules and untraceable claims are **blockers**: never scored, never filtered. Everything else is scored, and only findings at 70% confidence or higher are reported.
3. **Precedent excused violations.** "The last draft did it" and "you passed this before" stopped counting. A rule is a rule every time.

It's also told to **assume the artifact is wrong somewhere**, which finds more than "check this for issues". And a clean pass has to say exactly what it checked, so "looks good" can't hide a skipped step.

## Install

1. Copy `reviewer.md` to `~/.claude/agents/` (all projects) or `<project>/.claude/agents/` (one project). Rename it to something specific, like `proposal-reviewer.md`, and change `name:` to match.
2. Fill in the `[[placeholders]]`: what it reviews, the path to your source of truth, your rules files, and any domain-specific never-rules.
3. Ask Claude to "run the proposal-reviewer on draft.md". It runs with read-only tools (Read, Grep, Glob), so it can't edit what it's judging.

## Pairs well with

A `CLAUDE.md` rule like: *"Before showing me any draft of X, run the X-reviewer on it and fix every BLOCKER."*
