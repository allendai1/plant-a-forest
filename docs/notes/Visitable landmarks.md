# Visitable landmarks (future feature, saved 2026-10-10)

The user's idea: let players, especially fast ones, explore to the real landmarks labelled around the map ([Grand Canyon game](Grand%20Canyon%20game.md), `tools/build_landmarks.luau`). Saved for after launch, not built.

## The plan

1. **Vulcan's Throne first:** the real cinder cone about 4,300 studs from camp on the same plateau (3279, -2695), its top about 380 studs over the rim. Players walk out across the desert and climb it. Add a summit reward: a badge, a one-time coin chest and maybe a lookout over the bridge.
2. **The Lava Falls Trail later:** the real trail starts at the foot of Vulcan's Throne and drops to Lava Falls on the river at (-535, -5985), about 2,300 studs down. A winding trail carved down the canyon wall, a reward by the rapid.
3. **Mount Trumbull:** the real mountain is about 50,000 studs off at the map's scale. It could become its own place if the game goes to several canyons as separate places.

The Lava Falls and Mount Trumbull labels were taken down on 2026-10-10 (they implied players could go there). Bring them back with the visits: Lava Falls was a label at (-535, 260, -5985) with a glowing line down to the river, and Mount Trumbull a dark flattened-sphere silhouette 12,000 studs from camp toward (49,356, 15,261), its label over the top.

## What it takes

- **Walkable ground:** the landmarks are in the far scenery, which has no collision. Add real terrain around them and the trail with the same height function (`tools/canyon_heightmap.py Canyon.heights` over a wider area, `tools/canyon_terrain.luau`), so it matches the scenery exactly.
- **The edge:** move the boundary walls out (`GameConfig.Boundary`, `tools/build_boundary.luau`) to take them in.
- **Speed is the reward:** at 32 studs/s Vulcan's Throne is over 2 minutes away; at 300+ it's about 15 seconds.
- **Cost:** moderate work. Vulcan's Throne adds maybe a fifth to the terrain, the trail a bit more. Barely any cost in play (terrain streams in near the player), but the place file grows, so saving and publishing slow down.
