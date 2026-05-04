# supabuild

Multi-agent builds, design exploration, and ticket-queue burndown for Claude Code — every diff goes through a security audit, a polish pass, and a Playwright walkthrough before it ships.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/jaequery/supabuild?style=for-the-badge)](https://github.com/jaequery/supabuild/stargazers)

```bash
claude plugin marketplace add jaequery/supabuild
claude plugin install supabuild@supabuild
```

**Works wherever Claude Code runs — Mac, Windows, Linux.**

---

[Why I Built This](#why-i-built-this) · [How It Works](#how-it-works) · [Why It Works](#why-it-works) · [Commands](#commands) · [Configuration](#configuration) · [Caveats](#caveats) · [License](#license)

---

> [!IMPORTANT]
> **First run:** The first time you run a mode that needs [`gh`](https://cli.github.com) or [`@schpet/linear-cli`](https://github.com/schpet/linear-cli), supabuild detects what's missing, installs what it can via `brew` or `npm`, and prints the one or two `auth login` commands you still need — before any long build starts. See [§C.1 / §A.1 preflight](plugins/supabuild/skills/supabuild/SKILL.md) in the skill for the full auth-gap walkthrough.

---

## Why I Built This

I kept running into the same wall: Claude would ship code that passed its own made-up QA bar — "looks good to me" — and broke the UI in three places. Not because Claude is bad. Because nothing was enforcing a real bar.

I wanted a flow where "done" meant: the code compiles, a security agent actually reviewed the diff, a polish agent walked an explicit a11y and edge-case checklist, and a Playwright recording exists proving the UI still works. I wanted each build isolated in its own git worktree so parallel runs couldn't step on each other. I wanted my Linear and GitHub queues to drain themselves, one clean PR per ticket, with status updates posted back to the ticket so a stakeholder could follow along without pinging me.

None of that existed as a single command. So I built it.

Every knob described above is baked into `/supabuild`. You don't configure it. You run it and it does the right thing.

— Jae ([@jaequery](https://github.com/jaequery))

---

## Who This Is For

supabuild is for developers who use Claude Code as a serious build tool, not a novelty. Specifically:

- **Solo devs** who want Claude to ship a complete, QA-gated PR without supervision.
- **Small teams** burning down a Linear or GitHub Projects backlog and tired of babysitting each ticket.
- **Anyone** who has had Claude declare "QA passed" on a build that visibly broke the UI.
- **Designers and engineers** who want to explore multiple visual directions in parallel rather than settling on one take.
- **Developers with a Postgres, MySQL, or Mongo project** who want isolated DB state per build without managing it themselves.

If you're using Claude Code for one-off completions, the overhead here is not for you. If you're using it to ship features end-to-end, it is.

The flow is designed for teams where the ticket queue IS the backlog and shipping clean PRs IS the definition of done. If that's not your context, the individual modes (especially `worktree` and `design`) still work standalone.

---

## Getting Started

Install the plugin, then invoke any of the five modes directly from Claude Code:

```bash
/supabuild add an oauth login button to the navbar
```

That's it. supabuild handles worktree setup, agent dispatch, security review, QA gate, and (optionally) the PR. No project initialization step. No config file to create.

<details>
<summary>First-time auth setup (Linear / GitHub)</summary>

supabuild never stores tokens itself. Auth lives in `gh` and `linear-cli`.

For **GitHub mode**, install and authenticate the GitHub CLI:

```bash
brew install gh
gh auth login
```

For **Linear mode**, install and authenticate the Linear CLI:

```bash
npm install -g @schpet/linear-cli
linear auth login
```

supabuild detects missing tools on first use, installs what it can automatically, and tells you exactly which `auth login` command to run if anything is still missing.

</details>

<details>
<summary>Per-worktree database setup</summary>

If your project has a `docker-compose.yml` with a Postgres, MySQL/MariaDB, or MongoDB service, supabuild detects it automatically. Each worktree gets its own logical database wired into `$WT_PATH/.env` and dropped cleanly on ship. No manual configuration needed.

</details>

---

## How It Works

A single [`SKILL.md`](plugins/supabuild/skills/supabuild/SKILL.md) routes the first token of your input to one of five mode files. Each mode file is loaded on demand — only the file you actually need is ever read into context. Auth lives in `linear-cli` and `gh`; supabuild never stores tokens itself.

The rough shape of a build run:

```
task description
  → Team Lead writes plan.md
  → 2–10 specialist subagents (parallel where independent)
  → Security agent reviews diff
  → Polish agent checks a11y, edge cases, observability
  → Playwright records walkthrough (if UI changed)
  → APPROVED → PR opened
```

Everything after the task description is automatic.

### 1. Build (default)

```
/supabuild add an oauth login button to the navbar
```

The default mode. A Team Lead reads your task, writes a `plan.md`, and dispatches 2–10 specialist subagents — parallel where independent, sequential where dependent. After the build round, a Security agent reviews only the diff since `$BASE_SHA`. Any Critical or High finding hard-blocks the ship and forces a fix round. Then a polish agent walks an explicit edge-case / a11y / responsive / observability checklist. If the diff touches UI, `playwright-cli` boots the dev server, records a `.webm` walkthrough, and the file must exist and be ≥50KB or the ship is refused. Only once all three gates pass does `/supabuild` open a PR.

### 2. Design

```
/supabuild design redesign the empty state for the projects page
```

Builds N divergent visual variants in parallel — each in its own worktree and branch — screenshots them, and opens an HTML gallery. A Design Lead critiques each variant on thesis fidelity, craft, and differentiation. You pick one, merge it, abandon the rest.

### 3. Linear burndown

```
/supabuild linear
```

Pulls every ticket in your Linear `Todo` column, hydrates description images locally (Linear `uploads.linear.app` attachments downloaded with your token), and runs each ticket through the full build flow — one clean PR per ticket. Every state transition is posted back to the ticket as a comment:

```
ENG-130 — Fix invoice rounding bug on the billing page
state: Todo → In Progress
picked up by /supabuild linear
walkthrough captured
QA + code review APPROVED
PR opened: github.com/…/pull/46
state: In Progress → In Review
```

### 4. GitHub burndown

```
/supabuild github
```

Same idea, over a GitHub Projects v2 board. On first run in a repo, supabuild creates the project, the `Status` field with `Todo / In Progress / In Review / Done`, and the four labels it uses — idempotent thereafter. Drains every issue in `Todo`, one PR per issue, state moves and verdicts posted as issue comments.

You can also create a new issue and immediately burn it down:

```
/supabuild github fix the invoice rounding bug on the billing page
```

### 5. Worktree

```
/supabuild worktree experiment with a different rate limiter
```

The thin git worktree wrapper without the agent stack. Spins up a sibling worktree on its own branch for isolated one-off work. No Team Lead, no QA gate — just a clean branch that won't disturb your current checkout.

---

## Why It Works

### Worktree isolation per task

Every build runs in a sibling `git worktree` on its own branch. Parallel runs never share an index. The main checkout stays untouched throughout. If a build goes sideways, you check out the branch and finish by hand — nothing has polluted your working tree. This is the structural reason supabuild can run multiple builds simultaneously without them interfering (§A.1).

### Multi-agent orchestration

A Team Lead plans the work, picks 2–10 specialists, and dispatches independent ones in parallel. The Team Lead renders the final go/no-go itself — it doesn't delegate that decision to a subagent. Specialist scope is scoped to the diff, not the whole repo, which keeps each agent's context tight and its judgment reliable (§A.2.7, §A.3).

### Live plan artifact

The §A.2 plan is written to `$WT_PATH/.supabuild/plan.md` and mirrored into the Linear/GitHub ticket description and PR body. It's updated on every round, every security finding, every QA verdict, and every ship event. At any point, opening the ticket shows you exactly where the build stands (§A.2.5).

### Security + polish + walkthrough gates

Three hard gates, in sequence, before any PR opens:

1. **Security audit** — a Security agent reviews only the diff since `$BASE_SHA`. Any Critical or High finding hard-blocks the ship (§A.4).
2. **Polish pass** — before QA, the Team Lead walks an explicit edge-case / a11y / responsive / observability checklist and dispatches a scoped polish round if anything is non-trivial (§A.4.5).
3. **Playwright walkthrough** — when the diff touches UI, `playwright-cli` records a `.webm` walkthrough plus step PNGs. The file must exist and be ≥50KB or APPROVED is refused (§A.5 step 3, §A.5a).

Evidence (videos and screenshots) lives under `$WT_PATH/.supabuild/evidence/` and is uploaded to the ticket or PR comment — never committed, so `git log` and `Files changed` stay clean (§A.5.5).

### Per-worktree DB branch

Postgres, MySQL/MariaDB, and MongoDB are auto-detected from `docker-compose.yml`. Each worktree gets its own logical database, wired into `$WT_PATH/.env`, and dropped on ship. Parallel builds don't share a database any more than they share a git index (§A.1.5).

### One PR per ticket

A `gh pr list` snapshot is taken before the §A flow runs and re-checked after. Zero new PRs or more than one new PR for the ticket's branch stops the loop — the guarantee is strict. You always know exactly which PR corresponds to which ticket (§C.3c, §E.3).

### Token-saving by default

Running a full build — plan, dispatch 5 specialists, security pass, QA loop, ship — costs a fraction of the equivalent free-form Claude conversation. None of this is a knob you flip; it's baked in:

- **Right model for the role.** Mechanical roles run on Haiku, implementers on Sonnet, only the orchestrator runs on Opus. Every subagent gets the cheapest model that can do its job.
- **Cache-friendly prompts.** Subagent dispatches share a stable prefix so the prompt cache hits across the dozen-plus turns a single build produces.
- **Delta-only remediations.** Round 2+ ships a single remediator scoped to just the findings, instead of re-running the full specialist roster against the full diff.
- **Lazy-loaded phases.** Walkthrough capture and the ship/PR sequence are only loaded into context when those phases actually fire. A backend-only build never reads a byte of the Playwright instructions.
- **No polluted retries.** Each build runs in a clean worktree on its own branch, so failure modes that cost extra context — agents stepping on each other's edits, rebuilding state after a bad merge — just don't happen.

Net effect: roughly 40–60% fewer tokens than the same multi-agent build done as a free-form Claude conversation, without giving up safety or completeness.

---

## Commands

| Command | Purpose | Group |
|---|---|---|
| `/supabuild <task>` | Multi-agent build with security + QA gate + optional PR | Build |
| `/supabuild build <task>` | Same as above, explicit mode token | Build |
| `/supabuild design <task>` | Parallel design variants, HTML gallery, Design Lead critique | Design |
| `/supabuild linear` | Burn down Linear `Todo` queue, one PR per ticket | Burndown |
| `/supabuild github` | Burn down GitHub Projects `Todo` queue, one PR per issue | Burndown |
| `/supabuild github <task>` | Create a GitHub issue, drop it in `Todo`, burn it down | Burndown |
| `/supabuild worktree <task>` | Isolated git worktree, no agent stack | Worktree |

Full mode details and internal section references live in [`plugins/supabuild/skills/supabuild/SKILL.md`](plugins/supabuild/skills/supabuild/SKILL.md).

---

## Configuration

supabuild persists lightweight config via `git config` in the repo. Most keys are set automatically on first use.

| Key | What it stores | Set by |
|---|---|---|
| `supabuild.linearTeamId` | Linear team ID for ticket queries | Auto-detected on first `linear` run |
| `supabuild.githubProjectNumber` | GitHub Projects v2 project number | Auto-created on first `github` run |
| `supabuild.steps` | Comma-separated phase CSV for custom build order | Optional manual override |

You can inspect or override any key with `git config supabuild.<key>`. No config file, no `.env` to create. The only setup that requires action is `gh auth login` and `linear auth login` if you're using those modes — and supabuild will tell you when you need to run them.

To check what supabuild has stored in the current repo:

```bash
git config --get-regexp supabuild
```

To clear a key (e.g. reset the project number to force supabuild to re-detect it):

```bash
git config --unset supabuild.githubProjectNumber
```

---

## Troubleshooting

**The build stopped mid-run.**
Builds run inside your Claude Code session. Close the session and the run stops. The worktree and branch are still there — check out the branch and continue by hand, or re-run `/supabuild` with the same task from a fresh session. It will detect the existing worktree.

**The Playwright gate refused APPROVED with "file too small".**
The `.webm` walkthrough must be ≥50KB. This usually means the dev server didn't fully start before the recording began. Check that your dev server starts cleanly with `npm run dev` (or equivalent) and try again. The gate is intentionally strict — a 3KB file is a blank recording.

**`gh` or `linear` auth errors on first run.**
supabuild prints the exact commands needed. Run them in your terminal (not inside Claude Code), then re-invoke `/supabuild`. The auth-gap walkthrough (§A.1 / §C.1) handles every known missing-tool case.

**A ticket produced zero new PRs or more than one.**
The one-PR-per-ticket guarantee tripped. This usually means a PR already existed for the branch (zero new) or a parallel run opened one before this run finished (more than one). supabuild stops the loop rather than guess which PR is correct. Inspect with `gh pr list` and clean up manually.

**The worktree wasn't cleaned up after a failed build.**
Run `git worktree list` to see all active worktrees. Remove a stale one with `git worktree remove <path> --force`, then delete the branch with `git branch -D <branch>`.

---

## Caveats

- Runs in your Claude Code session. No daemon, no cloud. Close the session and the run stops.
- `linear` mode needs Linear; `github` mode needs a GitHub repo. The other three modes need neither.
- Output is plain git branches and PRs. If a build goes sideways, check out the branch and finish by hand.

---

## Star History

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=jaequery/supabuild&type=Date&theme=dark" />
  <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=jaequery/supabuild&type=Date" />
  <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=jaequery/supabuild&type=Date" />
</picture>

---

## License

MIT — see [LICENSE](LICENSE).

---

**Claude Code can ship. supabuild makes sure it actually shipped.**
