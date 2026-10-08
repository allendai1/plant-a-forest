# Tree stages: from 4 models to 8

## Goal

Make a tree change shape far more often, especially early on. Today a tree is the same model for 11 seeds at a time (seeds 1–11, then 12–22, then 23–43, then 44). With 8 stages packed toward the start, a new player sees a new shape on almost every early press. The full-grown tree stays exactly as it is now.

## What the player sees

Each stage change already "pops" the new model in. New in this plan:
- **Leaf puff:** a small one at the tree on each stage change. The leaf burst at full grown stays.
- **Rising note:** a soft "pop" note, a little higher each stage. It only plays for your own seeds, so 50 players don't make a din.

| Stage | Starts at seed (of 44) | Leafy tree | Pine |
| --- | --- | --- | --- |
| 1 Seedling | 1 | a tiny stem with 2 leaves | a tiny green tuft |
| 2 Sprout | 3 | a taller stem, 4 leaves | a stem with a small cone |
| 3 Sapling | 6 | a thin trunk with one leaf clump | a thin trunk, 2 needle tiers |
| 4 Small tree | 10 | trunk and 3 clumps | 3 tiers |
| 5 Young tree | 16 | first branches, 4 clumps, root flare | 3 bigger tiers, root flare |
| 6 Growing tree | 24 | 5 clumps | 4 tiers |
| 7 Mature tree | 33 | 7 clumps, nearly full size | 5 tiers, nearly full size |
| 8 Full grown | 44 (the last seed) | today's full-grown leafy tree, unchanged | today's full-grown pine, unchanged |

- **Sizes:** they climb about 6%, 10%, 18%, 28%, 42%, 58%, 78% and 100% of full height. Between stage changes, each seed still makes the tree a little bigger (80% → 100% of its current model), so it grows on every press.
- **Proportions:** the stage starts are stored as fractions of a tree's seeds (0, 5%, 12%, 21%, 35%, 53%, 74%, 100%), so they still work for tier 2's different seed count.

## Files

| File | Change |
| --- | --- |
| `tools/blender/build_assets.py` | `leafy(stage)` and `pine(stage)` build 8 stages (shapes in the table above). Stage 8 is today's stage 4, built by the same code so it doesn't change. `STAGES = 1..8`. |
| `src/shared/GameConfig.luau` | `Growth.StageStarts` (the 8 fractions) replaces `SproutUpTo` / `SaplingUpTo`; `growthStage` returns 0–8 from it; `Growth.Stages = 8`. |
| `src/client/Controllers/ForestController.luau` | **Stage change:** a new stage's model pops in from the previous model's size, not from half its own. With models this close in size, popping from half would make the tree shrink and then grow. It also gets the leaf puff and, for your own seeds, the rising note. **Full grown:** checked as "the last stage" instead of 4. |
| `tools/build_map.luau` | **Importing:** imported `Leafy1–8` / `Pine1–8` go into `Assets.Trees`, with the bark, leaf and needle colors the current trees use. Today the import would drop them in the Lobby folder. **Islets:** the decorative trees there use the full-grown `Leafy8` / `Pine8`. |
| `ReplicatedStorage.Assets.Trees` | the old `Leafy1–4` / `Pine1–4` are replaced by `Leafy1–8` / `Pine1–8` |
| `CLAUDE.md`, `docs/DESIGN_CHANGES.md` | "4 model stages" becomes 8, with the stage table |

No server changes, no remotes, no saved data. The server only counts seeds; clients pick the model.

## Steps

1. **Models:** build the 16 models in Blender and **send you a lineup picture of all 8 stages of each tree before anything goes into the game.**
2. **Into the game:** after your OK, upload with Open Cloud, import, update the code, and sync.
3. **Test in Studio:**
   - **Every stage:** plant a tree seed by seed and check each stage shows at the right seed, with the pop, the puff and the note.
   - **Speed:** fill a whole forest with the test panel and check the frame rate.
   - **Islets:** check their trees still look the same.

## Open questions (my defaults in brackets)

1. **Stage starts.** [seeds 1, 3, 6, 10, 16, 24, 33, 44 of 44]
2. **The rising note on stage changes.** It reuses the full-grown chime at a lower volume; you can turn it off later. [yes, your own seeds only]
3. **Performance.** Twice as many stage swaps per forest: about 4,300 model swaps over a whole forest instead of about 2,200, spread over the ~12 minutes. That should be fine, and M12 will measure it.
4. **Spreadsheet.** `docs/Balancing.xlsx` lists 4 stages and needs the new table by hand.

## What changed from the plan (2026-10-06, built)

- **Bigger early stages:** in the game, stages 1–2 were no taller than a planted tile's grass tufts (about 1.9 studs), so the seedling was hard to see. With the user's OK, stages 1–5 are scaled up (same shapes, `STAGE_BOOST` in `build_assets.py`).
  - Leafy is now 4.6, 7.1, 10.1, 14, 18.9, 23.6, 31.6 and 41.8 studs tall.
  - Pine is now 4.1, 6.5, 9.4, 13.5, 18, 22.7, 35 and 44.8.
  - Stages 6–8 are unchanged, and stage 8 is today's full-grown tree, checked mesh for mesh.
- **Detecting your own seeds:** HexBatch doesn't say who planted. So "your own seeds" means: your Carried count dropped in the last 0.6 s and the tree is within 60 studs of you.
- **The Ancient Tree:** keeps its 4 stages; `build_all` builds it in its own loop.
- **The training pad signs** (asked for mid-build): "Requirements: N" with the user's tree icon instead of "N forests or game pass". The 1x pad still says Free.
- **Assets:** the trees are asset 108405905129987, imported into `Assets.Trees`. The map script now files imported `Leafy#` / `Pine#` models there with their colors.

**Verified in Studio, one player:**
- **Stage changes:** planting one tree a seed at a time (Bulk Plant 0) changed the model at seeds 1, 3, 6, 10, 16, 24, 33 and 44 (Pine1 to Pine8). The leaf puffs showed.
- **The note:** it played on your own stage changes, at pitches 0.83, 0.91 and 0.99 and volume 0.25.
- **With Bulk Plant 2:** 4 seeds per press, and the model still lands on the right stage.
- **Speed:** with 539 full-grown trees, 60 fps at automatic graphics quality. While filling, it dipped to 29 fps with one 190 ms frame, because the test panel fills the whole forest at once.

**Not verified:** hearing the note by ear; the stage pop as another player sees it.
