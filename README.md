# supabuild

A single `/supabuild` slash command for Claude Code that orchestrates multi-agent builds, parallel design exploration, Linear backlog burndown, and isolated worktree tasks — with a security audit and QA gate built in.

## Install

```bash
claude plugin marketplace add jaequery/supabuild
claude plugin install supabuild@supabuild
```

## Usage

`/supabuild` routes on the first token. When invoked without a mode token, it defaults to `build`.

- `/supabuild build <task description>` — Multi-agent build with security audit and a final QA gate that loops until clean.
- `/supabuild design <task description>` — Parallel design-variant exploration (2–10 variants, each in its own isolated git worktree and branch).
- `/supabuild linear` — Ship every Linear ticket sitting in **Todo**, one isolated worktree and one PR per ticket. No args needed.
- `/supabuild linear <task description>` — Same thing, but first creates a new Linear ticket from your description (e.g. `/supabuild linear fix login issue`) and includes it in the run.
- `/supabuild worktree <task>` — Execute a task in an isolated git worktree with a 6-option cleanup menu when done.

## Example workflow

A typical end-to-end run — design exploration first, then a clean build, then autonomous backlog burndown for the follow-ups.

### 1. Explore design directions

```
/supabuild design build a settings page with profile, billing, and team management
```

The Design Lead drafts a brief, spins up N parallel worktrees, and dispatches a per-variant team into each:

```
| Variant         | Branch                                | Worktree                              |
|-----------------|---------------------------------------|---------------------------------------|
| swiss-grid      | supabuild-design/settings-swiss-grid  | ../repo.supabuild-design-settings-... |
| brutalist       | supabuild-design/settings-brutalist   | ../repo.supabuild-design-settings-... |
| editorial-serif | supabuild-design/settings-editorial   | ../repo.supabuild-design-settings-... |
| playful-collage | supabuild-design/settings-playful     | ../repo.supabuild-design-settings-... |
```

After the build round, an HTML gallery opens in your browser with screenshots, scores, and **Pick / Redo / Kill** buttons. You pick `swiss-grid`.

### 2. Build the chosen direction

```
/supabuild build implement the settings page using the swiss-grid variant from supabuild-design/settings-swiss-grid --branch main
```

A plan is announced, 2–10 specialists are dispatched in parallel, a security audit and polish pass run, and a Playwright walkthrough video is captured for any UI-bearing diff. Then it ships:

```
## /supabuild build — APPROVED
**Branch:** supabuild/settings-page-20260502-...
**Commits:** 4, 0408728..b9bc3e4
**Rounds run:** 1
```

The branch is pushed, a PR opened against the target, and the worktree + local branch are removed automatically.

### 3. Burn down the related tickets

With the page live, drain the rest of your Linear **Todo** queue in one pass:

```
/supabuild linear
```

That's the whole command. No flags, no team key, no limit. It picks up every ticket sitting in **Todo**, processes them one at a time, and ships an isolated PR per ticket against `main`.

Or kick off a single new ticket from a sentence — it gets created in Linear first, then immediately worked on:

```
/supabuild linear fix the invoice rounding bug on the billing page
```

### 4. Watch the work narrate itself in Linear

Every state change, label flip, and dispatch lands as a comment on the ticket as it happens, so anyone watching in Linear sees the full timeline without ever opening the terminal:

```
ENG-130
─ state: Todo → In Progress
─ 🤖 picked up by /supabuild linear
       Route: BUILD · Position in queue: 2 / 5
─ label +Building
─ 🛠️ build started
       Working branch: supabuild/eng-130-invoice-rounding-…
       Target (PR base): main
       Mode: plan → parallel specialists → security audit → QA gate
─ label −Building, +Testing
─ 🎬 walkthrough captured (00-walkthrough.webm, 4 step screenshots)
─ ✅ QA + code review APPROVED (1 round)
─ 📎 walkthrough.webm + step screenshots uploaded
─ 🔗 PR opened: github.com/…/pull/46
─ state: In Progress → In Review
─ label −Testing
```

For UI-flavored tickets the path forks into design exploration first — the Design Lead spins up N divergent variants in parallel, posts each variant's screenshots back to the ticket as its own comment, then drops the ticket back into **Todo** with a `Choose Design` label so a human can pick. The next `/supabuild linear` run sees the pick and goes straight to the build path.

When the run finishes you get a single summary table:

```
## /supabuild linear — summary
| Ticket  | Verdict   | PR                       | Linear comment           | Rounds |
|---------|-----------|--------------------------|--------------------------|--------|
| ENG-123 | APPROVED  | github.com/…/pull/45     | linear.app/…/comment-…   | 1      |
| ENG-130 | APPROVED  | github.com/…/pull/46     | linear.app/…/comment-…   | 2      |
```

For one-off scratch work that doesn't need the full QA gate, `/supabuild worktree <task>` gives you the isolated branch and the same 6-option cleanup menu — no agents dispatched.

## What's inside

A single `SKILL.md` with mode routing, plus ~63 specialist subagents across engineering, design, testing, and specialized categories.

## License

MIT
