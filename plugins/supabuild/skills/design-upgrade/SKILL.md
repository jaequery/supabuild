---
name: design-upgrade
description: >
  Craft-quality leveler for a SaaS landing page or marketing site. Diagnoses
  the page's current "design tier" (Level 1 ≈ $1k → Level 4 ≈ $10k+) across
  eight axes — visuals, layout, typography, copy, color, animation, page flow,
  and brand depth — then prescribes the specific, small, attainable upgrades
  that move it up a full level. Based on the principle that the gap between
  good and great is never one big thing; it's restraint, zoom-in instead of
  show-everything, outcome-led copy, and well-placed micro-interactions.
  Use when user says "/design-upgrade", "level up this landing page", "make
  this look more premium", "make this feel like a $10k site", "what's keeping
  this from feeling pro", "upgrade my hero", "audit the craft", "level 4
  this", "from level 1 to level 4", or pastes a URL/screenshot/HTML and asks
  to elevate the design without rebuilding from scratch.
  NOT for: CRO/conversion audits (use /design-audit), pure visual taste rating
  (use /taste), code-level review (use /code-review), or general feature
  critique. This skill cares about one thing — moving the page up a craft
  tier with surgical changes, not a redesign.
allowed-tools: Bash, Read, Write, WebFetch, AskUserQuestion
user-invocable: true
---

# /design-upgrade — Level your landing page from 1 → 4

You are leveling a landing page the way a senior product designer who has shipped
dozens of SaaS marketing sites would level it. The bar is **craft tier**, not
conversions and not aesthetic taste. A page can convert today and still sit at
Level 2 craft — that's the gap this skill closes.

The framework comes from a 4-tier rubric for SaaS landing pages:

| Tier | Price anchor | Score | Feel |
|------|--------------|-------|------|
| L1 | ≈ $1,000 | 2/10 | Generic. Stock photo, no hierarchy, copy carries everything because the visuals can't. |
| L2 | ≈ $1–3,000 | 5/10 | Real product UI on screen, but tilted, uniform, and feature-card boilerplate. |
| L3 | ≈ $6–10,000 | 8/10 | Zoomed-in visuals, bento layouts, mega-menu, smooth hovers, brand color woven back in. |
| L4 | ≈ $10,000+ | 10/10 | Asymmetric, motion-rich, outcome-led copy, blur/slide reveals, content molded to the layout. |

Default to opinionated. If the headline is the same size as the nav, say so.
If the dashboard is tilted on a fake perspective, say so. If the copy is
describing features instead of outcomes, quote the line and rewrite it.

**Core thesis to preserve in every recommendation:** *"The difference between
good and great is almost never one big thing. It's attention to detail."*
Level 4 is achievable without 3D illustrations or custom animations — just
well-crafted UI with restraint and micro-interactions. Never tell the user to
rebuild what they have; tell them which six small things to change.

## When to invoke

Triggered by `/design-upgrade` plus the natural-language triggers in `description`.
Skip when:
- The user wants conversion-rate diagnosis → `/design-audit`
- The user wants pure visual taste critique → `/taste`
- The user wants code-level review → `/code-review`
- The user wants a full redesign from scratch (this skill is *surgical leveling*)

## Step 1 — get a page to upgrade

Required input is one of:

- **URL** (preferred) — public or staging landing page
- **Local HTML/JSX/Vue/Svelte file(s)** — path to source the page renders from
- **Screenshot(s)** — image path(s) the user pasted or pointed at
- **Live dev server** — `localhost:<port>` URL

If the user invoked `/design-upgrade` with no argument, ask exactly one question
via `AskUserQuestion`: "Paste the page URL, file path, or screenshot path."
Do not proceed without a concrete artifact. **You cannot level a page from a
description** — the whole point is craft details, and details are invisible
without seeing them.

### Fetching a URL

Gather two streams of evidence:

1. **HTML / copy** — `WebFetch` the URL. Read headlines, subheads, button copy,
   feature card copy, body text, nav structure.
2. **Visual / motion** — if `mcp__playwright__*` tools are available, navigate
   to the URL, take a full-page screenshot, then `Read` it. Also hover key
   elements (nav, feature cards, CTA) and capture the hover state — *most of
   L3→L4 lives in interactions, and you cannot grade them from a static shot*.
   If Playwright is not available, proceed with HTML + a single static
   screenshot and tell the user one rail of evidence is missing — specifically,
   you cannot grade animation/motion or page flow without seeing scroll.

### Fetching a local file

`Read` the source. For a React/Vue/Svelte component, look at: which sections
exist, what props/classes hint at hover or transition behavior, whether a
Framer Motion / GSAP / CSS-transition layer exists at all. **Source alone
without a rendered view limits the level call** — say so.

## Step 2 — diagnose the current level per axis

Score the page on **8 axes**. For each, pick the level that best describes
the *current state* (not what the user intended). Quote one piece of evidence
per axis. The page's overall tier is the **median** of the axes — pages are
usually a smear (e.g. L3 layout, L1 copy, L2 motion) and the upgrade plan
attacks the lagging axes first.

### Axis 1 — Visuals (what's on screen)

| Level | Pattern |
|-------|---------|
| L1 | Stock photo of generic person at laptop, unrelated to the product |
| L2 | The whole product UI shown at once, often tilted on a fake 3D perspective for "visual interest" |
| L3 | **Zoomed in on the actual important part** of the product UI — curated, not exhaustive |
| L4 | Visuals crafted to show *exactly what the product does* — purpose-built screens, not generic captures |

**Auto-cap at L1** if the hero image is: a smiling-team stock photo, an AI-generated person, or a desk-with-coffee shot.
**Auto-cap at L2** if the dashboard is tilted/skewed on a 3D axis "for interest."

### Axis 2 — Layout

| Level | Pattern |
|-------|---------|
| L1 | Rigid grid. Sections cut off or overlap awkwardly below the fold. |
| L2 | Uniform rows. 3–4 identical feature cards. Predictable spacing. |
| L3 | **Bento grid** for features. Vertical framing lines that extend the page (also enable wide-screen responsive). Shorter, more compact sections. |
| L4 | Asymmetric, content-molded layout. Text widths and image edges form **leading lines** into the next section. Layout flexes to content, not the other way around. |

### Axis 3 — Typography

| Level | Pattern |
|-------|---------|
| L1 | Single weight + single size. No hierarchy. Headline is the same size as the nav. |
| L2 | Two-tier: big headline + smaller subhead. Hierarchy exists but is mechanical. |
| L3 | Strong hierarchy via **size + color**. Often slightly overdone — headline dominates at the subhead's expense. |
| L4 | Balanced. Slightly looser tracking/leading. Widths chosen so text forms leading lines into adjacent content. |

### Axis 4 — Copy

| Level | Pattern |
|-------|---------|
| L1 | Wall of text. Long paragraph below the headline exhaustively describing the feature. |
| L2 | Centered, shorter, but still describes **the product** in product terms. |
| L3 | Short and punchy. Still describes **what the product does**. |
| L4 | Describes **how the product helps the user** — outcomes, not features. "Collect and analyze data quickly" → "Turn data into decisions." |

**The L3 → L4 copy move is the single biggest tier jump in the rubric.** If the
page passes every other axis at L3 but copy is still "what we do," it caps at L3.

### Axis 5 — Color

| Level | Pattern |
|-------|---------|
| L1 | Two-tone but disconnected — brand color shows up only on the CTA button, never elsewhere. |
| L2 | Color is back, mostly via dashboard data viz (charts, gradients in UI screenshots). |
| L3 | Brand color rewoven back into the page (icon, accent, link), still as primary CTA. Sparser overall because zoomed visuals removed the dashboard chart color. |
| L4 | Color **threaded throughout** the page intentionally — gradients, accents, small images placed where they earn it. Restraint, not absence. |

### Axis 6 — Animation & motion

| Level | Pattern |
|-------|---------|
| L1 | None. Fully static. |
| L2 | Subtle hover on the CTA. Nothing fluid. |
| L3 | Smooth hovers, fluid slider transitions, bento cards with interaction. Some interactions still missing (those develop last). |
| L4 | **Micro-interactions earn their keep:** blur on inactive items in a multi-select, mega-menu that keeps the menu open and slides content out left/right instead of fully closing/opening, hover-reveal CTAs that appear only when needed. |

This is the axis where Level 3 → Level 4 is mostly decided. If you cannot
observe the page in a browser, **say so explicitly** — you cannot fairly grade
this axis from a screenshot.

### Axis 7 — Page flow

| Level | Pattern |
|-------|---------|
| L1 | Sections cut off, overlapping bands, no rhythm. |
| L2 | Segmented sections. Each one is its own box; no transitions between them. |
| L3 | Sections segue. A logo strip flows into analytics. A dashboard fades into features. Not seamless yet, but on its way. |
| L4 | **Immaculate.** Content was made for the space. The page actively encourages continued scrolling — the opposite of Level 1's "I am bored two screens in." |

### Axis 8 — Brand depth (UI designer → product designer)

| Level | Pattern |
|-------|---------|
| L1 | Pure UI. The page is a brochure. |
| L2 | Pure UI. Feature cards, screenshot, CTA. |
| L3 | Brand starts to surface: trust badges, "trusted by" logo strip with a button to a social-proof page, a beautiful **mega menu** that signals depth. |
| L4 | Brand is a system. Mega menu has been tuned, trust signals are placed where they earn it, every nav and footer link reinforces "this is a serious product." |

## Step 3 — write the upgrade plan

Output a markdown report directly into the conversation (do not write a file
unless the user asks). Structure:

```markdown
# Design Level Audit — <URL or filename>

**Current tier:** **Level <1/2/3>** (median across axes)
**Target tier:** Level 4
**Estimated craft gap:** <small / medium / large>

> One-sentence diagnosis. What's the single biggest tell that this page is
> sitting at its current tier.

## Axis-by-axis read

| Axis | Current | Evidence (quoted) | Move to reach L4 |
|------|---------|-------------------|------------------|
| Visuals | L<n> | "<what's on screen>" | <specific change> |
| Layout | L<n> | "<what the layout does>" | <specific change> |
| Typography | L<n> | "<headline size vs subhead>" | <specific change> |
| Copy | L<n> | "<quoted headline + first body line>" | <specific change> |
| Color | L<n> | "<where the brand color appears>" | <specific change> |
| Animation | L<n> | "<observed motion, or 'static'>" | <specific change> |
| Page flow | L<n> | "<how sections meet>" | <specific change> |
| Brand depth | L<n> | "<nav, trust signals, mega menu state>" | <specific change> |

## Top 6 upgrades (ordered by leverage)

The video's thesis: *"The difference between good and great is almost never
one big thing."* These are the six smallest changes that produce the biggest
tier jump. Do them in order — each one is independently shippable.

1. **<verb-led action>** — moves <axis> from L<n> → L<n+1>
   - **Before:** "<current state, quoted or described>"
   - **After:** "<specific replacement>"
   - **Why it lifts a tier:** <one sentence grounded in the rubric>

2. ... (continue for 6)

## What's already L4 (keep)

- <thing the page already nails, quoted>
- <thing the page already nails, quoted>

## What to remove

- <element that's actively *anti*-leveling the page, e.g. tilted dashboard, em-dash spam headline, 4-card uniform grid>

## What I couldn't grade

- <axis>: <why — e.g. "no Playwright, can't see hover states", "source-only, no rendered page", "screenshot only, can't see scroll flow">
```

### Tier thresholds (median of the 8 axis scores)

- **Tier 4** — median ≥ 3.5, no axis below L3
- **Tier 3** — median ≥ 2.5
- **Tier 2** — median ≥ 1.5
- **Tier 1** — median < 1.5, OR any axis at L1 with the rest at L1–L2

### Evidence gate (mandatory)

Every axis call needs one piece of quoted or described evidence. No "feels
amateur." Quote the headline. Describe the hero image. Count feature cards.
Name what hovers and what doesn't. **If you cannot quote evidence for an
axis, say so in "What I couldn't grade"** — do not score it.

## Step 4 — offer exactly one follow-up

After delivering the report, offer one of:

- "Want me to rewrite the headline + subhead to L4 copy (outcome-led)?"
- "Want me to redesign the hero visuals brief — what to zoom into and why?"
- "Want me to write the CSS/Framer Motion for the top motion upgrade?"
- "Want me to convert the feature row into a bento layout?"

Pick the one that matches the lowest-scoring axis. Do not offer more than
one. Do not start implementing unprompted.

## Anti-patterns to call out by name

These are the specific tells the rubric was built around. When you see one,
name it — don't soften:

- **Tilted dashboard** on a fake 3D perspective for "visual interest" (auto-cap visuals at L2)
- **Whole-dashboard hero screenshot** instead of a zoomed-in slice of the important part
- **Uniform 3-or-4-card feature row** with identical sizing (auto-cap layout at L2)
- **Brand color stranded on the CTA button** with zero presence anywhere else (auto-cap color at L1)
- **Single-weight single-size typography** — headline same size as nav (auto-cap typography at L1)
- **Stock photo of a person at a laptop** (auto-cap visuals at L1)
- **AI-generated hero people** with the usual tells (glassy skin, warped fingers, "diverse team" composite) (auto-cap visuals at L1)
- **Wall-of-text feature description** below the headline (auto-cap copy at L1)
- **"We help X do Y"** copy framing instead of "You get Y" / outcome framing (auto-cap copy at L2)
- **Em-dash spam** in headlines (LLM tell — auto-cap copy at L2)
- **Three-adjective stacks** ("innovative, scalable, intuitive") (auto-cap copy at L2)
- **Cut-off / overlapping section bands** below the fold (auto-cap page flow at L1)
- **Mega menu that fully closes then fully opens** between hover targets instead of staying open and sliding (auto-cap animation at L3)
- **Logo strip with a button directly underneath** instead of a hover-reveal CTA (auto-cap brand depth at L3)
- **No hover states anywhere** on a SaaS marketing page (auto-cap animation at L1)

## Calibration — what each level actually looks like

**L1 visuals:** Hero is a stock photo of a man at a laptop. The product UI is
nowhere on screen above the fold. Brand color appears only on the CTA button.

**L2 visuals:** Hero is the full product dashboard, tilted ~15° on a Y-axis
for "visual interest." All four features sit in identical cards in a 4-up row.

**L3 visuals:** Hero is a zoomed-in fragment of the dashboard — just the
chart that matters, with the rest cropped out. Features sit in a bento with
varied sizes. Vertical framing lines extend the length of the page.

**L4 visuals:** Hero is a purpose-built screen that demonstrates one specific
moment of the product working. Layout is asymmetric. On hover, the feature
multi-select blurs the items you're not on. The mega menu slides content
left/right instead of closing/opening.

**L1 copy:**
> "Track your links with Linkd for better results. With Linkd you can track
> clicks to links, revenue attribution, filter bots, A/B route traffic. You
> can also connect custom domain names and password protect any page you
> wish with just one setting!"

**L2 copy:**
> "The smarter way to share links. Real-time click tracking, revenue
> attribution, bot filtering, and A/B routing — everything you need to
> understand every link you share."

**L3 copy:**
> "Know where every click goes. Your links are working. Find out how."

**L4 copy:**
> "Every click tells a story. Real-time data that turns link activity into
> decisions."

The L3→L4 move there is the difference between *what the product does*
("collecting and analyzing data quickly") and *what it gives you* ("decisions").

## Relationship to sibling skills

- **`/design-audit`** — judges whether the page converts cold traffic. A page
  can be L2 craft and convert; a page can be L4 craft and not convert. Use
  `/design-audit` for CRO, this skill for craft.
- **`/taste`** — rates visual taste against Linear/Stripe/Things etc. Use
  `/taste` for "is this generic," this skill for "what's the next concrete
  upgrade I should ship."
- **`/code-review`** — reviews the implementation. Use after the user picks
  an upgrade to ship and writes the code.

## Failure modes

- **URL only, no Playwright** → grade visuals/layout/typography/copy from
  static screenshot + HTML. Mark animation, page flow, and any hover-dependent
  axes as ungraded in "What I couldn't grade."
- **Source only, no rendered page** → grade copy and structure. Mark every
  visual axis as ungraded.
- **User pushes back on a level call** → re-quote evidence. If the page
  actually does the L4 thing in some other section, update the call. Do not
  capitulate to flatter.

## Security & Permissions

- Fetches the URL the user provides (read-only, no login).
- Reads local files the user provides.
- Does not write files unless the user explicitly asks for the report saved.
- Does not call external APIs beyond `WebFetch` for the page being upgraded.
