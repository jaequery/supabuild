## §A.5a (extended) — Walkthrough capture details

This file is **lazy-loaded** by build.md §A.5a only when both:
- `sb_step_enabled walkthrough` returns true, AND
- `$UI_DIFF` from §A.5 Step 1 is non-empty.

Direct invocations and non-UI builds never read it — saves the load on
every backend-only build, every `--steps "review,qa,security"` run,
and every Linear/GitHub burndown ticket whose diff doesn't touch
render paths.

### Resolution order (first match wins)

1. **`$WT_PATH/.supabuild/capture.sh`** — repo-owned hook (highest
   priority). Receives env vars `WT_PATH`, `EVID`, `URL` (or `PORT`),
   and is responsible for the entire boot → record → teardown cycle.
   Use this when the repo has custom auth, migrations, or preview-URL
   handling that boilerplate detection can't cover. The hook MUST
   leave `$EVID/00-walkthrough.{webm,mp4}` on disk; everything else
   is optional.

2. **`package.json` field `supabuild.capture`** — same contract as the
   hook.

3. **Default: shipped `scripts/capture.sh`.** Run the script that
   ships with this plugin:

   ```bash
   STEPS_FILE="$WT_PATH/.supabuild/walkthrough-steps.sh" \
     bash "$SUPABUILD_PLUGIN_ROOT/scripts/capture.sh"
   ```

   Where `$SUPABUILD_PLUGIN_ROOT` is the plugin's base directory
   (printed at the top of skill invocation; the same path the SKILL.md
   router uses to find `modes/`).

   The shipped script handles: dev-server detection (10 frameworks),
   boot + 30s readiness poll, playwright-cli session + video session,
   teardown trap. It exits non-zero with an explicit reason on
   failure (no boot command detected, server didn't answer, video
   missing or <50KB).

### Per-build walkthrough steps (when AC is browser-actionable)

When the AC is browser-actionable (login flow, form submission, etc.),
the Team Lead authors per-ticket steps. Write them to
`$WT_PATH/.supabuild/walkthrough-steps.sh` BEFORE invoking the capture
script — `STEPS_FILE` is sourced after `video-start` and runs in the
same shell with `$SESS` and `$EVID` already set.

Example `walkthrough-steps.sh`:

```bash
playwright-cli -s="$SESS" video-chapter "Login"
playwright-cli -s="$SESS" fill "input[name=email]" "test@example.com"
playwright-cli -s="$SESS" fill "input[name=password]" "test1234"
playwright-cli -s="$SESS" click "button[type=submit]"
playwright-cli -s="$SESS" screenshot "$EVID/01-login.png"
playwright-cli -s="$SESS" video-chapter "Dashboard loaded"
playwright-cli -s="$SESS" screenshot "$EVID/02-dashboard.png"
```

If `walkthrough-steps.sh` is absent, the shipped script falls back
to a generic scroll-and-screenshot tour — at minimum that proves the
page renders.

### Artifact contract (preserved for §C.3d.5 / §E.3d.5)

- `$EVID/00-walkthrough.webm` — primary walkthrough video. **Hard
  APPROVED gate** per build.md §A.5 step 3 (≥50KB).
- `$EVID/0[1-3]-step.png` — up to 3 step stills (best-effort).
- `$EVID/playwright-report.zip` — only present when the optional
  test bonus below ran and produced a report.
- `$EVID/server.log` — dev-server stdout/stderr (debugging aid only).

### Optional bonus — run existing tests

After the walkthrough completes, if the repo has a JS/TS test runner
configured, run it for **bonus signal only**. Pass/fail surfaces in
the §A.6 verdict but does **not gate APPROVED**. A failing project
test that has nothing to do with the diff under review (flaky,
unrelated suite, pre-existing breakage) is not a reason to block the
ship. Skip this entire block on non-JS/TS repos — there's no PHPUnit /
PyTest / RSpec hookup, by design.

```bash
# Playwright — produces a browseable HTML report; archive it for §C.3d.5.
PW_CFG=$(find "$WT_PATH" -maxdepth 4 -name 'playwright.config.*' \
  -not -path '*/node_modules/*' | head -1)
if [ -n "$PW_CFG" ]; then
  ( cd "$(dirname "$PW_CFG")" \
    && pnpm exec playwright test \
       --reporter=list,html \
       --output="$EVID/playwright-output" 2>&1 \
    | tee "$EVID/test-run.log" \
    || echo "playwright tests had failures (non-blocking)" )
  if [ -d "$EVID/playwright-report" ]; then
    ( cd "$EVID" && zip -qr playwright-report.zip playwright-report )
  fi
fi

# Cypress — pass/fail to log only; no archive.
if [ -f "$WT_PATH/cypress.config.ts" ] || [ -f "$WT_PATH/cypress.config.js" ]; then
  ( cd "$WT_PATH" \
    && npx cypress run --reporter spec 2>&1 \
    | tee -a "$EVID/test-run.log" \
    || echo "cypress tests had failures (non-blocking)" )
fi
```

When the bonus run fires, the Team Lead reads `$EVID/test-run.log`
and notes pass/fail in the §A.6 verdict. If a failure clearly
corresponds to the diff under review (not flaky/unrelated), the Team
Lead may choose NEEDS ANOTHER ROUND on that basis — but the **video
walkthrough remains the primary verification.**

### Failure semantics

- Capture script exits non-zero, dev server doesn't answer within
  30s, or the video file is missing/<50KB → `capture failed: <exit
  code + reason>` is recorded as a finding. Team Lead decides
  whether this blocks APPROVED:
  - If the diff is genuinely UI-bearing, capture failure = NEEDS
    ANOTHER ROUND (or ESCALATED if the failure is structural, e.g.
    no detectable boot command, or auth-walled app with no
    `.supabuild/capture.sh`).
  - If the diff is UI-adjacent but verifiable another way (Storybook,
    snapshot, terminal transcript), Team Lead may waive and proceed.
- Optional test-bonus failures are surfaced but **do not gate
  APPROVED** unless the failure clearly corresponds to the diff.
- This is the only place capture failure is allowed to surface as a
  blocker. §A.5.5 and §C.3d.5 reuse the artifact produced here; they
  do not re-boot the server.
