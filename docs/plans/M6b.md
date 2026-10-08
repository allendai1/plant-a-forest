# M6b. The lobby, after the style reference

Status: **done 2026-10-06.**

## 1. Goal

Rebuild the hub (now about 180 studs in radius) to look like the style reference: a magical Ancient Tree with glowing glyphs and vines, a garden ring around its roots with the shop close to the trunk, a round stone plaza with dedicated places for training, the seed rack and the spawn, and wooden fences with lanterns all around, open where the trails lead out into the forest.

Done when: the lobby matches the layout below in Studio, every station, the rack and the shop stand still work, and the frame rate with a full forest stays where it was.

## 2. Layout (top-down, radii from the hub center)

```text
                  fence + lanterns (r ~172), openings at the 6 trails
            .-----------/   \-----------.
          /   TRAINING:     |     TRAINING:   \
         /    benches       |     treadmills   \      <- plaza districts
        |      (5 in an arc)|     (5 in an arc) |        between the trails
   trail ---- stone plaza (r 85-165) ---------- trail
        |   .------- root garden (r 30-80) ------.   |
        |  | flowers, stones, crystals, low walls |  |
        |  |       TRUNK  (glyphs + vines)        |  |
        |  |   [SHOP altar + 3 crystal stands]    |  |
        |   '--------------------------------------'   |
         \    SPAWN + seed rack    |   gift board /  /
          \   (faces the forest)   |   decoration   /
            '-----------\   /-----------'
                       trail
```

- **The tree:** three large glowing glyphs on the trunk (a swirl, a leaf and a drop, like the reference), cyan Neon, plus vines winding up the trunk and along the main branches. They're part of each of the 4 Ancient Tree models, so they grow with the tree, and they brighten at the forest complete moment.
- **Root garden (r 30–80):** flower beds, rocks and low stone walls in a ring around the roots, with gaps so you can walk in. The glowing rune circle (the Ancient Spring) stays here.
- **The shop:** a stone altar with a glowing leaf glyph, right in front of the trunk and facing the spawn, with **3 crystal stands**, one per upgrade (Bulk Pickup, Bulk Plant, Planting Range). In M6b the altar has a "Shop" prompt that says "Coming soon"; M7 opens the real shop there.
- **Stone plaza (r 85–165):** a ring of stone paving with lantern posts. The six trails split it into six districts:
  - **Spawn and seed rack** (the district facing the first forest section): the spawn faces the forest, and the rack (the pile of giant acorns) sits just beside it.
  - **Training, benches:** the 5 bench presses in an arc, 1x to 25x left to right, each on a small stone pad with its multiplier on a sign.
  - **Training, treadmills:** the 5 treadmills the same way in the next district.
  - **Gift board / quests** (M10), and the remaining districts as decoration (flowers, rocks, benches to sit on).
- **Fence ring (r ~172):** low wooden fence sections between stone pillars with lanterns on top, like the reference, with an opening at each of the 6 trails flanked by two taller lantern pillars.
- **The trails:** the six plank walkways become stone paths like the reference, with lantern posts along both sides every ~45 studs. Their `NoPlant` parts stay as they are, so the plots don't change.

## 3. How it's built

| Piece | Made in | Notes |
| --- | --- | --- |
| Glyphs and vines on the tree | Blender (`tools/blender/build_assets.py`, added to `Ancient1–4`) | New `AncientN_Glyphs` (Neon) and `AncientN_Vines` MeshParts per model; AncientTreeController treats the glyphs like the glow parts (brighter when awakened) |
| Root garden, shop altar, crystal stands, fence section, lantern pillar, lantern post, stone path segment, plaza ring | Blender, same script, a new `Lobby` collection | Low-poly, flat-shaded, the same palette as the trees |
| Getting them into Studio | **Open Cloud** (your key has asset write) | I export each piece as FBX, upload it as a Model asset, and insert it with the Studio connection into `ReplicatedStorage.Assets.Lobby`. If the upload route fails, you import the FBX by hand like before. |
| Placement | `tools/build_lobby.luau`, run once through the Studio connection | Places every piece in `Workspace.Map.Lobby` from the hub center and the walkway angles: fences, pillars, lanterns, plaza, paths. Moves the existing stations, rack and spawn into their districts. Re-runnable, so the layout can be tweaked and rebuilt. The place then needs saving. |

**Code changes are small:** the spring radius may change to match the new rune circle, AncientTreeController brightens the glyphs when awakened, and the shop altar gets a "Coming soon" prompt (a Studio-placed ProximityPrompt; M7 hooks it up). Stations and the rack are found by their tags, so moving them needs no code.

**Performance:** lanterns use glowing Neon parts, with real lights only on the 12 trail-entrance pillars and the shop. There's roughly one MeshPart per fence section, about 150 parts for the whole lobby.

## 4. Decisions

1. **Seed racks at the tree:** six acorn piles around the roots, one facing each plaza district, so seeds can be grabbed from any direction. The first forest section is now the one in front of the spawn.
2. **One shop:** a single altar in front of the trunk. Stepping into the glowing ring in front of it opens one panel with the three upgrades, like the pyramid's shop circle.
3. **Training:** like the pyramid's gym, each tier's bench and treadmill share a pad in the tier's color (gray 1x, yellow 2x, cyan 5x, purple 10x, orange 25x). The pads fill two neighboring districts across the plaza from the spawn's side: 1x, 2x and 5x in one, 10x and 25x in the next.
4. **Stone trails** with lanterns replace the plank walkways.
5. **The acorn** (asked for during the build): a Blender acorn is the giant seed over your head and fills the seed rack piles.

## 5. Test plan

1. Screenshots from above and at player height, compared with the reference.
2. Walk the lobby: every fence opening lines up with a trail, nothing blocks the way from the spawn to the rack, the stations and the forest, and the character doesn't snag on roots or walls.
3. Every bench, treadmill and the rack still work in their new places, and the spring still trains inside the rune circle.
4. The frame rate with a full forest (`Fill forest`) is the same as before the lobby (60 fps in Studio).
5. The shop altar's prompt shows "Coming soon".

## What changed from the plan

- **Training pads instead of an arc of separate stations:** your reference from Build the Pyramid. Each tier's bench and treadmill are low-poly Blender models whose frame, plates and glow strips take the tier color. They sit on a pad with a tinted floor and a glowing Neon outline. The effects build up with the tier: a plain gray outline at 1x, a Neon outline from 2x, sparkles from 5x, rising light motes from 10x, and embers plus a light at 25x. Each pad has a "5x / 3 forests or game pass" label.
- **The shop ring** (your second reference): a glowing ring in front of the altar. `ShopController` opens the shop panel while you stand in it. Buying comes in M7, so the three upgrades say "Coming soon".
- **The fence is at 150 studs, not 172:** the hub's edge is a hexagon, and ring-7 tiles reach to about 154 studs from the center between the trails. The plaza runs from 89 to 146.
- **The Ancient Tree's old trunk streaks were removed:** they clashed with the glyphs. The glowing root veins and canopy orbs stay.
- **Meshes go to Studio through Open Cloud:** the FBX is uploaded as a Model asset and loaded with `InsertService`, so nothing has to be imported by hand. The steps are in `docs/HANDOFF.md`.

**Verified in Studio (one player, through the Studio connection):**
- Screenshots: the full-grown tree with glyphs and vines over the plaza, garden ring, rune circle, fence, trails, acorn piles, shop and training pads. Close-ups of the shop with its ring, and of the pads.
- **Seed racks:** holding E (real key press) at a pile away from the spawn filled the player to capacity. The giant seed over the head is the new acorn.
- **Shop:** standing in the ring opened the panel; stepping out closed it.
- **Training:**
  - The 2x treadmill trained Speed (+16 in 2.5 s).
  - The 5x bench prompt (real E press) started benching (+40 Strength in 2 s), and the plates moved with the lifting bar.
- **Spawn and first section:** the player spawned at 29°, and the first open row is in front of the spawn (3° to 57°).
- **Performance:** 60 fps with a 99% forest and the lobby (142 parts).
- StyLua, Selene and luau-lsp pass.

**Not verified:**
- Walking the whole lobby by hand: snagging on roots or walls, and getting through every fence opening.
- A phone.
- Two players.

**Place changes to save:**
- `Workspace.Map.Lobby`; the moved stations, spawn and grass; the six racks (the old rack was removed)
- `ReplicatedStorage.Assets.Lobby` and `Assets.Acorn`; the new pieces in `Assets.AncientTree`
- the synced scripts (new: `ShopController`)

## Fixes after M6b (2026-10-06)

- **Treadmill arrows:** every treadmill belt now has the scrolling arrow Beam from your `TreadmillGold` model (texture 10249261576, 50% transparent, `TextureSpeed` −3). It runs from the back of the belt to the console, sized to our narrower belt with the same proportions. `tools/build_lobby.luau` copies it once into `ReplicatedStorage.Assets.Lobby.TreadmillArrows`, so `TreadmillGold` can be removed. Note that its `GamepassTreadmill` script trains anyone who touches it in play mode.
- **Bench seat:** turned around, so players sit facing away from the bar. Verified with a real E press on the 5x bench: benching works and the character faces away from the bar (screenshot).
- **Signs:** the six acorn piles say "SEEDS", and the shop altar has a matching "UPGRADES" sign (cyan, like the altar's glow). The shop panel's title is "Upgrades".
- **Guide arrow:** the three-bar ground arrow (it read as a "Y") is replaced by a blue, glowing, scrolling arrow beam. It uses the treadmills' arrow texture and runs along the ground from your feet all the way to the nearest open plot, with the ▼ marker kept above the plot. It's set up like the treadmill arrows, with the plot as `Attachment0`, so the chevrons point and scroll toward the plot the way the treadmill arrows point and scroll toward the back of the belt. Verified: with seeds in the hub, the beam showed from the player to the open row and the old arrow was gone. A playtester followed it and planted 10 seeds.
- **No more falling into cracks:** `tools/build_lobby.luau` adds `Workspace.Map.WalkFloor`, one invisible part just under the tile tops (top at 1.55) that covers the whole map, with the plaza cut out. It's a union of two discs with precise collision, so the plaza stays at its own height. The stone trails were raised to tile level to match. The floor is tagged `WalkFloor` so ForestService's tile-height raycasts skip it; without that, every tile came out 1.15 studs too high. Verified: a character stands at the same height on a tile, on the seam between two tiles, in the gap beside a trail and on a trail (4.7 to 4.73), and on the plaza as before. The dirt gaps beside the trails are still visible, just walkable now; they can be covered visually in the art pass.
