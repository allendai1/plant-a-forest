# Worlds and future trees (planning, 2026-10-07)

## World 3: Great Smoky Mountains (autumn): the user's pick

Fall colors, so it also suits Halloween events.

| Piece | State |
| --- | --- |
| **Maple** (Common): grey-brown trunk, a full round crown of orange, red and gold clumps | modeled, 8 stages |
| **Birch** (Common): 1–3 slender white trunks with dark bark marks, an airy golden crown | modeled, 8 stages |
| **Giant maple World Tree** (`AncientMaple1-4`): a stout buttressed trunk, a huge fall-colored crown, amber root veins and lantern orbs | modeled, 4 stages |

- **Images:** `autumn_lineup.png` (all 8 stages), `autumn_maple_birch.png`, `autumn_world_tree.png`.
- **Where they come from:** Blender `maple()`, `birch()`, `ancient_maple()`, uploaded as asset 83839494816907.
- **In Studio:** `tools/build_map.luau` put `Maple1-8` and `Birch1-8` in `Assets.Trees` and `AncientMaple1-4` in `Assets.AncientTree`, with their colors.

**In the game since 2026-10-07:**
- **Species:** `Maple` and `Birch` are added at the end of `Trees.Species`.
- **World:** `GameConfig.Tiers[3]`, "Great Smoky Mountains", 3x coins, `WorldTree = "AncientMaple"`.
- **Roulette weights (the user's pick):** Sherwood 60, Kyoto 30, Smoky Mountains 10.
- **World Tree look:** AncientTreeController's `VARIANT_LOOK.AncientMaple` gives an amber glow and label, falling orange and red leaves, and amber sparkles. Petal colors are now set per world.
- **Roulette:** the card is orange.
- **Verified in a playtest:**
  - `setTier 3` showed Maple and Birch trees, the AncientMaple World Tree with its leaf emitter, and the label "Great Smoky Mountains · 3x coins".
  - The odds came out to 6000/3000/1000 in 10,000 rolls.
- **Not done:** warmer autumn lighting (optional).

## Future seed-shop trees (when the seed shop returns)

| Rarity | Ideas |
| --- | --- |
| Uncommon | Maple and Birch seeds (special versions with a boost) |
| Rare | Weeping Willow, Ginkgo |
| Epic | Jacaranda (purple, falling petals), Baobab |
| Legendary | Rainbow Eucalyptus, Dragon's Blood Tree |

Add 1–2 per update rather than all at once.

## Later, not urgent: a bigger map (more rings)

- **The gameplay side is one setting:** `GameConfig.Grid.ForestRings` (9 today: rings 7–15, 540 plots). The server and client build plots, sections, rows and the target from it.
- **The work:**
  - the island, trails, walkways, walk plate and edge decor (cliffs, waterfalls, islets, bridges) regenerated at the new size
  - performance: twice the trees needs the M12 work first, measured on phones

| Rings | Plots | Target at 100/tree | Furthest walk |
| --- | --- | --- | --- |
| 15 (now) | 540 | 54,000 | ~415 studs |
| 20 | 1,050 | 105,000 | ~555 studs |
| 25 | 1,710 | 171,000 (Build the Pyramid's size) | ~690 studs |

- **A bigger map in one world only:** the island would be built at the largest size, with the outer rings unused elsewhere.
- **The cheaper way to make a world harder:** more acorns per tree in that world. The client still assumes one size for every world (`Tiers[1].SeedsPerHex` in ForestController and TargetController), which is a small fix to do first.
