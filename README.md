# supabuild

A single `/supabuild` slash command for Claude Code: Team-Lead-orchestrated multi-agent builds, parallel design exploration, Linear backlog burndown, and isolated worktree tasks — with a security audit and QA gate built in.

## Install

```bash
claude plugin marketplace add jaequery/supabuild
claude plugin install supabuild@supabuild
```

## Usage

`/supabuild` routes on the first token. When invoked without a mode token, it defaults to `build`.

- `/supabuild build <task description>` — Team-Lead-orchestrated multi-agent build with security audit and a final QA gate that loops until clean.
- `/supabuild design <task description>` — Parallel design-variant exploration (2–10 variants, each in its own isolated git worktree and branch).
- `/supabuild linear` — Burn down every Linear ticket in the Todo workflow status, one isolated worktree and PR per ticket.
- `/supabuild worktree <task>` — Execute a task in an isolated git worktree with a 6-option cleanup menu when done.

## What's inside

A single `SKILL.md` with mode routing, plus ~63 specialist subagents across engineering, design, testing, and specialized categories.

## License

MIT
