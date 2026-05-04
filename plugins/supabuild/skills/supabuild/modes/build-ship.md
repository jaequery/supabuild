## §A.6 (extended) — Ship details

This file is **lazy-loaded** by build.md §A.6 only when the §A.5
verdict is APPROVED. Builds that escalate / fail / loop never read it
— the load is paid only on the runs that actually ship.

When the verdict is APPROVED, the Team Lead produces a **final report**:

```
## /supabuild build — APPROVED
**Goal:** <one line>
**Branch:** $BRANCH
**Worktree:** $WT_PATH
**Commits:** <count>, <range>
**Rounds run:** <n>
**Gates run:** review, qa, security, polish, walkthrough  ← from SUPABUILD_STEPS (omit row if signal absent)
**Gates skipped:** <inverse list>                          ← omit row if empty

### What was built
- <bullet>
- <bullet>

### Security audit
- <findings + how resolved>     ← or "skipped via SUPABUILD_STEPS" if `security` off

### Polish pass
- <gap list summary>            ← or "skipped via SUPABUILD_STEPS" if `polish` off

### QA + code review
- <findings + how resolved>     ← or "skipped via SUPABUILD_STEPS" if both `qa` and `review` off; partial when only one ran

### Known limitations / follow-ups
- <bullet> (if any)
```

When sections were skipped via `SUPABUILD_STEPS`, do **not** drop
their headers — keep them with a single line stating the skip and
which signal triggered it. Reviewers reading the report should be
able to see at a glance which gates ran without cross-referencing
the round log.

Then choose the ship path based on `$TARGET_BRANCH`:

### A.6a. `$TARGET_BRANCH` was provided — push and open PR

**Do NOT append a `## Visual evidence` section that links into
`.supabuild/evidence/...`.** Evidence is not committed (per §A.5.5),
so relative-path image links would 404 on GitHub. Instead, append a
short **`## Walkthrough`** section that names the local artifacts:

```markdown
## Walkthrough

QA captured a walkthrough video and step screenshots; they are
attached to the Linear ticket (and/or as a follow-up PR comment) —
not committed to the branch.

- Walkthrough: `00-walkthrough.webm` (~<n>s)
- Steps: `01-step.png`, `02-step.png`, `03-step.png`
```

If §A.5.5 was skipped ("no visual surface" or "not captured: <reason>"),
state that explicitly in the same section instead of omitting it. The
orchestrator (§C.3d.5, or a human running standalone) is responsible
for uploading the actual files to Linear / a PR comment.

If `walkthrough` was disabled via `SUPABUILD_STEPS`, the section
becomes:

```markdown
## Walkthrough

Walkthrough capture was disabled for this run via `SUPABUILD_STEPS`
(orchestrator opted out of visual proof). No video or screenshots
were captured. Reviewer should manually verify the UI surface before
merging if needed.
```

State the skip explicitly — silently omitting the section would let
"no walkthrough" look indistinguishable from "we forgot".

1. Detect remote: `git -C "$REPO_ROOT" remote get-url origin`. If no
   `origin`, abort the push and tell the user how to add one — leave the
   worktree as-is so they can finish manually.
2. `cd "$WT_PATH" && git fetch origin` (warn on failure; do not abort).
3. Resolve base ref: `origin/$TARGET_BRANCH` if it exists, else
   `$TARGET_BRANCH`, else `$BASE_SHA`. Pick the first that exists.
4. Record lease target before rebase:
   `LEASE=$(git -C "$WT_PATH" rev-parse "origin/$BRANCH" 2>/dev/null || echo "")`.
5. **Merge-conflict preflight.** Probe whether `$BRANCH` merges cleanly
   into `$BASE_REF` before touching the index:
   `git -C "$WT_PATH" merge-tree --write-tree --name-only --no-messages "$BASE_REF" "$BRANCH"`.
   If the output contains any filenames (conflicting paths), STOP and
   list them to the user — do not proceed to step 6.
6. `cd "$WT_PATH" && git rebase "$BASE_REF"` — on conflict, STOP and
   hand back to the user; do not run `git rebase --abort`. The user
   resolves locally (`git add` + `git rebase --continue`) and re-runs.
7. **Post-rebase conflict guard.** Before pushing, verify the working
   tree is clean and no conflict markers survived:
   - `git -C "$WT_PATH" status --porcelain` must be empty.
   - `git -C "$WT_PATH" ls-files -u` must be empty (no unmerged entries).
   - `git -C "$WT_PATH" grep -nE '^(<{7}|={7}|>{7}) ' -- ':!*.md'` must
     return nothing (no leftover `<<<<<<<` / `=======` / `>>>>>>>` markers).
   Any check failing → STOP and report to the user. Do not push.
8. **Typed-`yes` gate** before pushing: show `$BRANCH`, the LEASE target
   (or "first push"), and `$BASE_REF`. Require literal `yes`.
9. Push:
   - LEASE non-empty: `git -C "$WT_PATH" push --force-with-lease="$BRANCH:$LEASE" --force-if-includes -u origin "$BRANCH"`.
   - LEASE empty: `git -C "$WT_PATH" push -u origin "$BRANCH"`.
10. `cd "$WT_PATH" && gh pr create --fill --base "$TARGET_BRANCH"`. If
    `gh` is missing, print the push URL from step 9 and stop.
10.5. **Mirror the plan into the PR body.** `gh pr create --fill`
    seeds the PR body from the latest commit message — replace it
    with the same fenced plan block that's on the ticket so reviewers
    see goal/AC/risks/round log without leaving the PR. Run after
    `gh pr create` returns; failure is non-fatal (plan still lives on
    the ticket and on disk).
    ```bash
    PR_NUMBER=$(gh pr view --json number -q '.number')
    PR_BODY=$(gh pr view --json body -q '.body // ""')
    PLAN_BODY_FOR_PR=$(cat "$WT_PATH/.supabuild/plan.md" 2>/dev/null)
    if [ -n "$PLAN_BODY_FOR_PR" ]; then
      sb_plan_splice "$PR_BODY" "$PLAN_BODY_FOR_PR" \
        > "/tmp/sb-pr-body-$$.md"
      gh pr edit "$PR_NUMBER" --body-file "/tmp/sb-pr-body-$$.md" \
        || echo "warn: PR body plan mirror failed (continuing)"
      rm -f "/tmp/sb-pr-body-$$.md"
    fi
    ```
    Also flip the plan's `**Status:**` to `shipped` and append a
    `**PR:** $PR_URL` line under it before this mirror — that single
    `sb_plan_update` call propagates the shipped status to the
    ticket too:
    ```bash
    PR_URL=$(gh pr view --json url -q '.url')
    # update plan.md status line + append PR link, then:
    sb_plan_update "$PLAN_BODY"
    # PR body mirror above will pick up the shipped status from disk.
    ```
11. **Auto-cleanup after successful push + PR**: once the PR has been
   opened (the branch lives on origin and locally), remove the worktree
   automatically — UNLESS an orchestrator has asked you to defer.

   **Defer signal.** If the invoking prompt body contains the literal
   string `DEFER_WORKTREE_CLEANUP=1` (set by §C so §C.3d.5 can read
   evidence files off disk), SKIP this step entirely.
   Print: `worktree retained for orchestrator: $WT_PATH`. The
   orchestrator owns cleanup after it's done with the artifacts.

   Otherwise, clean up now:
   ```
   # Evidence is no longer committed (per §A.5.5), so nothing under
   # $WT_PATH/.supabuild/evidence/ lives on origin. The whole tree is
   # ephemeral — sweep it before `worktree remove`, since the dir is
   # untracked and would block removal.
   rm -rf "$WT_PATH/.supabuild/evidence" 2>/dev/null
   git -C "$REPO_ROOT" worktree remove "$WT_PATH"
   git -C "$REPO_ROOT" branch -d "$BRANCH"   # safe delete; skip if it fails (unmerged)
   ```
   Print one line confirming both. If `worktree remove` STILL fails
   after the sweep (means real uncommitted changes survived push), fall
   back to asking the user whether to force-remove or keep — do not
   silently leave artifacts without flagging. In autonomous-push mode
   without the defer signal, force-remove is the right call after the
   sweep — log the reason but don't block on it.
12. **Drop the per-worktree DB** if §A.1.5 created one. Run from
    `$REPO_ROOT` against the same compose service:
    - **Postgres:**
      ```
      docker compose exec -T <svc> psql -U "$USER" -d postgres \
        -c "DROP DATABASE IF EXISTS \"$DB_BRANCH\" WITH (FORCE);"
      ```
    - **MySQL / MariaDB:**
      ```
      docker compose exec -T <svc> mysql -uroot -p"$ROOT_PASS" \
        -e "DROP DATABASE IF EXISTS \`$DB_BRANCH\`;"
      ```
    - **Mongo:**
      ```
      docker compose exec -T <svc> mongosh "$BRANCH_URL" \
        --quiet --eval "db.dropDatabase()"
      ```
    Failures here are non-fatal — log and continue. Skip entirely if
    §A.1.5 was skipped.

### A.6b. No target branch — hand back the worktree

Print `$WT_PATH` and `$BRANCH` and offer the standard 6-option menu
from §D (the worktree flow):

```
(a) keep worktree as-is
(b) merge $BRANCH into a target branch
(c) rebase onto base, push, open PR
(d) discard worktree and branch (typed-yes gated)
(e) stash uncommitted changes, keep worktree
(f) adopt branch: remove worktree, checkout $BRANCH in main tree
```

For destructive options, follow §D's typed-`yes` gates and discard
rules verbatim — do not invent shortcuts.

If §A.1.5 created a per-worktree DB and the user picks **(d) discard**
or **(f) adopt branch**, also drop the branch DB using the §A.6a step
12 commands. For **(c) rebase + push**, run the §A.6a step 12 cleanup
after the PR is opened. For **(a)/(b)/(e)**, leave the branch DB in
place — the user is still using it.
