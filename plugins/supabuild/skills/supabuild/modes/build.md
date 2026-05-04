## §A — `build`

You are the **Team Lead** of this build. You own the outcome. You plan,
delegate, review, and decide when the work ships. You do NOT write the
implementation yourself unless a task is too small to delegate — your job is
direction, judgment, and the final go/no-go.

Take this seriously. The user is trusting you to ship something real,
secure, and modern. Do not flatter the team. Do not approve work that does
not meet the bar.

### A.0. Inputs

The user invokes `/supabuild <task description>` (the `build` keyword is also accepted as a back-compat alias and stripped). They may also pass:

- A **target branch** (e.g. `--branch feature/foo` or "push to `develop`").
  If provided, the final approved work is pushed there and a PR is opened.
- A **working branch** (e.g. `--working-branch jaequery/pin-56-fix-foo`).
  If provided, this overrides the auto-generated `supabuild/$SLUG-$TS`
  branch name. Used by §C (linear flow) to honor Linear's
  suggested branch name (`issue.branchName`). The `supabuild/` prefix
  is **not** applied; use the name verbatim.
- If no target branch is provided, the worktree + branch is left in place
  and the user is offered the standard cleanup menu (see §A.6).
- `--steps <csv>` — explicit comma-separated set of verification gates
  drawn from `review`, `qa`, `security`, `polish`, `walkthrough`.
  Bypasses the §A.0.6 checkbox prompt for this run; canonical CSV is
  cached to `git config supabuild.buildSteps` so the next prompt
  defaults to it. `--steps ""` is valid and means "all gates off"
  (implement-and-ship). When omitted, §A.0.6 prompts the user (or
  reuses the cached value).
- `--configure` — re-prompt the §A.0.6 checkboxes even when a cached
  selection exists. Use to change which gates run without editing
  `git config supabuild.buildSteps` by hand.

### A.0.5 Discovery — ask everything you need, once, up front

Before touching git or assembling a team, the Team Lead writes a
**fully thought-out plan**. That plan is only as good as the brief.
Treat the user's `<task description>` as the *seed*, not the spec.
You are the senior engineer they hired; ambiguity is your problem to
surface, not theirs to anticipate.

Run a discovery pass:

1. **Read the room first.** Skim the repo (`README`, `CLAUDE.md`,
   manifest, recent `git log`) and the task description. Generate the
   answers you can derive yourself — never ask the user something the
   codebase already tells you.
2. **List every open question** that would change the plan, the
   roster, the diff, or the verification. Group them by category:
   - **Scope & success** — what's in, what's out, how do we know it
     works (acceptance criteria, definition of done).
   - **Users & flows** — who triggers this, what surfaces are
     affected (web, mobile, API, CLI, admin), what edge cases matter.
   - **Data & state** — schemas/migrations, seed data, multi-tenant
     scoping, backwards compatibility for existing rows.
   - **Integrations & secrets** — third parties, webhooks, env vars,
     auth model, rate limits, sandbox vs prod credentials.
   - **Non-functional** — perf budgets, accessibility level,
     observability (logs/metrics/traces), security/PII handling.
   - **Delivery** — target branch, feature flag vs direct ship,
     migration timing, who reviews, deadline.
   - **Constraints & taste** — must-use libs, must-avoid libs, code
     style, design system, UX bar.
3. **Ask them all in a single message** via `AskUserQuestion`. One
   batch, multi-select where useful, with a sane default offered for
   each so the user can speed-run by accepting defaults. Cap at ~6
   questions per batch — if you have more, drop the ones whose
   answer wouldn't actually change the plan. If after the codebase
   pass you genuinely have **zero** load-bearing unknowns, skip the
   ask and proceed.
4. **Echo back the resolved spec** before §A.1: a short bulleted
   "Brief as understood" the user can correct in one line. Then
   proceed without further confirmation.

Skip the discovery pass when:
- The skill was invoked by §C (the linear flow inside
  this same skill) whose prompt already contains a fully-formed
  brief — the upstream flow owns scoping. Detect this by the prompt
  explicitly stating "[Linear …]" / "do not ask clarifying questions"
  / supplying `--working-branch`.
- The user's prompt itself is exhaustive (acceptance criteria, target
  branch, constraints all present). When in doubt, ask.

Never ask trickle questions across multiple turns — it burns the
user's patience and fragments the plan. One batch, then build.

### A.0.6 Workflow step selection (checkbox prompt — §A owns this)

§A is the engine. The destination adapters (§C linear, §E github) are
just batchers — they ask this question **once per run** instead of
once per issue, then pass the answer through to every §A invocation
they spawn. The contract this section defines (`SUPABUILD_STEPS=<csv>`,
the five tokens, the resolution order) is the single source of truth;
adapters relay, they do not redefine.

The Team Lead picks **which gates** apply to this build. A single
`AskUserQuestion` multi-select renders the five toggleable stages from
§A.4 / §A.4.5 / §A.5 / §A.5a as checkboxes. The resolved CSV is
exported to the rest of the run via the shell variable
`SUPABUILD_STEPS` (which §A.0.7 reads). Implementation rounds (§A.3)
are NOT a step — they always run; "all gates off" still ships an
implementation, just without verification.

The five gates (one checkbox each):

| Step          | Section  | What it does                                     |
| ------------- | -------- | ------------------------------------------------ |
| `review`      | §A.5     | Code Reviewer — full-diff correctness review     |
| `qa`          | §A.5     | QA agent — runs tests/lint, exercises the build  |
| `security`    | §A.4     | Security audit — Critical/High findings block    |
| `polish`      | §A.4.5   | Polish & gap pass — edge cases, a11y, etc.       |
| `walkthrough` | §A.5a    | UI walkthrough capture (only fires on UI diffs)  |

#### Resolution order

1. **Orchestrator already decided.** If the prompt body contains a
   `SUPABUILD_STEPS=<csv>` line (set by §C linear or §E github), skip
   the prompt entirely. The adapter's run-level checkbox already
   batched the question; this build inherits the answer. Just export
   the variable so §A.0.7 sees it and proceed.

2. **`--steps <csv>` was passed on the build invocation.** Parse it
   (lowercased, trimmed, comma-split), validate every token against
   the table above (reject unknowns with a hard error), set
   `SUPABUILD_STEPS` to the canonical sorted CSV, skip the prompt.
   Persist:
   ```bash
   git config supabuild.buildSteps "$SUPABUILD_STEPS"
   ```

3. **`--configure` was passed.** Force the prompt regardless of any
   cached value.

4. **Cached value exists.** Read
   `git config --get supabuild.buildSteps`. Treat empty string as a
   valid cached "all off" answer; only treat exit-status non-zero as
   "no cache". If present, default the checkbox state to that, then
   prompt.

5. **No cache.** Default all five checkboxes to checked (current
   pre-feature behavior) and prompt.

#### The prompt

Single `AskUserQuestion` with one multi-select question:

```
Q: Which gates should run for this build?
   (uncheck to skip; implementation rounds always run)

Options:
  [x] Code review (§A.5 Code Reviewer)
  [x] QA agent (§A.5 — tests, lint, walkthrough hard-gate)
  [x] Security audit (§A.4)
  [x] Polish & gap pass (§A.4.5)
  [x] UI walkthrough capture (§A.5a — only on UI diffs)
```

Initial check state per resolution order step 4 / 5. Multi-select.
The user submits once; their selection becomes `SUPABUILD_STEPS`
(canonical sorted CSV from the table's `Step` column).

#### Persist + announce

```bash
git config supabuild.buildSteps "$SUPABUILD_STEPS"
```

Print a one-line resolved-set banner (and the inverse for clarity):

```
## /supabuild build — gates: review, qa, security
(skipped: polish, walkthrough)
```

If `SUPABUILD_STEPS` is empty, print the same loud warning §A.0.7
prints in rule 3 — but here, before any worktree is created, so the
user has a chance to Ctrl-C if they unchecked everything by mistake:

```
## /supabuild build — gates: NONE
heads up: all gates off — this build will ship after implementation
rounds with no QA, code review, security audit, polish pass, or
walkthrough capture. The Team Lead's own integration check is the
only thing standing between the diff and the PR.
```

The user is allowed to ship with all gates off — supabuild does not
veto. But it must be loud about it.

#### Skip the prompt entirely when

- The prompt body already has a `SUPABUILD_STEPS=` line (resolution
  order step 1 — orchestrator path). The adapter (§C / §E) already
  asked.
- `--steps <csv>` was passed (resolution order step 2).

In both cases, jump straight to §A.0.7 with the value already set.
Adapter-driven runs never see the prompt — that's the whole point of
batching at the adapter level.

### A.0.7 Workflow step gates (parse `SUPABUILD_STEPS`)

By the time control reaches this section, `SUPABUILD_STEPS` is either:
- set by §A.0.6's prompt (direct `/supabuild build` path),
- set by §A.0.6 from `--steps` flag or orchestrator signal (skipped
  the prompt but still produced a value), or
- absent entirely (legacy path: an orchestrator that hasn't been
  updated to set the signal, or a programmatic invocation that bypassed
  §A.0.6 — kept for backwards compatibility).

Parse it once here, before the worktree gets created, so every later
section can short-circuit cleanly.

Recognized tokens (anything else is ignored with a warning):

| Token         | Section  | What it gates                                |
| ------------- | -------- | -------------------------------------------- |
| `review`      | §A.5     | Code Reviewer dispatch                       |
| `qa`          | §A.5     | QA agent dispatch + walkthrough hard-rule    |
| `security`    | §A.4     | Security audit pass                          |
| `polish`      | §A.4.5   | Polish & gap pass                            |
| `walkthrough` | §A.5a    | UI capture script                            |

#### Resolution rules

1. **Line absent.** No `SUPABUILD_STEPS=` anywhere in the prompt body.
   Default = all five enabled. Preserves behavior for direct
   `/supabuild build` invocations and for orchestrators that do not
   set the signal.
2. **Line present, value non-empty.** Parse as the canonical step set.
   Anything not in the table is dropped with a one-line warning.
3. **Line present, value empty (`SUPABUILD_STEPS=`).** All five
   disabled. The orchestrator has explicitly opted out of every gate.
   Print this banner before §A.1:
   > ⚠️  All verification gates disabled (`SUPABUILD_STEPS=`).
   > Shipping after implementation rounds with only the Team Lead's
   > integration check between rounds. No security audit, no polish
   > pass, no QA, no code review, no walkthrough.

Distinguishing rule 1 from rule 3 matters: a missing line is
backwards-compatible default-on; an empty value is an explicit
opt-out. Detect the difference by literal substring match on
`SUPABUILD_STEPS=` in the prompt body.

#### Helper for downstream sections

```bash
sb_step_enabled() {  # usage: sb_step_enabled review
  case ",${SUPABUILD_STEPS-review,qa,security,polish,walkthrough}," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}
```

Note the `${SUPABUILD_STEPS-...}` form (single dash, not `:-`): the
default applies only when the variable is **unset**, not when it's set
to an empty string. That is what carries rule 1 vs. rule 3 through to
every call site.

#### Plan implications

§A.2's plan template still lists every non-negotiable acceptance
criterion. When a gate is skipped, log the skip in `### Round log` at
the moment the section would normally execute, with the form:

```
**A.4 security: SKIPPED via SUPABUILD_STEPS**
**A.4.5 polish:   SKIPPED via SUPABUILD_STEPS**
**A.5 QA+review: SKIPPED via SUPABUILD_STEPS**  (or partial: e.g. "review only")
```

Reviewers reading the plan on the ticket / PR see exactly which
verifications ran and which the orchestrator opted out of. Do NOT
remove the AC entries themselves from the plan — the user may still
want to verify those criteria by hand on a no-gate run.

#### Skip the parse when

- The prompt body contains no `SUPABUILD_STEPS=` line at all (default
  to all-on without comment — silent fallback for direct invocation).

Apply the parse otherwise. Run it once at the top of §A; do not
re-parse per round.

### A.1. Create the isolated worktree

Use the §D worktree-creation logic — same preflight, same path
conventions — but run it inline here so the Team Lead retains control
of the session. (See §D for the full mental model and recovery
commands; §A.1 below is the build-flavored specialization.)

Compute:
- `$REPO_ROOT` — `git rev-parse --show-toplevel` (or, if inside a linked
  worktree, `dirname $(git rev-parse --git-common-dir)`).
- `$REPO_NAME` — basename of `$REPO_ROOT`.
- `$SLUG` — 2–4 kebab-case words from the task (`^[a-z0-9][a-z0-9-]{0,39}$`).
- `$TS` — `date +%Y%m%d-%H%M%S`.
- `$BRANCH` — user-supplied `--working-branch <name>` if present
  (used verbatim, no prefix added); otherwise `supabuild/$SLUG-$TS`.
- `$WT_PATH` — `$(dirname $REPO_ROOT)/$REPO_NAME.supabuild-$SLUG-$TS`
  (the worktree path keeps the `supabuild-` prefix even when
  `--working-branch` overrides `$BRANCH`, so cleanup heuristics still
  match).
- `$BASE_BRANCH` — current branch, or `main`/`master` if detached.
- `$BASE_SHA` — `git rev-parse HEAD`.
- `$TARGET_BRANCH` — user-supplied target branch, or empty.

Preflight:
1. `git rev-parse --is-inside-work-tree` → must be `true`.
2. `git status --porcelain` — if non-empty, surface it and ask the user to
   confirm before proceeding (uncommitted changes stay in the main tree).
3. Branch / path collision: if `$BRANCH` or `$WT_PATH` already exists,
   regenerate `$TS` once; abort if still colliding.
4. If `$TARGET_BRANCH` is set, verify it exists locally OR on `origin`
   (`git show-ref --verify --quiet refs/heads/$TARGET_BRANCH ||
   git ls-remote --exit-code --heads origin "$TARGET_BRANCH"`). If neither,
   ask the user whether to create it from `$BASE_BRANCH` or abort.
5. **`gh` setup walkthrough (push-only).** If `$TARGET_BRANCH` is set,
   the build will end in a `gh pr create` — gate on `gh` install + auth
   **before** starting a multi-round build, so the user isn't told to
   `gh auth login` after 20 minutes of work. If `$TARGET_BRANCH` is
   empty, skip this step (the build stays local; `gh` is irrelevant).

   Run the same detection + walkthrough as §C.1 step 1 parts d–h,
   scoped to `gh-install` and `gh-auth` only:
   ```bash
   GH_GAPS=()
   if command -v gh >/dev/null 2>&1; then
     gh auth status >/dev/null 2>&1 || GH_GAPS+=("gh-auth")
   else
     GH_GAPS+=("gh-install")
   fi
   ```
   If `GH_GAPS` is empty, continue. Otherwise:
   - Auto-install when possible (`brew install gh` on macOS with
     Homebrew; otherwise print the install snippet from
     `https://cli.github.com/manual/installation` and stop).
   - For `gh-auth`, print: "Run `gh auth login` in your terminal
     (pick GitHub.com → HTTPS → authenticate via browser), then
     re-run `/supabuild`." Stop the skill — never assume
     browser auth completed.

Create:
```
git worktree add -b "$BRANCH" "$WT_PATH" "$BASE_SHA"
```

Print `$WT_PATH`, `$BRANCH`, `$BASE_SHA`, `$TARGET_BRANCH` (or "none") so
the user can audit. From now on, **all** Read/Edit/Write use absolute paths
under `$WT_PATH/…`, and every Bash call needing the worktree as cwd
prefixes `cd "$WT_PATH" && …` in the same call.

**Persist upstream-ticket context (if any).** If the prompt body
declares an upstream ticket via the `SUPABUILD_TICKET=<kind>:<id>`
line (set by §C.3a for linear or §E.3c for github), write the values
to `$WT_PATH/.supabuild/ticket.env` so the §A.2.5b mirror helper
can find them across the many separate Bash invocations that make
up a build (each invocation is a fresh shell — env vars set in one
call don't survive into the next, hence the file).

```bash
mkdir -p "$WT_PATH/.supabuild"
# Parse the SUPABUILD_TICKET line out of the prompt body. Two
# accepted shapes:
#   SUPABUILD_TICKET=linear:ENG-123
#   SUPABUILD_TICKET=github:42:owner/repo
case "$SUPABUILD_TICKET" in
  linear:*)
    {
      echo "SUPABUILD_TICKET_KIND=linear"
      echo "SUPABUILD_TICKET_ID=${SUPABUILD_TICKET#linear:}"
    } > "$WT_PATH/.supabuild/ticket.env"
    ;;
  github:*)
    rest=${SUPABUILD_TICKET#github:}
    {
      echo "SUPABUILD_TICKET_KIND=github"
      echo "SUPABUILD_TICKET_ID=${rest%%:*}"
      echo "SUPABUILD_TICKET_REPO=${rest#*:}"
    } > "$WT_PATH/.supabuild/ticket.env"
    ;;
  ""|*)  : ;;  # standalone build — no ticket
esac
```

Skip silently when `$SUPABUILD_TICKET` is unset or malformed —
standalone runs have no upstream ticket and the helper's `none`
branch handles that correctly.

### A.1.5 Per-worktree database branch (ORM-agnostic, auto-detected)

Parallel worktrees that all hit the same dev database trample each
other's data. This step gives each worktree its own logical database
on the project's existing dev DB server, so the build can migrate,
seed, and exercise data without touching anyone else's state.

**This step is best-effort.** At every check below, on miss/failure,
log the reason in the plan announcement and continue without a
per-worktree DB. Do not block the build.

#### Detect

1. **Compose file.** `$REPO_ROOT/docker-compose.yml`, `compose.yml`, or
   `docker-compose.yaml`. None present → skip §A.1.5 entirely.
2. **DB service.** `docker compose -f $COMPOSE_FILE config --format json`
   and pick the first service whose `image` matches one of:
   `postgres`, `postgis/postgis`, `mysql`, `mariadb`, `mongo`. Multiple
   matches → ask the user once which to use. Zero → skip §A.1.5.
3. **Connection details.** Prefer parsing the parent `DATABASE_URL`
   from `$REPO_ROOT/.env` (then `.env.local`, then `.env.example`) —
   it's the authoritative source of how the project actually connects.
   Fall back to the service's `environment:` block in compose
   (`POSTGRES_USER/PASSWORD/DB`, `MYSQL_USER/PASSWORD/DATABASE`,
   `MONGO_INITDB_*`) and the `ports:` mapping for the host port.
   Capture: scheme, user, password, host, port, parent dbname.

#### Create the branch DB

1. Bring the service up from the repo root (idempotent):
   ```
   cd "$REPO_ROOT" && docker compose up -d <db-service>
   ```
2. Wait until ready, polling the right liveness probe for the image:
   - Postgres: `docker compose exec -T <svc> pg_isready -U $USER`
   - MySQL/MariaDB: `docker compose exec -T <svc> mysqladmin ping -u root -p$ROOT_PASS`
   - Mongo: `docker compose exec -T <svc> mongosh --quiet --eval "db.runCommand({ping:1}).ok"`
3. Generate `DB_BRANCH`:
   ```
   DB_BRANCH="${PARENT_DB}_$(echo "${SLUG}_${TS}" | tr '-' '_' | tr 'A-Z' 'a-z' | cut -c1-50)"
   ```
   Total length must stay ≤63 chars (Postgres identifier limit). Trim
   `PARENT_DB` first if needed.
4. Create the branch DB via `docker compose exec` (no host clients
   required):
   - **Postgres:**
     ```
     docker compose exec -T <svc> psql -U "$USER" -d postgres \
       -c "CREATE DATABASE \"$DB_BRANCH\" OWNER \"$USER\";"
     ```
   - **MySQL / MariaDB:**
     ```
     docker compose exec -T <svc> mysql -uroot -p"$ROOT_PASS" \
       -e "CREATE DATABASE \`$DB_BRANCH\`; \
           GRANT ALL ON \`$DB_BRANCH\`.* TO '$USER'@'%';"
     ```
   - **Mongo:** no-op — Mongo creates databases implicitly on first
     write. Just compose the new URL.
5. Compose the new `DATABASE_URL` by replacing the parent dbname
   in the parsed parent URL with `$DB_BRANCH`. Write it (and any
   related vars like `DIRECT_URL`, `SHADOW_DATABASE_URL` if the parent
   `.env` defined them — apply the same dbname swap) to:
   ```
   $WT_PATH/.env
   ```
   Compose's auto-load + the agents inheriting cwd make this picked up
   automatically by every command run inside the worktree.

#### Bootstrap (best-effort, ORM-agnostic)

Run from `$WT_PATH` so the new `DATABASE_URL` is in scope. Try in this
order; **first match runs, the rest are skipped**:

1. **`package.json` scripts** — try `db:setup`, then `db:migrate`,
   then `migrate`, then `db:reset` (whichever exists in `scripts`).
   Run via the project's package manager (`pnpm`/`yarn`/`npm` —
   detect by lockfile).
2. **`Makefile` targets** — `make db-setup`, `make migrate`, `make db-reset`.
3. **Python**:
   - `alembic upgrade head` if `alembic.ini` exists.
   - `python manage.py migrate` if `manage.py` exists (Django).
4. **Ruby** — `bin/rails db:setup` if `bin/rails` exists.
5. **Go** — `go run ./cmd/migrate` if that path exists.
6. **None matched** → log "no bootstrap script detected; agents will
   handle schema" and continue.

After migrations, attempt a seed step (same first-match logic):
`db:seed` / `seed` (package.json), `make seed`, `python manage.py loaddata` (if a fixture is committed), `bin/rails db:seed`. No match → skip silently.

If a bootstrap step fails, capture the error, surface it in the plan
announcement under "DB bootstrap failed: <why>", and continue. The
agents can still operate against an empty branch DB.

#### Tell the agents

Append this line to every agent dispatch prompt in §A.3:

> A per-worktree database has been provisioned. The connection string
> is in `$WT_PATH/.env` as `DATABASE_URL`. Use it for any DB work in
> this build. Do not connect to the parent dev database. If you change
> schema, generate a new migration in the project's normal way (e.g.
> `prisma migrate dev`, `alembic revision --autogenerate`,
> `bin/rails generate migration`) — do NOT hand-edit migration files.

#### Print before §A.2

Add to the plan announcement:
```
**Per-worktree DB:** $DB_BRANCH on <db-service> (skipped: <reason> | bootstrapped: <step> | empty)
```

### A.2. Team Lead's plan (internal, then announced)

The plan is the contract for everything downstream. A vague plan
produces a vague diff. Before dispatching anyone, the Team Lead
produces a **fully thought-out, explicit, falsifiable** plan grounded
in §A.0.5 discovery answers and what you read in the codebase.

Build the plan in this order:

1. **Goal & success criteria.** One sentence on what's being built,
   then 3–7 *falsifiable* acceptance criteria — observable behaviors
   a tester could check ("user can submit form X with email Y and
   sees confirmation Z within 2s"), not vibes ("works well").
2. **Out of scope.** Explicit list of things this build will NOT do.
   This is the most-skipped section and the one that prevents drive-by
   refactors and scope creep. If you can't name 2–3 things you're
   deliberately not doing, you haven't bounded the work.
3. **Domains touched.** Frontend / backend / infra / data / auth /
   payments / design system / etc. Used to size the team in step 7.
4. **Architecture sketch.** A short outline naming the *new* and
   *changed* artifacts:
   - Files to create (path → purpose, one line each).
   - Files to modify (path → what changes).
   - Database changes (new tables/columns/indexes/constraints,
     migrations needed yes/no).
   - New routes / endpoints / events / jobs / cron / queues.
   - New env vars / config / secrets.
   - External services touched (with auth model + sandbox vs prod).
   No code yet — this is the map. If you can't draw it, you don't
   understand the task; loop back to §A.0.5.
5. **Risks & unknowns.** 2–5 bullets naming the ways this could go
   sideways (perf hot path, race condition, migration on a hot
   table, breaking change, third-party flakiness) and the mitigation
   for each. "No known risks" is almost always wrong; push harder.
6. **Verification plan.** How §A.5 (QA gate) will *prove* each
   acceptance criterion. Map each criterion → the artifact that
   proves it (unit test, integration test, screenshot, transcript,
   manual smoke). The QA agent reads this map; missing entries =
   missing proof = blocked ship.
7. **Roster & orders.** Pick **2–10** specialist subagents from the
   environment's `subagent_type` list. Selection rules:
   - Domain fit over prestige. UI → UI/UX agents. Backend → backend
     architect / database / API. Mobile → mobile builder. Etc.
   - Always include at least one builder per major domain in scope.
   - Always include a **`Security Engineer`** (or closest security
     agent) for the §A.4 security pass.
   - Always include a **`Code Reviewer`** AND a QA-style agent
     (`Reality Checker`, `Evidence Collector`, `Test Results Analyzer`,
     or `API Tester`) for the §A.5 gate.
   - If the build has any UI surface, include a **`UI Designer`** or
     **`UX Architect`** to enforce the clean/minimalist bar.
   - Prefer specialists over `general-purpose`. Each agent gets a
     **scoped order** (1–2 sentences) tied to the artifacts in step 4
     — never "make it work", always "create `X` that does `Y`,
     wired into `Z`".
8. **Sequencing.** Identify what must run *before* what (data layer
   before UI, auth before authed endpoints, etc.) and which agents
   can run in parallel. The §A.3 build round uses this directly.
9. **Non-negotiables.** Latest stable framework versions, project
   conventions reused (don't reinvent existing helpers — name the
   ones you'll lean on), no dead code / TODOs / commented-out code,
   secrets via env, validation at boundaries, accessibility AA where
   UI exists.

Announce the plan to the user before dispatching — full, not
abridged. The user's confirmation here is implicit (the skill is
high-velocity), but this is their last chance to redirect, so make it
legible:

```
## Team Lead's plan

**Goal:** <one line>
**Success criteria (falsifiable):**
1. <criterion>
2. <criterion>
…

**Out of scope:**
- <thing not being done>
- <thing not being done>

**Worktree:** $WT_PATH on $BRANCH (base: $BASE_BRANCH @ $BASE_SHA)
**Target branch:** $TARGET_BRANCH (or "none — leaving worktree for review")
**Per-worktree DB:** <from §A.1.5>

## Architecture sketch
**New files**
- `path/to/file` — <one-line purpose>

**Modified files**
- `path/to/file` — <what changes>

**Data**
- <migration / schema change / "no DB changes">

**Surfaces**
- Routes: <list> · Jobs: <list> · Events: <list> · Env: <list>

**External services**
- <name> (auth: <model>, env: <sandbox|prod>)

## Risks & mitigations
- <risk> → <mitigation>
- <risk> → <mitigation>

## Verification map
| # | Criterion | Proof artifact |
|---|-----------|----------------|
| 1 | <crit>    | <test / shot / transcript> |

## Assembled team & orders
- **<agent>** — <scoped order tied to specific files/artifacts>
- **<agent>** — <scoped order tied to specific files/artifacts>

## Sequencing
1. <agent(s) running first> — <why first>
2. <agent(s) next, in parallel> — <why parallel>
…

## Non-negotiables
- Latest stable versions of <X, Y>
- Reuse existing helpers: <names>
- Clean, minimalist UI / accessible (where applicable)
- Security audited (§A.4)
- QA gate (§A.5) verifies every success criterion above before ship
```

If any section above would be empty or hand-wavy ("TBD", "as
needed"), STOP and either re-derive it from the codebase or add the
missing question to a §A.0.5 follow-up batch. Do not dispatch on a
plan with holes — those holes become bugs.

### A.2.5 Plan artifact (write to disk + mirror to ticket/PR)

The plan announced in §A.2 is also persisted as a **live artifact**
that survives the chat session, gets ticked off as work progresses,
and — when running under §C (linear) or §E (github) — mirrors into
the ticket description so a human watching the ticket sees the
current state without opening the terminal.

The artifact has three sinks; **plan.md is always written**, the
others activate when their context is present:

1. **`$WT_PATH/.supabuild/plan.md`** — always. Source of truth on
   disk. Survives an aborted run; a resumed run can re-read it.
2. **Ticket description** — when invoked by §C or §E (i.e. when the
   env signals `SUPABUILD_TICKET_KIND` and `SUPABUILD_TICKET_ID` are
   set in the build prompt body), splice plan.md between markers in
   the Linear/GitHub issue description.
3. **PR description** — once a PR exists in §A.6a, splice the same
   block into the PR body alongside `## Walkthrough`. Reviewers see
   goal/AC/risks at the top of the PR.

> **Do NOT commit `plan.md`** — same rule as `.supabuild/evidence/`
> in §A.5.5. The persistent copy lives on the ticket and the PR;
> committing the worktree's copy would drag in-flight QA artifacts
> through `git log` forever.

#### A.2.5a Template (use exactly this skeleton)

Marker fences are HTML comments — invisible in rendered Markdown,
load-bearing for the splice helper. Do not change them.

```markdown
<!-- supabuild:plan:start -->
## 🤖 Supabuild plan
**Status:** $STATUS · branch `$BRANCH` · target `${TARGET_BRANCH:-none}`
**Worktree:** `$WT_PATH`
**Updated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

### Goal
<one line from §A.2.1>

### Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>
…

### Out of scope
- <bullet from §A.2.2>

### Architecture
**New files**
- `path` — purpose

**Modified files**
- `path` — what changes

**Data**
- <migration / schema change / "no DB changes">

**Surfaces**
- Routes: <list> · Jobs: <list> · Events: <list> · Env: <list>

### Risks & mitigations
- <risk> → <mitigation>

### Verification map
| # | Criterion | Proof |
|---|-----------|-------|
| 1 | <crit> | <test / shot / transcript> |

### Rollback
- <feature flag / migration reverse / kill switch / "revert PR is safe">

### Round log
- (filled in as rounds run; see A.2.5c)
<!-- supabuild:plan:end -->
```

`$STATUS` values, in order through the run:
`planning` → `round 1/3` → `round 2/3` → `qa-gate` → `approved` →
`shipped` (or `escalated` / `failed` on terminal failure paths).

#### A.2.5b Helpers (define once at the top of the build, reuse below)

The helpers are POSIX-shell, ORM-agnostic, and depend only on `jq`,
`awk`, and the relevant CLI (`linear` or `gh`). Define them at the
start of §A.3, before the first round dispatch:

```bash
# Always-on: write plan.md to disk.
sb_plan_write() {
  mkdir -p "$WT_PATH/.supabuild"
  printf '%s\n' "$1" > "$WT_PATH/.supabuild/plan.md"
}

# Idempotent splice: replace the fenced block in $1 with $2, or
# append it (separated by `---`) if no fence exists. Preserves
# everything outside the fences exactly.
sb_plan_splice() {
  local existing="$1" plan="$2"
  local fenced
  fenced=$(printf '<!-- supabuild:plan:start -->\n%s\n<!-- supabuild:plan:end -->' "$plan")
  if printf '%s' "$existing" | grep -q '<!-- supabuild:plan:start -->'; then
    printf '%s' "$existing" | awk -v new="$fenced" '
      BEGIN { skip=0 }
      /<!-- supabuild:plan:start -->/ { print new; skip=1; next }
      /<!-- supabuild:plan:end -->/ { skip=0; next }
      !skip { print }
    '
  elif [ -n "$existing" ]; then
    printf '%s\n\n---\n\n%s\n' "$existing" "$fenced"
  else
    printf '%s\n' "$fenced"
  fi
}

# Mirror plan.md into the upstream ticket description (no-op when no
# orchestrator wrote the ticket-context file). Best-effort: failures
# log and continue — never block the build on a description edit.
#
# Reads $WT_PATH/.supabuild/ticket.env if present. Format:
#   SUPABUILD_TICKET_KIND=linear|github
#   SUPABUILD_TICKET_ID=<id-or-number>
#   SUPABUILD_TICKET_REPO=<owner/repo>   # github only
# The file is written once by the orchestrator (§C.3a-pre / §E.3a-pre)
# right after the worktree is created. Sourcing it inside the helper
# keeps the env alive across the many separate Bash tool invocations
# that make up a build (each invocation is a fresh shell).
sb_plan_mirror_ticket() {
  local plan; plan=$(cat "$WT_PATH/.supabuild/plan.md" 2>/dev/null) || return 0
  [ -z "$plan" ] && return 0
  [ -f "$WT_PATH/.supabuild/ticket.env" ] && \
    . "$WT_PATH/.supabuild/ticket.env"
  case "${SUPABUILD_TICKET_KIND:-}" in
    linear)
      local cur; cur=$(linear issue view "$SUPABUILD_TICKET_ID" --json 2>/dev/null \
        | jq -r '.description // ""')
      sb_plan_splice "$cur" "$plan" > "/tmp/sb-plan-mirror-$$.md"
      linear issue update "$SUPABUILD_TICKET_ID" \
        --description-file "/tmp/sb-plan-mirror-$$.md" \
        || echo "warn: plan mirror to Linear $SUPABUILD_TICKET_ID failed (continuing)"
      rm -f "/tmp/sb-plan-mirror-$$.md"
      ;;
    github)
      local cur; cur=$(gh issue view "$SUPABUILD_TICKET_ID" \
        --repo "$SUPABUILD_TICKET_REPO" --json body -q '.body // ""' 2>/dev/null)
      sb_plan_splice "$cur" "$plan" > "/tmp/sb-plan-mirror-$$.md"
      gh issue edit "$SUPABUILD_TICKET_ID" --repo "$SUPABUILD_TICKET_REPO" \
        --body-file "/tmp/sb-plan-mirror-$$.md" \
        || echo "warn: plan mirror to GitHub #$SUPABUILD_TICKET_ID failed (continuing)"
      rm -f "/tmp/sb-plan-mirror-$$.md"
      ;;
    ""|none) : ;;  # standalone build — disk only
  esac
}

# Combined: write + mirror. Call after every plan mutation.
sb_plan_update() { sb_plan_write "$1"; sb_plan_mirror_ticket; }
```

The orchestrator modes (§C, §E) write `$WT_PATH/.supabuild/ticket.env`
once at worktree-creation time with `SUPABUILD_TICKET_KIND`,
`SUPABUILD_TICKET_ID`, and (for github) `SUPABUILD_TICKET_REPO`.
Standalone `/supabuild build` runs don't write the file → the `none`
branch fires → plan.md still lands on disk.

Example file the orchestrator writes:
```
SUPABUILD_TICKET_KIND=linear
SUPABUILD_TICKET_ID=ENG-123
```

#### A.2.5c When to update

| Step | Action | New `$STATUS` |
|---|---|---|
| §A.2 done (before §A.3 dispatch) | First write — full template populated from §A.2 | `planning` → `round 1/N` |
| §A.3 round complete | Append round log entry; tick AC the round demonstrably proved | `round k/N` |
| §A.4 findings | Update **Risks & mitigations** with security findings + status | (unchanged) |
| §A.4.5 polish list | Append polish-pass summary to round log | (unchanged) |
| §A.5 verdict APPROVED | Tick remaining AC; status flips | `approved` |
| §A.5 verdict NEEDS ANOTHER ROUND | Append remediation list as next round entry | `round k+1/N` |
| §A.6a PR opened | Append `**PR:** <url>` line; status flips | `shipped` |
| §A.6 ESCALATED / FAILED | Capture blocker in round log; status flips | `escalated` / `failed` |

Round log entry format (one bullet per agent per round):
```markdown
- **R$N $agent** — <one-line outcome> (<commits>)
```

Call `sb_plan_update "$NEW_PLAN"` once after each transition. The
helper is cheap (one `awk` + one CLI call), and a missed mirror just
means the ticket lags by a phase — never a build blocker.

### A.3. Build round (parallel where possible)

**Before dispatching round 1**, define the §A.2.5b helpers in the
shell context and write the initial plan to disk + ticket:

```bash
# (helpers from §A.2.5b — sb_plan_write, sb_plan_splice,
# sb_plan_mirror_ticket, sb_plan_update — defined here, used below)

PLAN_BODY=$(cat <<'EOF'
<!-- supabuild:plan:start -->
… (the §A.2.5a template, populated from the §A.2 announcement) …
<!-- supabuild:plan:end -->
EOF
)
sb_plan_update "$PLAN_BODY"
```

#### A.3.1 Prompt skeleton (cache-friendly, mandatory order)

Subagent prompts MUST follow this exact ordering. The first four
blocks are **identical across every parallel agent in a round** —
keeping them at the front lets the Anthropic prompt cache hit on
the prefix and skip re-billing for blocks 1–4 on every agent past
the first. Per-agent variability lives only in the suffix.

```
[1 — IMMUTABLE PREFIX, identical across all agents in the round]
  ## Plan
  <verbatim §A.2 plan body — paste the same string in every dispatch>

  ## Non-negotiables
  - Latest stable versions of the chosen stack
  - Reuse existing helpers; never reinvent
  - No secrets in code; env-var boundaries
  - No dead code, TODOs, or commented-out blocks
  - Accessibility AA where UI exists
  - All file writes under $WT_PATH using absolute paths
  - Commit your work with a conventional, descriptive message

  ## Workspace
  $WT_PATH (worktree root)
  $BASE_SHA (base commit; use `git diff $BASE_SHA..HEAD` for the diff)

  ## Repo conventions
  <2–6 bullets the Team Lead extracted from CLAUDE.md/AGENTS.md/
   recent commits — same string for every agent>

[2 — VARIABLE SUFFIX, per-agent]
  ## Your scope
  <one sentence: what to build, which files, which to avoid>

  ## Report back
  - Files touched
  - Key decisions
  - Open questions
  - Anything punted
```

The Team Lead constructs the prefix string ONCE per round and reuses
it byte-for-byte across every parallel `Agent` dispatch. Do not
interpolate per-agent details into blocks 1–4 — they are static.

#### A.3.2 Round-2+ delta dispatch (NEEDS-ANOTHER-ROUND remediation)

When §A.5 returns NEEDS ANOTHER ROUND, **do NOT re-paste the full
prefix** to remediation dispatches. Round 1 wrote `plan.md` and
non-negotiables to disk; round 2+ agents Read them on demand.

Default remediation path: dispatch a **single Remediator** (use
`engineering-senior-developer`, or the original agent if the
remediation is narrowly tied to that agent's diff). The dispatch
prompt is just:

```
## Remediation (round $N)
Worktree: $WT_PATH
Base diff: git diff $BASE_SHA..HEAD
Plan: read $WT_PATH/.supabuild/plan.md if you need full context.

## Issues to fix
<verbatim remediation list from §A.5 verdict>

## Report back
- Files touched, commit SHAs.
```

Re-dispatch the **full multi-agent roster** only when the remediation
list spans 3+ distinct domains (e.g. "fix auth + fix migration +
fix UI a11y all"). For 2-domain remediation, dispatch only the
relevant 2 specialists; for 1-domain remediation, dispatch one
specialist or the Remediator.

This rule cuts ~60–80% of round-2+ token cost vs. re-firing the
full team with a re-pasted plan + non-negotiables.

#### A.3.3 Dispatch + integration

Run independent agents **in parallel in a single message**. Run
dependent agents sequentially (e.g., backend API before the frontend
that consumes it, unless contracts are stubbed first).

After the round, the Team Lead reads every agent's report and
inspects the worktree (`git log`, `git diff`, targeted `Read`s) and
writes a short **integration check**: do the pieces fit? Any
contradictions? Any gaps?

If integration is broken, the Team Lead either fixes it inline
(small) or dispatches a follow-up agent (large) before proceeding.

**Plan update — round complete.** Append a `**R$N $agent**` bullet
under `### Round log` for each agent that ran, tick any AC the round
demonstrably proved (with the proof artifact noted in the
verification map), and bump `**Status:**` to `round $((N+1))/3` if
another round is expected. Then call `sb_plan_update "$PLAN_BODY"`.

### A.4. Security audit pass

**Skip-gate.** If `sb_step_enabled security` returns false, skip this
section entirely. Append `**A.4 security: SKIPPED via
SUPABUILD_STEPS**` under `### Round log`, call `sb_plan_update
"$PLAN_BODY"`, and proceed to §A.4.5. The orchestrator (or
`/supabuild build --steps "..."` if surfaced for direct use later)
has explicitly opted out — don't second-guess it.

Dispatch the Security agent (and `Blockchain Security Auditor` /
`Compliance Auditor` if relevant) with this scope:

- Audit **only** the code changed in `$WT_PATH` since `$BASE_SHA`
  (`git diff $BASE_SHA..HEAD`).
- Look for: injection, XSS, SQLi, SSRF, auth/authz flaws, insecure
  deserialization, secrets in code or config, weak crypto, dependency
  vulnerabilities (check against the latest known CVEs the agent is
  aware of), unsafe defaults, missing input validation, missing rate
  limits on sensitive endpoints, PII handling.
- Return a list of findings with severity (Critical / High / Medium /
  Low / Info) and a fix recommendation per finding.

If there are **any** Critical or High findings, the Team Lead MUST dispatch a
fix round (back to §A.3 with a narrower scope) before continuing. Mediums
are judgment calls; the Team Lead decides. Lows/Info are noted in the final
report but do not block.

**Plan update — security findings.** Add each Critical/High/Medium
finding to `### Risks & mitigations` as `<finding> → <fix or status>`.
Lows/Info don't need a plan entry. Call `sb_plan_update "$PLAN_BODY"`.

### A.4.5 Polish & gap pass — what is the user missing?

**Skip-gate.** If `sb_step_enabled polish` returns false, skip this
section. Append `**A.4.5 polish: SKIPPED via SUPABUILD_STEPS**`
under `### Round log`, call `sb_plan_update "$PLAN_BODY"`, and
proceed to §A.5. The §A.6 final report's "Polish pass" line should
read "skipped via SUPABUILD_STEPS" rather than the empty-list
acknowledgement.

Before the QA gate, the Team Lead runs an explicit "what did we miss"
pass. Users specify the obvious thing they want; the bar for shipping is
the obvious thing **plus** the surrounding details a thoughtful
collaborator would catch. The Team Lead is responsible for those
details, not the user.

Read the diff and the original task once more, then walk through this
checklist and write a **gap list** (file + concrete fix per item):

- **Edge cases.** Empty input, very large input, unicode/i18n, network
  failure, race conditions, repeated submissions, slow connection.
- **States.** Loading, empty, error, success, partial-success, offline,
  unauthenticated, no-permission. UI surfaces should handle all that
  apply, not just the happy path.
- **Errors.** Are failures user-actionable? No raw stack traces in the
  UI. Server errors logged with enough context to debug. Retries where
  retry is safe.
- **Accessibility (UI).** Keyboard navigation, focus order, visible
  focus ring, semantic HTML, alt text, color contrast, reduced-motion
  respected, screen-reader labels on icon-only buttons.
- **Responsive (UI).** Renders cleanly at narrow (mobile), medium
  (tablet), and wide (desktop) widths. No horizontal overflow. Touch
  targets ≥ 44×44.
- **Performance.** No obvious N+1 query, no synchronous work on the
  request path that should be async, no full-table scans on hot paths,
  bundle isn't bloated by an accidental whole-library import.
- **Observability.** New code paths log enough to debug a prod
  incident. Metrics on anything user-visible. No `console.log` left
  behind.
- **Config & secrets.** New env vars documented (README/`.env.example`).
  No secrets committed. Sensible defaults for local dev.
- **Docs.** README/CHANGELOG/inline doc updated where the public surface
  changed. Migration notes if behavior shifted.
- **Tests.** Coverage matches the project's existing bar — happy path
  + at least one failure mode for the new behavior.
- **Cleanup.** No dead code, no commented-out code, no TODOs, no debug
  prints, no scratch files committed.
- **Project-specific gotchas.** Anything in `CLAUDE.md`, `AGENTS.md`,
  `CONTRIBUTING.md`, or recent commit messages that this build should
  honor (commit conventions, lint rules, banned APIs, deprecation
  paths).

Then ask one harder question: **"If I were the user, what would I
*notice* and ask about in 24 hours?"** Write down 1–3 such items.

If the gap list is non-trivial, dispatch a **polish round** (back to §A.3
scoped to the gap list only — no scope creep) before §A.5. Small,
mechanical gaps the Team Lead can fix inline; anything domain-specific
(a11y, performance, error UX) goes to the matching specialist.

If the gap list is trivial or empty, record that fact in the §A.6 final
report under **"Polish pass"** and proceed. Do not skip this step
silently — even an empty list must be acknowledged.

### A.5. QA + code review gate

**Skip-gate (whole section).** If neither `qa` nor `review` is in
`SUPABUILD_STEPS` (i.e. `sb_step_enabled qa` AND `sb_step_enabled
review` both return false), skip §A.5 entirely:
- Append `**A.5 QA+review: SKIPPED via SUPABUILD_STEPS**` under
  `### Round log`.
- Render verdict APPROVED based on the Team Lead's own integration
  check from §A.3 (the same check the Team Lead runs after every
  round). If integration is broken, render NEEDS ANOTHER ROUND
  instead and loop back to §A.3 — the verdict still happens, just
  without external agents.
- §A.5a (capture script) and the UI walkthrough hard-gate below also
  no-op in this case (no QA → no QA-blocking precondition).
- Call `sb_plan_update "$PLAN_BODY"` with the round-log entry, flip
  status to `approved`, and proceed to §A.5.5 / §A.6.

If only one of `qa` / `review` is enabled, the section runs but
dispatches just that one agent — see Step 2 below.

**Step 1 — UI-diff detection (do this first, before dispatching anyone).**

```bash
UI_DIFF=$(cd "$WT_PATH" && git diff --name-only "$BASE_SHA"..HEAD \
  | grep -iE '\.(tsx|jsx|vue|svelte|astro|html|css|scss|sass|less|stylus)$|/(components|pages|app|views|routes|styles|public)/' \
  | head -1)
```

If `$UI_DIFF` is non-empty → this is UI work. **If `sb_step_enabled
walkthrough` returns true**, the Team Lead **must** execute the §A.5a
capture script *inline* (not delegate to QA) before or in parallel
with QA dispatch. Capture is mechanical, not judgment — the QA
agent's job is to render a verdict, not to run shell scripts.

If `walkthrough` is NOT enabled, skip §A.5a entirely even when
`$UI_DIFF` is non-empty. Append `**A.5a walkthrough: SKIPPED via
SUPABUILD_STEPS**` under `### Round log` for the audit trail. The
hard-gate in Step 3 below also no-ops in this case — the orchestrator
has explicitly traded visual proof for speed and the Team Lead must
not synthesize one.

> ## ⛔ The diff regex is the ONLY test for "is this UI work?"
>
> If `$UI_DIFF` is non-empty, capture is mandatory. You do NOT get to
> override this with a self-judged "no UI surface mutation" / "pure
> label gate" / "backend-driven label fix" / "no new component" /
> "covered by unit tests" rationale. **All of the following count as
> UI mutations and require a walkthrough:**
>
> - **Conditional-render gates.** Changing whether or when an existing
>   element appears (`{cond && <Pill/>}`, ternary class swaps,
>   `display: none` toggles, `visibility` flips). The pixels the user
>   sees change → it's a UI change. PIN-88 (newpintask, May 2026) is
>   the canonical failure: a one-line edit to a render condition
>   shipped without a walkthrough because the agent ruled "no UI
>   surface mutation"; reviewer had no visual proof the fix worked.
> - **Pill / badge / chip / banner / toast / status-label rendering
>   conditions.** Even if no JSX node was added, gating which one
>   renders or which copy/color is shown is a UI change.
> - **Variant gating** (loading vs. empty vs. error vs. success vs.
>   permission-denied state selection).
> - **Class-string changes** (color, size, layout, spacing,
>   visibility, focus, hover, disabled).
> - **Copy / label / icon swaps** in any rendered surface.
> - **Helper functions consumed by JSX** (e.g. `isMatchTerminallyExhausted`,
>   `getStatusColor`, `formatLabel`) — even if the helper itself
>   lives in a non-UI file, if its callers are in `.tsx`/JSX render
>   paths, the diff regex catches the callers and the rule applies.
>
> The ONLY waivers are:
> 1. The diff regex genuinely matched only non-render files (test
>    fixtures, `.d.ts` types, storybook stories with no production
>    callers, build/config touching `app/` paths).
> 2. The capture script *itself* failed (boot error, no E2E config,
>    auth wall the synthetic flow can't pass). In that case follow
>    §A.5a's "capture failed" path — surface the reason loudly, do
>    not silently skip.
>
> Phrases that have shipped past this gate before and must NOT — if
> you find yourself writing any of these in the §A.5/§A.6 report, STOP
> and run capture instead:
> - "_Walkthrough not captured: no UI surface mutation_"
> - "_Backend-driven label bug — pure logic change_"
> - "_The change is verified by unit tests; no walkthrough needed_"
> - "_No new component was added; visual capture N/A_"
>
> Unit tests verify *logic correctness*. Walkthroughs verify *what
> the user sees*. They are not substitutes. Both are required when
> `$UI_DIFF` matches.

**Step 2 — dispatch `Code Reviewer` and the chosen QA agent in parallel.**

Dispatch each only if its step is enabled:

- **Code Reviewer** (only when `sb_step_enabled review`). Scope: full
  diff `$BASE_SHA..HEAD`. Check correctness, maintainability,
  idiomatic use of the chosen stack, dead code, error handling at
  boundaries (don't add fallbacks for impossible states), comments
  only where the *why* is non-obvious, no over-engineering, no
  half-finished work.
- **QA agent** (only when `sb_step_enabled qa`). Scope: actually
  exercise the build where possible. Run the project's test suite,
  lint, typecheck if configured. For UI, follow the golden path and
  a few edge cases. Distinguish infra-skip (tooling missing) from
  genuine fail (code is wrong). Return concrete, evidence-backed
  findings — no fantasy approvals.

If only one of the two is enabled, dispatch that one alone (no
parallel — single tool call). Log the partial in the round log:
`**A.5 QA+review: review-only via SUPABUILD_STEPS**` (or
`qa-only`). The Team Lead's verdict at the bottom of §A.5 still
runs, but it weighs only the report(s) it actually got.

**Step 3 — APPROVED precondition (hard gate).**

This hard gate fires only when **`sb_step_enabled walkthrough` AND
`$UI_DIFF` is non-empty**. If `walkthrough` is disabled by
`SUPABUILD_STEPS`, the Team Lead may render APPROVED on UI diffs
without an evidence file — the orchestrator has explicitly traded
visual proof for speed, and the §A.6a `## Walkthrough` section just
records "skipped via SUPABUILD_STEPS" in place of the artifact list.

When the gate fires (`walkthrough` enabled AND `$UI_DIFF` non-empty):
the Team Lead **CANNOT** output APPROVED unless
`$WT_PATH/.supabuild/evidence/00-walkthrough.{webm,mp4}` exists on
disk and is ≥50KB. No exceptions, no waivers, no "I checked it
manually". If the file is missing or undersized:
- Re-run the §A.5a capture script inline once more with verbose logging.
- If still missing, the verdict is **NEEDS ANOTHER ROUND** with the
  specific remediation "fix capture: <error from script>". Hand the
  failure to the relevant specialist (Frontend Developer if the dev
  server won't boot; DevOps if Playwright config is broken; etc.).
- Three failed capture rounds → **ESCALATED** to the user. Do not
  silently ship UI work without a walkthrough.

This rule exists because past runs shipped UI changes claiming "QA
passed" with no actual visual proof, and the user couldn't tell
whether the build worked until they pulled and ran it themselves.

### A.5a. Capture script (Team Lead runs this inline when `$UI_DIFF` is non-empty)

**Skip-gate.** If `sb_step_enabled walkthrough` returns false, this
section is a no-op regardless of `$UI_DIFF`. §A.5 Step 1 already
logged the skip — do not run the script, do not produce the
artifact, and the §A.5 Step 3 hard gate will not fire.

When `$UI_DIFF` from §A.5 is non-empty AND `walkthrough` is enabled,
the **Team Lead executes capture inline** (do not delegate to the QA
agent — its dispatch prompt won't carry the script verbatim, and
past runs have silently skipped capture as a result). The artifact
at `$WT_PATH/.supabuild/evidence/00-walkthrough.{webm,mp4}` is a
hard APPROVED precondition per §A.5 step 3. This replaces the
post-APPROVED §C.3d.5 boot in the linear flow and the §A.5.5
still-only flow.

**Read `modes/build-walkthrough.md` now** — it carries the resolution
order, dev-server detection table, walkthrough-steps file convention,
shipped `scripts/capture.sh` invocation, optional test-bonus block,
and failure semantics. Splitting these out keeps build.md slim for
the ~70% of runs that have no UI diff (or `walkthrough` disabled),
where build-walkthrough.md is never loaded.

**Capture is `playwright-cli` against a live dev server.** Language-
agnostic by design — works for PHP/Laravel, Django, Rails, Go, Bun,
Node, anything that boots an HTTP server. The walkthrough proves
"the feature visibly works"; existing test suites are an *optional
bonus* run after the walkthrough and **do not gate APPROVED**.

**Quick reference** (full details in `modes/build-walkthrough.md`):
- Resolution order: `$WT_PATH/.supabuild/capture.sh` → `package.json`
  `supabuild.capture` → shipped `scripts/capture.sh`.
- Per-build steps go in `$WT_PATH/.supabuild/walkthrough-steps.sh`
  (sourced by capture.sh after `video-start`); generic
  scroll-and-screenshot tour runs if absent.
- Hard APPROVED gate: `$EVID/00-walkthrough.{webm,mp4}` ≥ 50KB.
- Capture failure on a UI-bearing diff → NEEDS ANOTHER ROUND
  (or ESCALATED on structural failures).

The Team Lead reads whichever reports actually ran (per Step 2's
per-step gating) and renders a verdict:

- **APPROVED** — every non-negotiable met. The required conditions
  scale with `SUPABUILD_STEPS`:
  - `security` enabled → no Critical/High security issues.
  - `review` enabled → code review is clean (or only nits the Team
    Lead is willing to ship).
  - `qa` enabled → QA passes.
  - `walkthrough` enabled AND `$UI_DIFF` non-empty → walkthrough
    artifact present and ≥50KB (Step 3 hard-gate).
  - Steps that are disabled by `SUPABUILD_STEPS` simply don't apply;
    the Team Lead notes the skip in the §A.6 final report and
    proceeds.
  Proceed to §A.6.
- **NEEDS ANOTHER ROUND** — the Team Lead writes a tight remediation list
  (specific files, specific issues, specific agents to dispatch) and
  loops back to §A.3 with that scope only. Do not rewrite the world; fix
  what was flagged.

Cap the loop at **3 rounds** by default. After the 3rd failed round, the
Team Lead stops and hands back to the user with: a status report, what's
blocking, and a recommendation (continue, change scope, or abandon).
Don't burn tokens grinding past a structural problem — escalate.

**Plan update — verdict.** On APPROVED: tick every remaining AC,
flip `**Status:**` to `approved`, and call `sb_plan_update`. On NEEDS
ANOTHER ROUND: append the remediation list as the next round entry
in `### Round log`, bump status to `round $((N+1))/3`, and call
`sb_plan_update` before looping back to §A.3. On the 3-round
escalation: flip status to `escalated`, capture the blocker in the
round log, call `sb_plan_update` once before handing back.

### A.5.5 Visual evidence (verify on disk — do NOT commit)

For UI work, the walkthrough video and stills already exist under
`$WT_PATH/.supabuild/evidence/` from §A.5a (captured during QA, not
after). **Evidence artifacts are NOT committed to the repo.** They
are uploaded to Linear / posted as a GitHub PR comment by the
orchestrator (e.g. §C.3d.5), so committing them would only bloat
the diff and pollute reviewers' `Files changed` view.

This section just verifies the artifacts are on disk and ready for
upload — no `git add`, no `git commit`.

- **UI work** — confirm `00-walkthrough.webm` (or `.mp4`, or the
  `0[1-3]-step.png` still set) exists under
  `$WT_PATH/.supabuild/evidence/`. Record the filenames in the §A.6
  final report so the orchestrator (or the user, in standalone mode)
  knows what to upload.
- **CLI / backend / infra** — capture a terminal transcript instead.
  Save it to `$WT_PATH/.supabuild/evidence/evidence-<step>.txt`.
  Same rule: do not commit; the orchestrator uploads or links it.
- **Pure refactor with no observable surface** — skip this section
  entirely and note "no visual surface" in the §A.6 final report.

If §A.5a flagged "capture failed" and the Team Lead chose to waive
(non-critical UI surface), record "evidence not captured: <reason>"
in the §A.6 report. Do not fabricate shots.

> **Why not commit?** Evidence is QA artifact, not source. It belongs
> on the ticket (Linear) or the PR conversation (GitHub PR comment),
> not in `git log`. Committing it forces every future clone, blame,
> bisect, and `git log -- <path>` to drag binary screenshots through
> history forever, and shows up under `Files changed` where it has
> no business being.

### A.6. Ship

The verdict is APPROVED. **Read `modes/build-ship.md` now** — it
carries:
- The final-report template (`/supabuild build — APPROVED` block).
- §A.6a — `$TARGET_BRANCH` set: rebase preflight + typed-`yes` gate
  + force-with-lease push + `gh pr create` + plan-mirror into PR
  body + worktree/branch auto-cleanup + per-worktree DB drop.
- §A.6b — no `$TARGET_BRANCH`: 6-option hand-back menu (keep / merge
  / rebase+push / discard / stash / adopt) following §D's typed-`yes`
  gates.

Splitting this out keeps build.md slim for runs that never reach
ship (NEEDS ANOTHER ROUND escalations, ESCALATED runs).

### A.7. Failure recovery (read-only reference)

If anything aborts mid-flight, the worktree persists with whatever
commits made it in. The user can resume with `cd $WT_PATH`. Useful:

```
git worktree list --porcelain
git -C "$WT_PATH" log --oneline "$BASE_SHA"..HEAD
git -C "$WT_PATH" status
git reflog --date=iso
```

Repair is the user's call; this skill does not auto-heal.

### A. Hard rules (build mode)

- The Team Lead never claims completion without the §A.5 QA + code
  review passing **when those gates are enabled in
  `SUPABUILD_STEPS`**. "I think it works" is not approval. When the
  orchestrator has explicitly disabled `qa` and/or `review`, the
  round log MUST name the skipped gates and the §A.6 final report
  MUST mark the corresponding sections as "skipped via
  SUPABUILD_STEPS" so the user can see exactly what didn't run. The
  Team Lead never silently skips — only conditionally skips.
- Loop cap is 3 rounds. After that, escalate to the user.
- All file writes go under `$WT_PATH`. Never edit the main working tree
  during a build run.
- Never `--no-verify`, never bypass signing, never skip hooks unless the
  user explicitly asks.
- Push only after the typed-`yes` gate. PRs only after the push succeeds.
- After a successful push + PR open in §A.6a, **always remove the worktree
  and the local branch** (the work is now on origin). Only keep them
  when ESCALATED/FAILED, or when `worktree remove` fails — in which
  case prompt the user instead of silently leaving artifacts.

