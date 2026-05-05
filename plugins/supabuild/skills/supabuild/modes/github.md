## §E — `github`

GitHub-Projects-v2 mirror of §C. For every issue in `Todo` status on
the repo's supabuild project, run the §A build flow against that
issue's body and ship a separate PR per issue. Same one-PR-per-issue
guarantee, same design fork, **user-selectable gates** (QA, code
review, security audit, polish pass, walkthrough capture — each
checkbox-toggled per run, see §E.0.6) — only the queue backend
differs.

If you already use Linear, prefer §C — Linear's API and workflow
states are richer. §E is for teams that want the supabuild
experience without onboarding to Linear, by using a GitHub Projects
v2 board they likely already have or can have created automatically
on first run.

### E.0. Inputs

`/supabuild github [task description] [flags]`.

**Positional arg (optional).** A free-form task description **creates
a new issue in the project's Todo column first**, then proceeds with
normal queue processing. The new issue is included in this run's
queue. Use:

```bash
ISSUE_URL=$(gh issue create \
  --repo "$REPO_FULL" \
  --title "<first line of description, ≤80 chars>" \
  --body-file /tmp/sgh-new-$$.md)
ISSUE_NUM="${ISSUE_URL##*/}"
gh project item-add "$PROJECT_NUM" --owner "$OWNER" --url "$ISSUE_URL"
ITEM_ID=$(gh project item-list "$PROJECT_NUM" --owner "$OWNER" --format json \
  | jq -r ".items[] | select(.content.url==\"$ISSUE_URL\") | .id")
gh project item-edit \
  --project-id "$PROJECT_ID" \
  --id "$ITEM_ID" \
  --field-id "$STATUS_FIELD_ID" \
  --single-select-option-id "$TODO_OPT_ID"
```

The remainder of the description goes in `--body-file`. Echo the
new issue's `#<num>` and URL before continuing.

Optional flags:
- `--repo <owner/repo>` — explicit repo. Default: detected from
  `gh repo view`.
- `--project <num>` — explicit project number. Default: auto-detect
  via `git config supabuild.githubProject`, falling back to a
  title match against the repo name. On first run in a repo, the
  user is prompted to confirm or rename (default = repo name); the
  resulting project number is stored in `git config` so the chosen
  name is irrelevant on subsequent runs.
- `--assignee <login>` — filter to one assignee. Default: any.
- `--limit <n>` — cap how many issues to process this run. Default: 10.
- `--target <branch>` — base branch for PRs. Default: `main`.
- `--parallel <n>` — process N issues concurrently **in this same
  Claude session**. **Default: 1 (sequential).** Pass an explicit
  number to parallelize. Warn if effective concurrency exceeds 5
  (shared `gh` rate limits) but do not cap. Mutually exclusive
  with `--tabs`.
- `--tabs` — for each issue in the queue, spawn a **new terminal
  tab/window running its own headless `claude -p` session** that
  processes exactly one issue via `--only-issue`. The parent does
  the queue fetch + spawn loop and exits; each child owns its own
  context, worktree, and GitHub narration. Auto-detects the
  terminal (cmux → iTerm2 → Terminal.app → tmux → background
  fallback). Override with
  `SUPABUILD_SPAWN_TARGET=cmux|iterm2|terminal|tmux|background`.
  Warn if queue size > 5 (N concurrent Claude sessions = N× spend,
  possible 429s, possible merge conflicts on overlapping issues)
  but do not cap. See §E.4-tabs (mirrors §C.4-tabs in linear.md).
- `--only-issue <number>` — internal flag used by `--tabs` children.
  Skip §E.2 queue fetch and process exactly the named issue
  (`123`), then exit. Assumes preflight passed in the parent.
- `--steps <csv>` — explicit comma-separated set of gates to run, drawn
  from `review`, `qa`, `security`, `polish`, `walkthrough`. Bypasses
  the §E.0.6 checkbox prompt. Empty value (`--steps ""`) disables every
  gate (implement-and-ship). When omitted, §E.0.6 prompts (or reuses
  cached selection).
- `--configure` — re-prompt the §E.0.6 checkboxes even when a cached
  selection exists in `git config supabuild.githubSteps`. Use to change
  which gates run without editing the cached value by hand.
- `--dry-run` — list issues that would be processed and stop.

**No confirmation prompt. Ever.** Same contract as §C — start
immediately on resolved settings, only stop on `--dry-run` or
preflight failure. The §E.0.6 step-selection prompt is *configuration*,
not run confirmation: it asks once per run (cached default makes
reruns one keystroke), is silent when `--steps` is passed, and never
gates the queue itself.

### GitHub interface — `gh` CLI

**All GitHub interactions go through `gh`** — no raw REST or
GraphQL calls. Canonical commands used below:

- `gh repo view --json owner,name -q '.owner.login + "/" + .name'`
  — current repo coordinates
- `gh project list --owner <owner> --format json` — list projects
- `gh project create --owner <owner> --title <title> --format json`
  — create project
- `gh project view <num> --owner <owner> --format json` — fetch
  project metadata (id, url, etc.)
- `gh project field-list <num> --owner <owner> --format json` —
  fetch field IDs and option IDs
- `gh project field-create <num> --owner <owner> --name <name>
  --data-type SINGLE_SELECT --single-select-options "Todo,In
  Progress,In Review,Done"` — create the Status field on first run
- `gh project link <num> --owner <owner> --repo <owner/repo>` —
  link the project to the repo so it shows in the repo's Projects tab
- `gh project item-list <num> --owner <owner> --format json` —
  fetch items + their status field values
- `gh project item-add <num> --owner <owner> --url <issue-url>` —
  add an issue to the project
- `gh project item-edit --project-id <pid> --id <item-id>
  --field-id <fid> --single-select-option-id <oid>` — change status
- `gh issue create --repo <owner/repo> --title <t> --body-file <p>`
  — create an issue
- `gh issue edit <num> --repo <owner/repo> --add-label <l>
  --remove-label <l>` — label management
- `gh issue comment <num> --repo <owner/repo> --body-file <path>` —
  comment (always use `--body-file` for multi-line markdown)
- `gh issue view <num> --repo <owner/repo>
  --json title,body,labels,assignees,url,comments` — fetch issue
- `gh label create <name> --repo <owner/repo> --color <hex>` —
  first-run label setup
- `gh label list --repo <owner/repo> --json name -q '.[].name'` —
  detect existing labels

Fall back to `gh api graphql -f query='...'` only for fields not
exposed via the structured subcommands above. **Never** call
`curl https://api.github.com/...` directly.

### E.0.5. First-run project setup

The Projects v2 board and the four labels (`building`, `testing`,
`choose-design`, `design-selected`) must exist before processing.
On first invocation in a repo, set them up automatically and
idempotently — re-running on a configured repo is a no-op.

1. **Determine repo coordinates.**
   ```bash
   REPO_FULL=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')
   OWNER="${REPO_FULL%%/*}"
   REPO="${REPO_FULL##*/}"
   ```
   If `gh repo view` fails (cwd is not a GitHub-tracked repo), stop
   and tell the user to run from a repo with a GitHub `origin` or
   pass `--repo <owner/repo>`.

2. **Find or create the supabuild project.** (Override with
   `--project <num>` to skip detection entirely.)

   Detection order — stored config first, then a title match against
   the repo name:
   ```bash
   PROJECT_NUM=$(git config --get supabuild.githubProject 2>/dev/null || true)
   if [ -n "$PROJECT_NUM" ]; then
     # Verify the stored project still exists; clear stale config if not.
     if ! gh project view "$PROJECT_NUM" --owner "$OWNER" --format json >/dev/null 2>&1; then
       git config --unset supabuild.githubProject || true
       PROJECT_NUM=""
     fi
   fi
   if [ -z "$PROJECT_NUM" ]; then
     PROJECT_NUM=$(gh project list --owner "$OWNER" --format json \
       | jq -r --arg t "$REPO" '.projects[] | select(.title==$t) | .number' \
       | head -1)
   fi
   if [ -n "$PROJECT_NUM" ]; then
     PROJECT_TITLE=$(gh project view "$PROJECT_NUM" --owner "$OWNER" \
       --format json | jq -r '.title')
   fi
   ```

   If `PROJECT_NUM` is still empty (true first run in this repo),
   **prompt the user via `AskUserQuestion`** before creating
   anything:
   - Question: "No supabuild project found for `$OWNER`. Create one?"
   - Default option: `$REPO` (the repo's name)
   - Also offer: "Use a different name" (free-text follow-up) and
     "Cancel"
   - On a free-text rename, trim whitespace; reject empty strings
     and re-ask.

   Use the user's chosen title (or the `$REPO` default if they
   accept) for `$PROJECT_TITLE`, then create and persist:
   ```bash
   PROJECT_JSON=$(gh project create --owner "$OWNER" \
     --title "$PROJECT_TITLE" --format json)
   PROJECT_NUM=$(echo "$PROJECT_JSON" | jq -r '.number')
   git config supabuild.githubProject "$PROJECT_NUM"
   ```
   Print the project URL so the user can bookmark it. The stored
   `git config` entry means subsequent runs find this project by
   number, so renames on the GitHub side never break detection.

3. **Capture project ID + Status field IDs (one fetch).**
   ```bash
   PROJECT_ID=$(gh project view "$PROJECT_NUM" --owner "$OWNER" \
     --format json | jq -r '.id')
   FIELDS_JSON=$(gh project field-list "$PROJECT_NUM" --owner "$OWNER" \
     --format json)
   STATUS_FIELD_ID=$(echo "$FIELDS_JSON" \
     | jq -r '.fields[] | select(.name=="Status") | .id')
   ```
   If `STATUS_FIELD_ID` is empty (newly-created project, or someone
   renamed the field), create it:
   ```bash
   gh project field-create "$PROJECT_NUM" --owner "$OWNER" \
     --name Status --data-type SINGLE_SELECT \
     --single-select-options "Todo,In Progress,In Review,Done"
   FIELDS_JSON=$(gh project field-list "$PROJECT_NUM" --owner "$OWNER" \
     --format json)
   STATUS_FIELD_ID=$(echo "$FIELDS_JSON" \
     | jq -r '.fields[] | select(.name=="Status") | .id')
   ```
   Capture each option's ID:
   ```bash
   STATUS_OPTS=$(echo "$FIELDS_JSON" \
     | jq -c '.fields[] | select(.name=="Status") | .options[]')
   TODO_OPT_ID=$(echo "$STATUS_OPTS" | jq -r 'select(.name=="Todo") | .id')
   INPROG_OPT_ID=$(echo "$STATUS_OPTS" | jq -r 'select(.name=="In Progress") | .id')
   REVIEW_OPT_ID=$(echo "$STATUS_OPTS" | jq -r 'select(.name=="In Review") | .id')
   DONE_OPT_ID=$(echo "$STATUS_OPTS" | jq -r 'select(.name=="Done") | .id')
   ```
   If any option ID is empty (someone renamed an option), stop and
   ask the user to restore the canonical four — auto-renaming
   options on a project that may have other automation is too risky.

4. **Link the project to the current repo.** Idempotent:
   ```bash
   gh project link "$PROJECT_NUM" --owner "$OWNER" --repo "$REPO_FULL" || true
   ```

5. **Create the four labels** in the repo if missing. Idempotent:
   ```bash
   EXISTING=$(gh label list --repo "$REPO_FULL" --json name -q '.[].name' | tr '\n' '|')
   for spec in "building:0e8a16" "testing:fbca04" "choose-design:d93f0b" "design-selected:0075ca"; do
     name="${spec%%:*}"; color="${spec##*:}"
     case "|$EXISTING|" in
       *"|$name|"*) ;;
       *) gh label create "$name" --repo "$REPO_FULL" --color "$color" ;;
     esac
   done
   ```

6. **Print resolved setup** so the user audits before processing:
   ```
   ## /supabuild github — setup ready
   Repo:     $REPO_FULL
   Project:  #$PROJECT_NUM ($PROJECT_TITLE)
   URL:      <project URL from step 2 / 3>
   Status:   Todo / In Progress / In Review / Done
   Labels:   building, testing, choose-design, design-selected
   Workflow: Each shipped PR includes `Closes #N`, so merging it
             auto-closes the issue. Projects v2 enables the
             "Auto-close issue → Done" workflow by default for
             projects created after April 2024 — closing the issue
             then moves the item to Done. If your project predates
             that and items aren't moving to Done, enable it once at
             <project URL>/workflows.
   ```

   GitHub does not expose an enable/disable mutation for this workflow
   in their public GraphQL — that's why the toggle stays a one-time
   manual step for legacy projects. New projects supabuild creates need
   no manual setup.

### E.0.6. Workflow step selection (run-level batcher for §A.0.6)

§E is a destination adapter — its only job is to feed §A one issue
at a time. The verification-step contract (`SUPABUILD_STEPS=<csv>`,
the five tokens, what each gates) is owned by §A.0.6 and §A.0.7. This
section is purely the **run-level batcher** of that prompt: ask once
per `/supabuild github` run instead of once per issue, then relay the
answer to every per-issue §A invocation via the build prompt body.

If you want to know what each step *does*, what tokens are valid, or
how the parsing rules work, see §A.0.6 (the source of truth) and
§A.0.7 (the parser). This section does not redefine any of that.

Repeated here for convenience only — the canonical table lives in
§A.0.6:

| Step          | Section  |
| ------------- | -------- |
| `review`      | §A.5     |
| `qa`          | §A.5     |
| `security`    | §A.4     |
| `polish`      | §A.4.5   |
| `walkthrough` | §A.5a    |

#### Resolution order

1. **`--steps <csv>` was passed.** Parse it (lowercased, trimmed,
   comma-split), validate every token against the table above (reject
   unknowns with a hard error), set `STEPS_CSV` to the canonical
   sorted CSV, skip the prompt entirely. `--steps ""` is valid and
   means "all gates off". Persist the choice to
   `git config supabuild.githubSteps "$STEPS_CSV"` so subsequent
   no-flag runs default to it.

2. **`--configure` was passed.** Force the prompt regardless of any
   cached value.

3. **Cached value exists.** Read
   `git config --get supabuild.githubSteps` (may be empty string —
   that's still a valid cached "all off" answer; only treat
   `git config` exit status non-zero as "no cache"). If present,
   default the checkbox state to that, then prompt — letting the user
   tweak with one keystroke if their selection hasn't changed.

4. **No cache.** Default all five checkboxes to checked (current
   pre-feature behavior) and prompt.

#### The prompt

Single `AskUserQuestion` with one multi-select question:

```
Q: Which gates should run for every issue this run?
   (uncheck to skip; implementation rounds always run)

Options:
  [x] Code review (§A.5 Code Reviewer)
  [x] QA agent (§A.5 — tests, lint, walkthrough hard-gate)
  [x] Security audit (§A.4)
  [x] Polish & gap pass (§A.4.5)
  [x] UI walkthrough capture (§A.5a — only on UI diffs)
```

Initial check state per resolution order step 3 / 4. Multi-select.
The user submits once; their selection becomes `STEPS_CSV` (canonical
sorted CSV from the table's `Step` column).

#### Persist + announce

```bash
git config supabuild.githubSteps "$STEPS_CSV"
```

Then print a one-line resolved-set banner (and the inverse, so the
user can see what's skipped at a glance):

```
## /supabuild github — gates: review, qa, security
(skipped: polish, walkthrough)
```

If `STEPS_CSV` is empty, print the warning before continuing:

```
## /supabuild github — gates: NONE
heads up: all gates off — every issue will ship after implementation
rounds with no QA, code review, security audit, polish pass, or
walkthrough capture. The Team Lead's own integration check is the
only thing standing between the diff and the PR.
```

The user is allowed to ship with all gates off — supabuild does not
veto. But it must be loud about it.

#### Carve-out from §E.0's "no confirmation prompt ever"

This step is *configuration*, not run/queue confirmation. It runs
once per `/supabuild github` invocation, never gates the issue queue
itself, and is fully silent when `--steps` is passed. Reruns default
to the cached selection so steady-state usage is one keystroke
(the user just hits Enter to accept the cached defaults).

### E.1. Preflight

1. **`gh` install + auth.** Same gap detection + walkthrough as
   §C.1 step 1 parts e–h, but scoped to `gh` only:
   ```bash
   GH_GAPS=()
   if command -v gh >/dev/null 2>&1; then
     gh auth status >/dev/null 2>&1 || GH_GAPS+=("gh-auth")
   else
     GH_GAPS+=("gh-install")
   fi
   ```
   Auto-install `gh` (`brew install gh` on macOS); for `gh-auth`
   print the `gh auth login` instruction and stop.

2. **`gh project` scope.** Projects v2 access requires the `project`
   scope on the gh token. Probe:
   ```bash
   if ! gh project list --owner "$OWNER" --format json --limit 1 >/dev/null 2>&1; then
     SCOPE_GAP=1
   fi
   ```
   If `SCOPE_GAP=1`, print:
   > Run `gh auth refresh -s project,read:project` and authorize in
   > the browser, then re-run `/supabuild github`.

   And stop. (The `project` scope is not granted by default on a
   fresh `gh auth login` — many users will hit this.)

3. **Run E.0.5 setup.** First-run check + auto-creation as above.
   Idempotent on subsequent runs.

4. **Repo state.** `git status --porcelain` must be empty, or
   surfaced and confirmed by the user.

5. **§A reachable.** This skill invokes the build flow inline;
   confirm the §A section is loaded before proceeding.

6. **Capture run-level state once** (so per-issue loops don't
   re-derive identical values, and parallel jobs don't race):
   ```bash
   SGH_CACHE_DIR=/tmp/sgh-cache-$$
   mkdir -p "$SGH_CACHE_DIR"
   echo "$PROJECT_ID"      > "$SGH_CACHE_DIR/project-id"
   echo "$STATUS_FIELD_ID" > "$SGH_CACHE_DIR/status-field-id"
   echo "$TODO_OPT_ID"     > "$SGH_CACHE_DIR/opt-todo"
   echo "$INPROG_OPT_ID"   > "$SGH_CACHE_DIR/opt-inprog"
   echo "$REVIEW_OPT_ID"   > "$SGH_CACHE_DIR/opt-review"
   echo "$DONE_OPT_ID"     > "$SGH_CACHE_DIR/opt-done"
   # Workflow steps resolved in §E.0.6. Empty string is valid (= all gates off).
   printf '%s' "$STEPS_CSV" > "$SGH_CACHE_DIR/steps"
   ```
   Per-issue caches: `$SGH_CACHE_DIR/issue-<NUM>.json` written once
   per issue in §E.2 (or after a hydration re-fetch) and reused by
   §E.3-state, §E.3a-pre, §E.3d, §E.3e. Cache directory removed at
   end of §E.4.

### E.2. Fetch the Todo queue

**`--only-issue <N>` short-circuit.** When invoked with `--only-issue`,
skip the queue fetch entirely. Fetch just the named issue via `gh
issue view "$N" --repo "$REPO" --json …`, persist to the cache, and
treat as a single-row queue. Hard-disable `--tabs` and `--parallel`
for this invocation (a child must never re-spawn) and skip the
§E.0.6 prompt (the parent passed `--steps`). Then jump to §E.3.


```bash
gh project item-list "$PROJECT_NUM" --owner "$OWNER" --format json --limit 200
```

Filter the JSON to items where:
- `content.type == "Issue"` (skip draft items and pull requests)
- the `Status` field value `name == "Todo"`
- if `--assignee` is set: `content.assignees[*].login` contains it

Sort ascending by `content.createdAt` (FIFO), cap at `${LIMIT:-10}`.

For each item, capture into `$SGH_CACHE_DIR/issue-<NUM>.json`:
- `number` (issue number)
- `title`, `body`, `url`
- `labels[*].name`
- `assignees[*].login`
- `itemId` (project item ID — needed for status edits)

Print a banner before processing:
```
# /supabuild github — $PROJECT_TITLE (N items)
1. #42 — Fix invoice rounding bug on the billing page
2. #44 — Add OAuth login button to the navbar
…
```

If `--dry-run` is set, stop here.

### E.3. Per-ticket loop

For each issue in queue, in order (or in parallel batches if
`--parallel <n>`):

1. **Pre-flight design fork check** (§E.3-design). If `design-selected`
   is on the issue OR no UI signal, route = BUILD. Otherwise (UI
   signal AND no `design-selected`), route = DESIGN_EXPLORATION.

2. **Announce + transition Todo → In Progress** (§E.3-state):
   - Move Status to In Progress.
   - Add `building` label (BUILD route) or keep no label yet
     (DESIGN_EXPLORATION).
   - Comment on the issue:
     ```
     ### 🤖 picked up by /supabuild github
     - **Route:** BUILD · Position in queue: i / N
     - **Working branch:** $WORKING_BRANCH
     - **Target (PR base):** $TARGET_BRANCH
     - **Mode:** plan → parallel specialists → security audit →
       QA + code review
     ```

3. **Hydrate image attachments** in the issue body to local files
   (§E.3a-img).

4. **Run the §A build flow inline once** (§E.3c) with the working
   branch derived from the issue title. Build prompt template at
   §E.3c.

5. **On §A APPROVED + PR opened** (§E.3e):
   - Swap labels: `building` → `testing` → eventually neither.
   - Optionally upload walkthrough/screenshots reference (§E.3d.5).
   - Move Status In Progress → In Review.
   - Strip `testing` label.
   - Final comment with PR link.

6. **On §A FAILED**:
   - Move Status In Progress → Todo.
   - Strip `building` (do NOT add `testing`).
   - Comment with failure reason and the partial worktree path so
     the user can finish by hand.

7. Continue to next issue.

**Isolation across tickets.** Same guarantee as §C.3: snapshot
`gh pr list --state open --json number,headRefName,url` before this
loop and after each ticket; each ticket should add **exactly one**
new open PR. If a ticket adds zero or two, stop and report — never
silently continue.

### E.3-state. State transitions

Status changes:
```bash
gh project item-edit \
  --project-id "$PROJECT_ID" \
  --id "$ITEM_ID" \
  --field-id "$STATUS_FIELD_ID" \
  --single-select-option-id "$TARGET_OPT_ID"
```

Label changes:
```bash
gh issue edit "$ISSUE_NUM" --repo "$REPO_FULL" \
  ${ADD_LABEL:+--add-label "$ADD_LABEL"} \
  ${REMOVE_LABEL:+--remove-label "$REMOVE_LABEL"}
```

Comments (always use `--body-file` for multi-line markdown):
```bash
gh issue comment "$ISSUE_NUM" --repo "$REPO_FULL" --body-file "$BODY_PATH"
```

Every transition that the user might be watching in GitHub gets a
comment **before** the slow operation that follows it (e.g., before
the §A build kicks off, not after). The Project board sidebar must
reflect "the robot is on it" the moment the user looks.

### E.3-design. UI design fork

Mirror §C.3-design:

1. **Detect UI signal:** label `ui` or `design` is on the issue, OR
   title/body matches `/(design|ui|ux|layout|landing|onboarding|empty
   state|theme|hero|nav|sidebar|modal)/i`.

2. **If UI signal AND no `design-selected` label:**
   - Route = DESIGN_EXPLORATION.
   - Run the §B design flow (default 4 variants) against the issue
     body. Each variant lands on its own worktree + branch.
   - For each variant, post a comment on the issue with:
     - Variant slug + branch name
     - 2–3 inline screenshots (link to images committed to the
       variant branch under `.supabuild/design-shots/`)
   - Add `choose-design` label, remove `building`.
   - Move Status back to `Todo`.
   - Final comment:
     ```
     🎨 4 variants ready. Pick one in the comments and add the
     `design-selected` label to resume — the next /supabuild github
     run will route this issue to BUILD against the chosen variant's
     branch.
     ```
   - Continue to next issue (this one is parked).

3. **When the user adds `design-selected`** and re-runs, the issue
   routes to BUILD. The chosen variant's branch is read from a
   user-provided link in the issue comments — if missing, comment
   asking for it and park again.

### E.3a-img. Image hydration

GitHub issue bodies embed images via:
- `https://user-images.githubusercontent.com/<id>/<file>`
- `https://github.com/<owner>/<repo>/assets/<id>`
- `https://github.com/user-attachments/assets/<uuid>`

**Unlike Linear's `uploads.linear.app`, GitHub user-content URLs are
publicly accessible — no auth header needed for downloads.** Just
curl them:

```bash
mkdir -p "$WT_PATH/.supabuild/refs"
i=1
echo "$ISSUE_BODY" \
  | grep -oE 'https://(user-images\.githubusercontent\.com|github\.com/[^/[:space:]]+/[^/[:space:]]+/assets|github\.com/user-attachments/assets)/[^[:space:])"\\]+' \
  | while read -r url; do
      ext="${url##*.}"
      case "$ext" in png|jpg|jpeg|gif|webp) ;; *) ext=png ;; esac
      curl -fsSL --max-time 30 -o "$WT_PATH/.supabuild/refs/$(printf '%02d' $i).$ext" "$url" \
        || echo "warn: failed to fetch $url" >&2
      i=$((i+1))
    done
```

Pass the local file paths into the §A build prompt's reference
section (see §E.3c) so specialists can `Read` them.

### E.3c. Run the §A build flow inline — ONE invocation per ticket

Run §A **exactly once** per issue. Never batch issues into a single
§A invocation.

Working branch convention: `supabuild/issue-<NUM>-<slug>` where
`<slug>` is 2–4 kebab-case words from the issue title. Example:
`supabuild/issue-42-fix-invoice-rounding`.

Build prompt template:
```
[GitHub #$ISSUE_NUM] $ISSUE_TITLE

$ISSUE_BODY

## Reference images (downloaded from the GitHub issue — Read these)
- $WT_PATH/.supabuild/refs/01.png
- $WT_PATH/.supabuild/refs/02.png
- ...

--working-branch $WORKING_BRANCH
--branch $TARGET_BRANCH

[Linear …]: do not ask clarifying questions; the issue body above is
the brief. (Note: this skill uses the Linear-style escape hatch
literally to suppress §A.0.5 discovery — the issue body is
authoritative.)

DEFER_WORKTREE_CLEANUP=1
SUPABUILD_TICKET=github:$ISSUE_NUM:$REPO_FULL
SUPABUILD_STEPS=$STEPS_CSV
```

The `DEFER_WORKTREE_CLEANUP=1` signal makes §A.6a skip its own
worktree sweep so §E.3d.5 can read evidence files (walkthrough.webm,
step screenshots) off disk before final cleanup in §E.4.

The `SUPABUILD_TICKET=github:$ISSUE_NUM:$REPO_FULL` signal lets
§A.1 write `$WT_PATH/.supabuild/ticket.env` so the §A.2.5b mirror
helper splices the live plan.md into this issue's body on every
plan mutation (§A.2 first write, each round, security findings, QA
verdict, ship). HTML-comment fences preserve the user-written
issue body above and below. Mirror failures log and are
non-blocking — the plan still lives on disk and (post-§E.3e) on
the PR.

The `SUPABUILD_STEPS=$STEPS_CSV` signal carries the §E.0.6 checkbox
selection through to §A.0.7. Read `STEPS_CSV` from
`$SGH_CACHE_DIR/steps` immediately before constructing the prompt so
parallel issue workers see a consistent value (the cache file is
written once at §E.1 step 6 and never rewritten mid-run). Splice it
literally — including the empty case (`SUPABUILD_STEPS=`), which
§A.0.7 interprets as "all gates off". Do NOT omit the line when
`STEPS_CSV` is empty: the *presence* of the line distinguishes
"orchestrator opted out of every gate" from "no orchestrator signal
at all" (which means default-all-on for direct `/supabuild build`
runs).

### E.3d.5. Walkthrough upload

If §A captured a walkthrough video and step screenshots
(`.supabuild/evidence/00-walkthrough.webm`, `01-step.png`, …),
surface them on the issue:

1. **Pragmatic v1: list the artifacts in a comment, do not upload
   binaries.** GitHub's `gh` CLI does not have a stable
   `gh issue comment --attach <file>` subcommand, and uploading via
   the raw API multipart endpoint is fragile across token scopes.
   Post a comment listing the local file names and a one-line
   instruction:
   ```
   ### 🎬 Walkthrough captured
   The QA gate captured these artifacts in the build worktree:
   - 00-walkthrough.webm (~Ns)
   - 01-step.png, 02-step.png, 03-step.png

   Drag them into this issue or the PR conversation if you want
   them attached — they will not be auto-uploaded by /supabuild
   github in this version.
   ```
2. The PR description's `## Walkthrough` section (written by §A.6a)
   names the same artifacts, so reviewers see them on the PR side
   too.

(A future enhancement is true upload via `gh api graphql` mutation —
left out of v1 to keep the dependency footprint small.)

### E.3e. End-of-ticket transitions

On §A APPROVED + PR opened:
```bash
# Ensure the PR body contains a closing keyword for this issue. Without
# this, merging the PR does not close the issue, so the project's
# "Auto-close issue → Done" workflow has no event to react to and the
# item is stuck in "In Review" forever. Idempotent: only prepends if no
# closing keyword for this issue is already present (in case the build
# agent or a human added one). Non-fatal on failure — manual fix is one
# `gh pr edit` away.
PR_NUMBER="${PR_URL##*/}"
PR_BODY_CUR=$(gh pr view "$PR_NUMBER" --repo "$REPO_FULL" --json body -q '.body // ""')
if ! printf '%s' "$PR_BODY_CUR" \
     | grep -qiE "(closes|fixes|resolves)[[:space:]]+#${ISSUE_NUM}([^0-9]|$)"; then
  printf 'Closes #%s\n\n%s' "$ISSUE_NUM" "$PR_BODY_CUR" \
    > "/tmp/sgh-pr-close-$$.md"
  gh pr edit "$PR_NUMBER" --repo "$REPO_FULL" \
    --body-file "/tmp/sgh-pr-close-$$.md" \
    || echo "warn: failed to add Closes #$ISSUE_NUM to PR body (continuing)"
  rm -f "/tmp/sgh-pr-close-$$.md"
fi

# Final state move
gh project item-edit --project-id "$PROJECT_ID" --id "$ITEM_ID" \
  --field-id "$STATUS_FIELD_ID" --single-select-option-id "$REVIEW_OPT_ID"
gh issue edit "$ISSUE_NUM" --repo "$REPO_FULL" --remove-label "testing"
gh issue comment "$ISSUE_NUM" --repo "$REPO_FULL" --body-file <(cat <<EOF
### 🔗 PR opened
$PR_URL

State: In Progress → In Review. Merging the PR will auto-close this
issue (\`Closes #$ISSUE_NUM\` is in the PR body) and the project's
\`Auto-close issue\` workflow will move it to **Done**.
EOF
)
```

On §A FAILED:
```bash
gh project item-edit --project-id "$PROJECT_ID" --id "$ITEM_ID" \
  --field-id "$STATUS_FIELD_ID" --single-select-option-id "$TODO_OPT_ID"
gh issue edit "$ISSUE_NUM" --repo "$REPO_FULL" --remove-label "building"
gh issue comment "$ISSUE_NUM" --repo "$REPO_FULL" --body-file <(cat <<EOF
### ⚠️ build did not pass the QA gate
$FAILURE_REASON

State: In Progress → Todo. Worktree retained at \`$WT_PATH\` for
inspection. Re-run /supabuild github to retry, or finish by hand.
EOF
)
```

### E.4-tabs. Tab-spawn mode (`--tabs`)

When `--tabs` is set, the parent does **not** dispatch §A inline.
After §E.1 preflight + §E.2 queue fetch, route each issue (§E.3-route
equivalent — UI-design vs build vs awaiting-human), then for each
spawnable issue shell out to:

```bash
"$SKILL_BASE/../../scripts/spawn-tab.sh" \
  "$REPO_ROOT" \
  "claude --dangerously-skip-permissions -p '/supabuild github --only-issue $NUMBER --steps $STEPS_CSV --target $TARGET'"
```

Same contract as §C.4-tabs in linear.md (which is canonical):

1. Preflight (`gh auth`, project setup) runs in the parent only.
2. Each child is `--only-issue <N>` — fetches just that issue,
   skips §E.2 queue fetch, runs §E.3 once, exits.
3. `--steps $STEPS_CSV` passes through verbatim so children never
   re-prompt.
4. AWAITING_HUMAN issues are not spawned — listed as skipped in
   the parent's mini summary.
5. The parent posts no GitHub comments on issues — narration is
   the child's job.
6. Queue > 5 → 5-second warning, then proceed. No cap.
7. Parent exits after spawning; the §E.5 summary is replaced by a
   compact "spawned" table identical in shape to §C.4-tabs.
8. `--tabs` and `--parallel` are mutually exclusive — abort if both.

### E.4. Run-level cleanup

- Remove `$SGH_CACHE_DIR`.
- Worktrees: §A.6a's auto-cleanup ran for every approved ticket
  (DEFER signal already cleared after §E.3d.5). Failed tickets'
  worktrees are intentionally retained per the §E.3e failure path.

### E.5. Summary

Print a tabular summary at the end:

```
## /supabuild github — done
Project:   #$PROJECT_NUM ($PROJECT_TITLE)
Gates:     review, qa, security        ← from §E.0.6 (or "NONE" if all off)
Skipped:   polish, walkthrough         ← inverse of Gates (omit row if empty)
Processed: N issues
Shipped:   M PRs opened
Parked:    K issues with `choose-design` (awaiting design pick)
Failed:    F issues moved back to Todo

| #   | Title                                | Outcome   | PR              |
| --- | ------------------------------------ | --------- | --------------- |
| 42  | Fix invoice rounding…                | shipped   | #46             |
| 44  | OAuth login button                   | shipped   | #47             |
| 51  | Redesign empty state                 | parked    | (4 variants)    |
| 53  | Migrate auth middleware              | failed    | (worktree kept) |
```

The Gates / Skipped rows make it obvious post-hoc which verifications
ran for this batch. If the user shipped with `--steps ""`, "Gates:
NONE" is the loud reminder that the diffs in those PRs went out
without QA, code review, security audit, polish, or walkthrough.
