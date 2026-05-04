# supabuild-extras

Optional companion plugin to [`supabuild`](../supabuild). Ships specialist
agents that the core `/supabuild` build / design / linear / github flows
don't reach for in normal use:

- `marketing/` — content, social, ASO, SEO, growth, podcast, ecommerce specialists
- `sales/` — discovery, pipeline, outbound, deal, sales engineering specialists
- `paid-media/` — PPC, search, programmatic, paid-social, tracking specialists
- `spatial-computing/` — visionOS, macOS Metal, WebXR, XR cockpit specialists
- `game-development/` — Unity / Unreal / Roblox / Godot specialists
- `support/` — analytics, finance, infrastructure, legal, support specialists
- `project-management/` — sprint, project, studio operations specialists
- `strategy/` — coordination, playbook, runbook, executive-brief docs

## Why a separate plugin

Every agent in the roster takes up context space in every parent
session — its `description` line is loaded so the Team Lead can pick
from it. Splitting these out means the core supabuild plugin only pays
context for agents the build flow actually uses, while keeping these
available for users who want them.

## Install

If you want these specialists available in the Team Lead's roster:

```bash
claude plugin install supabuild-extras@supabuild
```

Otherwise leave it uninstalled — `/supabuild` works fine without it.

## License

MIT
