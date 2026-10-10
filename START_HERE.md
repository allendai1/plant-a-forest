> **Update 2026-10-06:** the project is past M4 and no longer uses Rojo or git. For the current state and workflow, read [docs/HANDOFF.md](docs/HANDOFF.md). The setup steps below are from the original handoff.

# Starting Plant the Forest in Claude Code

## What's in this folder

| File | What it is |
| --- | --- |
| [CLAUDE.md](CLAUDE.md) | Project context and rules. Claude Code reads this automatically every session. |
| [docs/GDD.md](docs/GDD.md) | The full game design doc, exported from the live doc. |
| [docs/MVP_PLAN.md](docs/MVP_PLAN.md) | Build order, milestone by milestone, with checkboxes and "done when" tests. |
| `docs/Balancing.xlsx` | The balancing spreadsheet (stat curves, forest sizes, upgrade costs). |
| `src/shared/GameConfig.luau` | Every balance number and the stat formulas, ready to use in game code. |
| `src/shared/HexGrid.luau` | Hex grid math (rings, world positions, distances). |

`GameConfig` and `HexGrid` have been checked: the formulas reproduce all 9 recorded Build the Pyramid capacity readings, and the grid gives 3,276 forest hexes for tier 1 before paths and the stream.

## Setup

1. Put this folder where you keep your projects and open a terminal in it.
2. Optional: run `git init` so Claude Code can commit as it goes.
3. Start Claude Code in the folder (`claude`).
4. If you have the `roblox-dev` plugin, run `/roblox-dev:setup` first so it scaffolds Rojo, linting and CI around these files.
5. Open Roblox Studio with the Rojo plugin (or the Roblox Studio MCP connection) so changes can be tested live.

## How each step works

CLAUDE.md tells Claude Code to plan before it builds, so every step follows the same rhythm:

1. You ask it to plan a milestone.
2. It writes the plan to `docs/plans/` and stops.
3. You read the plan, ask for changes or approve it.
4. It builds, tests, ticks the boxes in [docs/MVP_PLAN.md](docs/MVP_PLAN.md), and stops again.
5. You run the milestone's "Done when" test in Studio, then ask for the next plan.

## First message to paste

> Read CLAUDE.md, docs/GDD.md and docs/MVP_PLAN.md, then write docs/ARCHITECTURE.md as described in CLAUDE.md. Keep src/shared/GameConfig.luau and src/shared/HexGrid.luau as they are. Stop when it's written so I can review it.

## Messages for each milestone after that

> Plan M0.

Once you've read the plan:

> Approved, go ahead.

or

> Change this before you start: ...

When a milestone is done and you've tested it in Studio:

> M0 works. Plan M1.

## When the design changes

The live design doc is the master copy. If you change the design there, re-export it to [docs/GDD.md](docs/GDD.md) (or tell Claude Code what changed) so the two don't drift apart. Balance changes go in `GameConfig.luau` and the spreadsheet together.
