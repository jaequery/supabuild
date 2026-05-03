# supabuild

A `/supabuild` slash command for Claude Code. The default is a multi-agent build pipeline; three keywords switch into other modes:

- `/supabuild <task>` — plan → multi-agent build → security audit → QA gate loop, in an isolated git worktree (default)
- `/supabuild design <task>` — generates N parallel UI design variants
- `/supabuild linear` — burns down a Linear "Todo" queue, one PR per ticket
- `/supabuild worktree <task>` — thin `git worktree` wrapper

## Install

```bash
claude plugin marketplace add jaequery/supabuild
claude plugin install supabuild@supabuild
```

For `linear` mode you'll also need [`@schpet/linear-cli`](https://github.com/schpet/linear-cli) and [`gh`](https://cli.github.com). The skill detects missing CLIs or auth on first run and walks you through setup.

## Usage

```
/supabuild add an oauth login button to the navbar
```

Plans, dispatches 2–10 specialist subagents in parallel, runs a security audit and QA gate, loops until the work passes. Add `--branch main` to push and open a PR when done.

```
/supabuild design redesign the empty state for the projects page
```

Generates 2–10 divergent design variants in parallel, each in its own worktree and branch. Opens an HTML gallery with screenshots so you can pick.

```
/supabuild linear
```

Pulls every Linear ticket in `Todo`, runs each through `build` mode, opens one PR per ticket. Every state move, label change, and verdict is posted back to the Linear ticket as a comment.

```
/supabuild linear fix the invoice rounding bug on the billing page
```

Creates a `Todo` ticket from your sentence first, then includes it in the run.

```
/supabuild worktree experiment with a different rate limiter
```

Just spins up an isolated worktree + branch. No agents dispatched.

## How it works

A single `SKILL.md` with mode routing, plus a roster of specialist subagents (engineering, design, testing, security). Auth lives in `linear-cli` and `gh` — supabuild never stores tokens itself.

For `linear` mode, the comment trail on a ticket looks roughly like:

```
ENG-130 — Fix invoice rounding bug on the billing page
state: Todo → In Progress
picked up by /supabuild linear
build started — branch: supabuild/eng-130-invoice-rounding-…
walkthrough captured
QA + code review APPROVED
PR opened: github.com/…/pull/46
state: In Progress → In Review
```

So you can follow a run from the Linear ticket without opening a terminal.

## Caveats

- Runs locally in your Claude Code session. No daemon, no cloud. Close the session and the run stops.
- `linear` mode is Linear-specific. The other three modes work without Linear.
- Output is plain git branches and PRs. If a build goes sideways, check out the branch and finish by hand.

## License

MIT
