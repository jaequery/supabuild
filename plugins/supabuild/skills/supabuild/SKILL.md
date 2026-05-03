---
name: supabuild
description: >
  Multi-mode build / design / Linear-burndown / GitHub-burndown / worktree skill.
  Parses the first whitespace-delimited token of $ARGUMENTS as a mode:
  `build` runs a Team Lead orchestrator (plan → 2–10 specialist subagents
  → security audit → QA + code review, looping until clean) in an isolated
  git worktree, optionally pushing to a target branch and opening a PR;
  `design` generates 2–10 divergent design variants in parallel, each in
  its own worktree, critiqued by a world-class Design Lead; `linear` burns
  down a Linear "Todo" queue, one clean PR per ticket, narrating every
  state/label transition back into Linear; `github` is the same backlog
  burndown over a GitHub Projects v2 board (auto-creates the project + Status
  field + label set on first run); `worktree` is the thin
  `git worktree` wrapper used as a building block. Use when the user
  says "/supabuild ...", "/supabuild design ...",
  "/supabuild linear", "/supabuild github", "/supabuild worktree ...", "ceo build", "chief
  executive build", "build with a chief and team", "build this with a
  chief and team", "run this as a chief-led build", "multi-agent build",
  "build with QA gate", "design variants", "give me design options",
  "show me variants", "explore directions", "I want to pick from a few
  looks", "burn down my linear todos", "burn down linear", "ship every
  linear todo", "burn down my github project", "burn down github", "ship
  every github todo", "github project burndown", "do X in a worktree",
  "run this in an isolated branch", "spin up a worktree for Z",
  "isolated branch", or otherwise wants a multi-agent build, parallel
  design exploration, autonomous Linear or GitHub-Projects backlog
  burndown, or a side-branch workspace that won't disturb the
  current checkout. Mode-routing is explicit: the first token of
  $ARGUMENTS picks §A (build) / §B (design) / §C (linear) / §D
  (worktree) / §E (github); natural-language phrase invocations route
  to the same sections.
---

# /supabuild — Multi-Agent Build / Design / Linear-Burndown / GitHub-Burndown / Worktree

`/supabuild` is one mode-routed entry point with five flows. Each flow's
full instructions live in `modes/<mode>.md` and are **loaded on demand** —
this file is just the router. Loading only the routed mode file (instead
of the whole skill body) is what keeps small invocations small.

## Mode routing

Parse `$ARGUMENTS`. Take the first whitespace-delimited token
(lowercased) as the mode:

| Token | Section | Mode file to Read |
|---|---|---|
| `build` | §A — multi-agent build | `modes/build.md` |
| `design` | §B — divergent design variants | `modes/design.md` |
| `linear` | §C — Linear backlog burndown | `modes/linear.md` |
| `worktree` | §D — git-worktree wrapper | `modes/worktree.md` |
| `github` | §E — GitHub Projects v2 burndown | `modes/github.md` |

Whatever follows the mode token in `$ARGUMENTS` is the task description /
flags for that mode. The mode file's own §X.0 inputs section parses what's
left.

If the first token is none of the above (or `$ARGUMENTS` is empty), treat
the entire string as a freeform task description and route to **§A
(build)** — Read `modes/build.md` and pass the full `$ARGUMENTS` through
as the task description.

Natural-language phrase invocations route the same way:

- "ceo build", "chief executive build", "build with a chief and team",
  "build this with a chief and team", "run this as a chief-led build",
  "multi-agent build", "build with QA gate" → §A.
- "design variants", "give me design options", "show me variants",
  "explore directions", "I want to pick from a few looks" → §B.
- "burn down my linear todos", "burn down linear", "ship every linear
  todo" → §C.
- "do X in a worktree", "run this in an isolated branch", "spin up a
  worktree for Z", "isolated branch" → §D.
- "burn down my github project", "burn down github", "ship every github
  todo", "github project burndown", "github backlog burndown" → §E.

## How to load a mode

Once the mode is decided:

1. **Read the mode file** at `<skill-base>/modes/<mode>.md`, where
   `<skill-base>` is the "Base directory for this skill" path printed at
   the top of the skill invocation (e.g.
   `/Users/.../plugins/cache/supabuild/supabuild/<version>/skills/supabuild`).
   Use the Read tool with the absolute path.
2. Follow the loaded mode file's instructions verbatim. Each mode file is
   self-contained and uses `§A`/`§B`/`§C`/`§D`/`§E` letter prefixes for
   internal cross-references, so there's no ambiguity between, e.g., "§3"
   in build (a build round) and "§3" in linear (a per-ticket loop).
3. **Do not load mode files you don't need.** Loading more than the
   routed mode is the bug this split exists to prevent. The only legit
   reason to load a second mode file is the cross-mode dispatch rule
   below.

### Cross-mode dispatch (only §C and §E)

Two flows orchestrate other flows:

- **§C (linear) dispatches §A (build)** inline once per ticket on the
  BUILD route, and **§B (design)** inline once per ticket on the
  DESIGN_EXPLORATION route. Read `modes/build.md` (or `modes/design.md`)
  **only when §C actually reaches that step** — e.g. just before §C.3c
  for the build dispatch, or just before §C.3-design step 3 for the
  design dispatch. Do not pre-load.
- **§E (github) dispatches §A (build)** inline once per issue. Read
  `modes/build.md` only when §E reaches §E.3c. Same lazy-load rule.

§A, §B, §D never dispatch other modes — they're terminal.
