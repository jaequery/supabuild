# supabuild

Ship your Linear backlog while you're not at the keyboard — one isolated PR per ticket, narrated back to the ticket as it happens.

A single `/supabuild` slash command for Claude Code. Linear-first, with build / design / worktree modes available standalone if you don't use Linear.

---

## What it does

You have a Linear backlog. It is not getting smaller.

Run this:

```
/supabuild linear
```

Every ticket in **Todo** gets picked up in priority order. Each one gets its own isolated git worktree, runs through a plan → multi-agent build → security audit → QA-gate-with-walkthrough-video loop, opens a PR against `main`, and leaves a paper trail of comments on the Linear ticket so anyone watching can follow along without opening the terminal.

When the run finishes, the column has drained, every ticket sits in **In Review**, and each one has a video walkthrough, step screenshots, a PR link, and a timeline of what happened.

## What a stakeholder sees on a single ticket

The ticket is the dashboard. This is the only thing they need to look at.

```
ENG-130 — Fix invoice rounding bug on the billing page
─ state: Todo → In Progress
─ 🤖 picked up by /supabuild linear
       Route: BUILD · Position in queue: 2 / 5
─ label +Building
─ 🛠️ build started
       Working branch: supabuild/eng-130-invoice-rounding-…
       Target (PR base): main
       Mode: plan → parallel specialists → security audit → QA + code review
─ label −Building, +Testing
─ 🎬 walkthrough captured (00-walkthrough.webm, 4 step screenshots)
─ ✅ QA + code review APPROVED (1 round)
─ 📎 walkthrough.webm + step screenshots uploaded to ticket
─ 🔗 PR opened: github.com/…/pull/46
─ state: In Progress → In Review
─ label −Testing
```

A non-technical co-founder, a client, an investor, your future self looking at this ticket on Monday morning — none of them have to ask "what happened with this?". The answer is on the ticket.

## Why this is worth your time

A few things that aren't obvious until you've tried to wire this up yourself:

- **One PR per ticket, never bundled.** A Linear ticket → a git branch → a PR. No mega-PRs mixing four tickets that need to be carefully untangled in review.
- **Isolated worktrees.** Each ticket runs in its own `git worktree`, so it can't trample your local checkout, and ticket N+1 starts from the same clean baseline as ticket N regardless of what ticket N did.
- **QA gate, not a vibe check.** Every UI-bearing diff captures a Playwright walkthrough video and step screenshots that get uploaded to the ticket. If the walkthrough is missing or under 50 KB, the build does not get marked APPROVED. "Looks good to me" is not a verdict the gate accepts.
- **Security audit on every build.** A security-focused subagent reviews the diff before the QA gate runs. Findings either get fixed in the same round or escalated.
- **Design fork for UI tickets.** If a ticket has a UI label or UI keywords, the path forks: 4 divergent design variants get built in parallel, screenshots posted back to the ticket as their own comments, then the ticket moves to **Todo** with a `Choose Design` label. A human picks. The next run goes straight to build.
- **A single label is the stop button.** `Choose Design` parks a ticket until you decide. `design-selected` resumes it. No bot config, no separate dashboard — the Linear ticket is the source of truth.
- **Linear is the audit log.** Every state move, label flip, dispatch, and verdict is a comment on the ticket. Async standup writes itself.

## Install

```bash
claude plugin marketplace add jaequery/supabuild
claude plugin install supabuild@supabuild
```

You'll also need [`@schpet/linear-cli`](https://github.com/schpet/linear-cli) authed against your workspace, and `gh` for PR creation.

## The three Linear forms

```
/supabuild linear
```

Drains every **Todo** ticket. Sequential, one PR per ticket, base branch `main`. No flags, no team key, no limit.

```
/supabuild linear fix the invoice rounding bug on the billing page
```

Creates a new ticket in **Todo** from your sentence first, then includes it in the run.

```
/supabuild linear --team ENG --limit 5 --parallel 3 --dry-run
```

Flags exist for when you need them (scope to a team, cap the queue, run in parallel, list-only). The no-argument form is the one you'll reach for 90% of the time.

## Without Linear

The same primitives are exposed directly if Linear isn't your tracker:

- `/supabuild build <task>` — Plan → parallel specialist build → security audit → QA gate, looping until clean. Works against any branch.
- `/supabuild design <task>` — N divergent design variants in parallel, each in its own worktree. An HTML gallery opens with screenshots and Pick / Redo / Kill buttons.
- `/supabuild worktree <task>` — Spin up a side-branch workspace with a 6-option cleanup menu when done. No agents dispatched.

These are the same building blocks the Linear flow runs on, just without the ticket narration layer.

## What it isn't

- Not a CI replacement. The build runs locally in your Claude Code session; CI still runs on the resulting PR.
- Not a server-side Linear bot. Close the Claude session and the run stops. There's no daemon, no cloud, no auth tokens stored anywhere supabuild controls.
- Not free of Linear vendor lock-in (the Linear flow specifically) — but the work itself is plain git branches and plain GitHub PRs. Worst case you check out the branch and finish by hand.

## What's inside

A single `SKILL.md` with mode routing, plus ~63 specialist subagents across engineering, design, testing, and specialized categories.

## License

MIT
