# supabuild

A `/supabuild` slash command for Claude Code that turns a one-line task into a clean PR.

## Why bother

If you've left Claude Code running for thirty minutes on a real task, you've hit at least three of these:

**It says "done" and the UI is broken.** A diff doesn't tell you whether the new modal actually opens. You pull the branch, boot the dev server, and find out by hand. supabuild won't say APPROVED until a Playwright walkthrough has booted the dev server, clicked through the change, and left a `.webm` plus step screenshots on disk at `.supabuild/evidence/`. The reviewer checks the file exists before passing the gate.

**It "ships" without ever opening a PR.** Claude does the work, declares victory, and the branch sits on your laptop. You find it three days later. supabuild's build mode only counts a build done after `gh pr create` returns a URL, and prints that URL back to you.

**It loses the screenshots in your ticket.** You paste a Linear ticket with three reference images and watch Claude ignore them, because `uploads.linear.app` URLs are auth-gated and the agent can't render them. `/supabuild linear` downloads them with your token first, drops them where the build team can vision them, and only then starts work. `/supabuild github` hydrates `user-attachments` URLs the same way (those are public, but the build still wants them on disk).

**It mutates your working tree.** Two parallel runs, two half-done branches, one dirty index. Every supabuild run happens in a fresh `git worktree` in a sibling directory, on a branch named for the task. After the PR opens, the worktree is removed.

**It trashes your dev database.** Two parallel builds running migrations against the same Postgres tramples both. supabuild detects the DB service in your `docker-compose.yml`, gives each worktree its own logical database (`<parent>_<slug>`), points the worktree's `.env` at it, and drops it when the PR opens. Best-effort: if there's no compose file, it skips and continues.

**You get one design option when you wanted three.** "Redesign the empty state" comes back as a single take you then have to argue with. `/supabuild design` builds 2–10 divergent variants in parallel, each in its own worktree, and opens an HTML gallery with screenshots so you can pick one.

## Key features

Everything that has to be true for a Claude Code build to ship without you babysitting it.

- **Ticket queue burndown** — `/supabuild linear` (§C) and `/supabuild github` (§E) drain a `Todo` column one ticket at a time, one PR per ticket, with state and label transitions narrated as comments.
- **Multi-agent orchestration** — a Team Lead picks 2–10 specialist subagents per build, dispatches independent ones in parallel and dependent ones in sequence, and renders the final go/no-go itself (§A.2 step 7, §A.3).
- **Live plan artifact** — the §A.2 plan is written to `$WT_PATH/.supabuild/plan.md` and mirrored into the Linear/GitHub ticket description and PR body, updated on every round, security finding, QA verdict, and ship (§A.2.5).
- **Isolated worktree per task** — every build runs in a sibling `git worktree` on its own branch, so parallel runs never share an index and the main checkout stays untouched (§A.1).
- **Per-worktree DB branch** — Postgres, MySQL/MariaDB, and Mongo are auto-detected from `docker-compose.yml`; each worktree gets its own logical database, wired into `$WT_PATH/.env`, and dropped on ship (§A.1.5).
- **Security audit gate** — a Security agent reviews only the diff since `$BASE_SHA`; any Critical or High finding hard-blocks the ship and forces a fix round (§A.4).
- **Playwright walkthrough as APPROVED precondition** — when the diff touches UI, `playwright-cli` boots the project's dev server, records a `.webm` walkthrough plus step PNGs, and the file must exist and be ≥50KB or APPROVED is refused (§A.5 step 3, §A.5a).
- **Polish & gap pass** — before QA, the Team Lead walks an explicit edge-case / a11y / responsive / observability checklist and dispatches a scoped polish round if the list isn't trivial (§A.4.5).
- **Parallel design exploration** — `/supabuild design` produces 2–10 divergent variants, each in its own worktree, judged by a Design Lead on thesis fidelity / craft / differentiation, surfaced via an auto-opened HTML gallery (§B.2, §B.6, §B.6.5).
- **First-run GitHub setup** — on first invocation in a repo, `/supabuild github` creates the Projects v2 board, the `Status` field with `Todo / In Progress / In Review / Done`, and the four labels supabuild uses; idempotent thereafter (§E.0.5).
- **One-PR-per-ticket isolation** — a `gh pr list` snapshot is taken before the §A flow runs and re-checked after; zero or more than one new PR for the ticket's branch stops the loop (§C.3c, §E.3).
- **Auth-gated image hydration** — Linear `uploads.linear.app` attachments are downloaded with the user's token (parallel, capped at 8) and dropped on disk so the agents can actually see them; GitHub `user-attachments` URLs get the same treatment (§C.3a-img, §E.3a-img).
- **Evidence stays off the diff** — walkthrough videos and step screenshots live under `$WT_PATH/.supabuild/evidence/` and are uploaded to the ticket or PR comment, never committed, so `git log` and `Files changed` stay clean (§A.5.5).
- **Auth-gap walkthrough** — on first run, missing `gh` or `linear-cli` install/auth is detected, what can be installed via `brew`/`npm` is, and the one or two `auth login` commands you still need are printed before a long build can start (§A.1 preflight, §C.1).

## Install

```bash
claude plugin marketplace add jaequery/supabuild
claude plugin install supabuild@supabuild
```

The first time you run a mode that needs [`gh`](https://cli.github.com) or [`@schpet/linear-cli`](https://github.com/schpet/linear-cli), supabuild detects what's missing, installs what it can via `brew` or `npm`, and prints the one or two `auth login` commands you need — in a single pass.

## What it does

Five flows. Pick the one that matches your pain.

```
/supabuild add an oauth login button to the navbar
```
Default mode — the answer to "Claude broke the UI and called it done". Plans, dispatches 2–10 specialist subagents in parallel, runs a security audit, runs the Playwright QA gate, loops until clean. Add `--branch main` to push and open a PR when the gate passes.

```
/supabuild design redesign the empty state for the projects page
```
The answer to "I wanted options, not a single take". Builds N divergent variants in parallel, each on its own worktree and branch, screenshots them, opens a gallery.

```
/supabuild linear
```
The answer to "the ticket has a description, screenshots, and a stakeholder watching it". Pulls every ticket in `Todo`, hydrates description images locally, runs each through the build flow, opens one PR per ticket. Every state move is also posted back to the ticket as a comment, so a non-developer can follow along without your terminal.

```
/supabuild github
```
Same idea, over a GitHub Projects v2 board. On first run in a repo, creates a `Build Queue` project with a Status field and the labels supabuild uses, then drains every issue in `Todo`. State moves and verdicts are posted as issue comments.

```
/supabuild github fix the invoice rounding bug on the billing page
```

Creates a GitHub issue, drops it in `Todo`, then includes it in the run.

```
/supabuild worktree experiment with a different rate limiter
```
The answer to "I just want an isolated branch for one-off work". Spins up a worktree, no agents.

## How it works

A single `SKILL.md` with mode routing, plus a roster of specialist subagents. Auth lives in `linear-cli` and `gh` — supabuild never stores tokens itself. The clean-code bar (no dead code, no `console.log`, reuse existing patterns, minimal diff) is enforced by the `§A.5` reviewer, not a wishlist in a prompt.

For Linear runs, the comment trail on a ticket reads roughly:

```
ENG-130 — Fix invoice rounding bug on the billing page
state: Todo → In Progress
picked up by /supabuild linear
walkthrough captured
QA + code review APPROVED
PR opened: github.com/…/pull/46
state: In Progress → In Review
```

If you want the full picture, read [`plugins/supabuild/skills/supabuild/SKILL.md`](plugins/supabuild/skills/supabuild/SKILL.md). It's the source of truth — the slash command is a thin wrapper.

## Caveats

- Runs in your Claude Code session. No daemon, no cloud. Close the session and the run stops.
- `linear` mode needs Linear; `github` mode needs a GitHub repo. The other three need neither.
- Output is plain git branches and PRs. If a build goes sideways, check out the branch and finish by hand.

## License

MIT
