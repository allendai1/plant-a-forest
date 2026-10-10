# Plant the Forest — Game Design Doc

Exported 2026-10-06 from the live design doc, then edited directly here on 2026-10-06 for the giant sequoia redesign (see [docs/DESIGN_CHANGES.md](DESIGN_CHANGES.md)). This file is now the master copy.

## Concept and pitch

**Pitch:** The whole server works together to plant a forest of big trees, one giant seed per trip. Every seed fills the server's Forest Bar and visibly grows a tree, while a colossal Ancient Tree rises in the middle of the map.

It takes the two things players love from two hit formats and joins them:

- **From Build the Pyramid:** a shared goal the whole server sees, discrete slots to fill (forest plots instead of block spots), and stats that make each trip bigger.
- **From garden games:** weather events and mutations, with seed rarities planned for a later update.

**What makes it different:** the thing you build is alive. Every seed visibly grows a tree, and a wall of giant trees closes in, ring by ring, on the Ancient Tree at the center.

**Audience:** Roblox players around 9 to 15 who like co-op simulator and incremental games. Sessions should feel rewarding in 10 minutes and keep pulling players back for weeks.

## Core gameplay loop

*[Diagram in the online doc: Grab seeds at the rack → carry to the forest → plant in a hex → tree grows a stage → Forest Bar rises (seeds and coins) → train and buy upgrades → repeat with bigger loads. When the bar fills → Forest Awakening → next tier.]*

Each trip pours a load of seeds into whichever open trees are closest to you. Training raises your stats and coins buy upgrades, so each lap of the loop carries more than the last, until the full bar triggers the Forest Awakening.

## Forest layout

The forest is a grid of large hexagonal plots, one big tree per plot. The Forest Bar counts seeds delivered, and its target is a fixed number per tier: every plot times the tier's seeds per hex. It doesn't change with how many players are in the server. When the bar completes, every tree is full grown.

- **Visible hex tiles.** Like the block spots of a pyramid, every plot is a visible hex tile on the forest floor, about 32 studs across, so a missing tree is always obvious. A tile shows its state at a glance: **locked** tiles are dark; **open, empty** tiles are bright with a glowing rim and a soft pulse; **started** tiles turn mossy and keep the glowing rim until the tree is full grown; **finished** tiles are mossy under their tree. Each tree sits slightly off its tile's center with random rotation and size, so the forest still looks natural.
- **Plant where you stand.** Like placing a block anywhere open in the pyramid, you can plant in any open hex in the open row: an empty tile or an unfinished tree. Press E (the X button on a gamepad; on mobile, tap anywhere on the game view or the plant button) and your seeds go into the targeted hex, which is the open hex closest to you within your planting range. On PC you can point at a different hex in range instead. Mobile has no picking on purpose: the nearest open tile is chosen for you, because players just want to see the numbers go up. If a press would overfill that tree (possible once Bulk Plant puts several seeds in per press), the extra seeds go into the open hex closest to you. Holding E (or the plant button) keeps planting. The hex tiles are solid, so you walk on top of them.

   **Target indicator.** The targeted tile gets a bright hex-shaped outline and a small floating meter showing its progress (for example 12 / 44 seeds). The outline turns gold when your next press will finish the tree. Only your own target is shown, so busy areas stay readable. If no open hex is in range, nothing is highlighted and the plant button dims.

   **Arrow to the nearest open plot.** Whenever you're carrying seeds and no open plot is in range, a glowing arrow points to the nearest one, so a trip never turns into a search.
- **Sections fill one at a time, row by row from the outside in.** The six walkways split the forest into six wedge-shaped sections of 90 plots. Only one row is open at a time: one section's plots in one ring. The section next to the seed rack goes first, starting with its outer row (14 plots) and closing in on the hub row by row (13, 12 ... 6 plots). The next row opens only when every tree in the current one is full grown. When a section is full, the next section around the hub opens at its outer edge. Small rows mean a quick win every few trees, and a whole section of forest finished is a big, visible success early in every forest.
- **Row complete moment.** When a row's last tree finishes, a quick wave of sways and bounces runs along it with a golden sweep, a chime plays and the next row's rims light up one after another.
- **Section complete moment.** When a section's last tree finishes, the wave runs over the whole section from its outer edge to the hub: each tree sways and bounces while a golden light sweeps across the tiles and leaves burst, then a chime rises, the next section's first row lights up, the Ancient Tree shakes, the Forest Bar pulses and a banner reads "Section 2 of 6 complete!" (Bonuses for finishing a section are in the backlog.)
- **One tree per hex.** Every tree takes exactly one hex, rare or not.

## Map layout

Both forest tiers use the same map and the same hex grid; only the theme changes. The map is a central clearing with the Ancient Tree, surrounded by 9 rings of tree plots. The outer rings are planted first, so each forest starts with the longest trips and they shorten as the forest closes in. That makes Speed most valuable early in every forest.

- **Hub (the lobby):** about 180 studs in radius (hex rings 0 to 6 are left empty; enlarged 2026-10-06) around the Ancient Tree. The tree's roots reach 72 studs, which leaves a band about 100 studs wide for the spawn, the seed rack (a pile of giant acorns), the training stations, the upgrade shop and the gift board, set between the walkways and decorated to fit the mystical-forest theme. The spawn faces the forest. The lobby (M6b, after the style reference): glowing glyphs and vines on the Ancient Tree's trunk, a garden ring of flowers and low stone walls around the roots (with the Ancient Spring's rune circle), a round stone plaza, and a wooden fence with lantern pillars, open where the six stone trails lead out into the forest. Six piles of giant acorns (the seed racks) stand around the roots, one facing each part of the plaza, so seeds can be grabbed from any direction. The shop is a stone altar right in front of the trunk; stepping into the glowing ring in front of it opens the shop. Each training tier's bench press and treadmill share a pad in the tier's color with a glowing outline, and the higher tiers add sparkles, rising light and embers.
- **Forest:** 9 plantable rings (rings 7 to 15) around the hub, 540 plots in all (594 hexes minus the 54 under the walkways), with tree centers about 27.7 studs apart. The outermost ring is about 12 seconds' walk from the spawn at the starting walk speed of 32 studs per second; the innermost is about 3 seconds.
- **Walkways:** six straight wooden walkways with lanterns run out from the hub to the island's edge, along the grid's three natural lines through the center (like spokes). Each takes the corner hexes of every ring it crosses, 66 plots in all; those hexes are blocked by tagging the walkway parts `NoPlant`. There are no ring-shaped walkways.
- **Edges:** the forest sits on a floating island; cliffs drop away at its edge, with waterfalls and small floating islets around it.

## First-time experience

A new player should plant their first tree within 20 seconds and understand the whole loop within 2 minutes, without reading a single wall of text. Guidance is a glowing arrow plus one short prompt at a time, and nothing ever blocks planting.

1. **0:00, spawn.** The player appears in the hub next to the Ancient Tree, facing the forest. The Forest Bar is at the top of the screen and other players are hauling giant seeds past them. An arrow points to the seed rack, a pile of giant acorns in the next clearing over (about 3 seconds' walk). Prompt: "Grab a seed."
2. **0:05, first seed.** Press E (or tap) at the rack and an acorn pops up over their head. The arrow points to the nearest glowing tile. Prompt: "Plant it in the forest."
3. **0:15, first seed planted.** Press E at the tile. A sprout (or the next growth step of a tree someone else started) bounces up, the tile turns mossy, the Forest Bar ticks up, and a +1 coin pops out. Each section starts at the forest's outer edge, about 12 seconds' walk, so the first plant can take up to about 20 seconds.
4. **0:30, repeat.** The tutorial prompts fade after the first plant; the arrow keeps pointing to the nearest open plot whenever none is in range. After the third plant, it points to the Training Grove. Prompt: "Get stronger to carry more."
5. **1:00, first upgrade.** Capacity rises fast at first: about 1 second on the bench press doubles it to 2 seeds, and about 12 seconds gets it to 6. The giant seed visibly grows, which teaches the core progression in one moment.
6. **1:30, the bigger picture.** A short popup shows the free gift (like, favorite and join the group for 500 coins, given once). The upgrade shop pulses once.
7. **2:00, hand-off.** The tutorial ends. (A quest list was planned here; it's postponed, see [docs/plans/M10.md](plans/M10.md).) After the training step, the arrow leads to the shop once you have 50 coins and no upgrades yet. The fence around the plaza only opens at the trails, so the arrow routes through the nearest gate.

Players who join mid-forest get the same flow. Returning players skip it, but the quest list continues where they left off.

## Player stats and progression

Two stats drive every trip, and both come only from training. Strength is the headline stat, because what you carry is what other players see.

| Stat | What it does | How you train it |
| --- | --- | --- |
| Strength | Seeds carried per trip, and how big your giant seed looks | Bench press in the Training Grove |
| Speed | Walk speed between the hub and the forest | Treadmill in the Training Grove |

**Training: press once, then it's automatic.** At a bench press, press E (or tap the button on mobile) to sit down and start benching; Strength keeps rising until you jump off. Stepping onto a treadmill starts your character running in place, and Speed rises while you're on it. Either way it's one rep every 0.25 seconds, worth +1 at 1x, so 4 per second (ticked by the server). These match measurements from Build the Pyramid (about 10 in 2.5 seconds at 1x; 100 in 13 seconds at 2x). AFK training is allowed. Any number of players can use the same station: everyone on a bench is seated on it, but each player only sees one person there (themselves if they're on it, otherwise whoever sat down first); treadmill users all run in place, overlapping. Planting never raises stats: the only way to carry more or move faster is to train. The equipment is placeholder for now and can be re-themed to the forest later.

**Carry: a giant seed over your head.** You carry your seeds as one huge seed held overhead, with a number above it showing how many it holds. Strength sets how many you can carry, with a curve fitted to recorded Build the Pyramid stats (it matches all 9 readings exactly):

```latex
\text{Seeds per trip} = \operatorname{round}\left(1 + 19.3 \times \left(\left(1 + \frac{\text{Strength}}{37}\right)^{0.256} - 1\right)\right)
```

It's very generous at first (2 seeds after 7 seconds of training, 6 seeds before the first minute) and heavily compressed later: 63 seeds at 10,000 Strength, 128 at 100,000 and 245 at 1 million. Stat numbers can climb into the millions while capacity stays manageable. The giant seed's look follows how many seeds you're holding right now, so it grows as you fill up at the rack and shrinks as you plant:

| Seeds held | Strength needed to carry that many | How the giant seed looks |
| --- | --- | --- |
| 1 | 0 | An acorn the size of your head |
| 5 | 40 | As big as your whole body |
| 15 | 275 | Twice your height |
| 40 | 2,740 | The size of a car |
| 80 | 21,338 | The size of a house; you wobble under it |
| 150 | 174,599 | Blocks out the sun |
| 250 | 1,079,638 | Casts a shadow over the whole hub |

When you plant, seeds pour from the giant seed into your highlighted hex. Like the pyramid, each press grabs or plants one seed at first, and holding E repeats. The Bulk Pickup and Bulk Plant upgrades raise how many seeds move per press.

**Walk speed** uses the same pyramid-fitted approach, with a soft cap:

```latex
\text{Walk speed} = 32 + 28 \times \frac{\text{Speed}}{\text{Speed} + 230}
```

Players start at 32 studs per second, gain 1 about every 9 Speed at first, reach 46 at 230 Speed and 52 at about 580, then approach 60 without ever reaching it.

**Training multipliers.** The Training Grove has one bench press and one treadmill for each multiplier: 1x, 2x, 5x, 10x, 25x, 50x, 75x and 100x. A station's multiplier makes each rep worth more (+2 per rep on a 2x station); the rep speed stays the same. Stations unlock with forests completed: 2x after 1 forest, 5x after 3, 10x after 8, 25x after 15, 50x after 25, 75x after 50, 100x after 100, and any unlocked station can still be used. Trying a locked station shows how many forests it needs and a popup to unlock that tier now with Robux (a game pass per tier; a pass unlocks only its own tier). You get credit for a forest if you planted at least 50 seeds during it.

## Trees, rarity and seeds

**The seed shop and special trees (built 2026-10-07, [docs/plans/SeedShop.md](plans/SeedShop.md)).** The free acorns grow Common trees only (the leafy tree and the pine). Special trees come from the **seed shop**, a Seeds tab in the altar shop, Grow a Garden style:

- **Restocks every 5 minutes**, with a countdown. Each restock rolls which seeds are in stock and how many, and every server sees the same stock at the same time. Stock counts are per player.
- **Seeds are saved in your seed bag** and used up when planted. Hold one from the bag (the HUD's Seeds button) and press E on an empty plot or an unfinished Common tree in the open row: it becomes that special tree, keeps its acorns, and the special seed counts as one more seed. Up to **3 special seeds per player per forest**.
- **Special trees boost training, not coins.** They still take 44 seeds and pay 1 coin per seed like any tree. Once one is full grown, its owner's training gains go up until the forest resets (the boosts of several trees add up, capped at +300%), and Redwoods and Crystal Trees also boost everyone in the server (added up, capped at 2x). Coins can't scale with a 44-seed tree (strong players fill one in a press) and only buy upgrades, so boosts stay worth having at every level.
- **Big moments:** Epic and Legendary trees show the owner's name over the tree, and everyone gets a banner when one boosts the server, and when an Epic or Legendary seed comes into stock.

| Seed | Rarity | Owner's training | Everyone's training | Price (coins) | In a restock | Stock | Robux |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Palm | Uncommon | +25% | none | 250 | 80% | 1–3 | 19 |
| Cherry Blossom | Rare | +50% | none | 750 | 45% | 1–2 | 49 |
| Redwood | Epic | +100% | +0.25x | 2,000 | 15% | 1 | 99 |
| Crystal Tree | Legendary | +200% | +0.5x | 6,000 | 4% | 1 | 249 |

**Special trees look special.** Each has its own low-poly shape over all 8 stages and its own seed model: a curved palm with coconuts, a pink cherry blossom that drops petals, a tall redwood (about 66 studs, the tallest tree) and a glowing crystal tree that sparkles. Particles only on the Rare and rarer ones.

**Still in the backlog:** more special trees per update, Mythic event trees, lucky bonus-seed drops, tier-exclusive trees, Lucky Soil, a Tree Book, and showing the held seed over your head.

**Instant, staged growth (no watering).** Every seed counts the moment it touches a plot: the Forest Bar ticks up and a coin pops out. The first seed in an empty hex sprouts a sapling, and the tile turns mossy. Each seed after that grows the tree a little more. A hex is complete once it has received its tier's seeds per hex (44 in tier 1; tier 2 to be rescaled, about 115). With 44 seeds, a big tree is a group project: several players usually pour into the same tree.

**Growth stages.** Each species has 4 tree models. The model swaps only when a stage boundary is crossed; in between, every seed still gets its own feedback.

| Stage | Tier 1 (44 seeds per hex) | What it looks like |
| --- | --- | --- |
| Sprout | Seeds 1–11 | A tiny stem with a few leaves |
| Sapling | Seeds 12–22 | A thin trunk with a small top |
| Young tree | Seeds 23–43 | A thicker trunk with a fuller crown |
| Full grown | Seed 44 | The finished tree |

**Art style and species.** Stylized low-poly: faceted shapes, flat shading and a bright palette, with a chunky trunk and root flare. The MVP has two Common species for variety, a round leafy tree (about 42 studs tall and 40 wide full grown) and a pine (about 45 tall and 24 wide), sized so one tree fits about one tile. Both are generated in Blender by `tools/blender/build_assets.py`, split into a few pieces (bark, leaves) so each piece is one recolorable MeshPart.

**The Ancient Tree's look.** The world tree, about 350 studs tall and 380 wide when full grown (8 times a forest tree's height): a thick stylized trunk (about 60 studs wide near the base) with roots spreading to the edge of the hub clearing, branches holding a wide two-tone low-poly umbrella canopy whose underside starts about 200 studs up, above the inner rings, and subtle cyan/green glow: rune streaks spiralling up the trunk, veins along the roots and small glowing orbs under the canopy. It has 4 models (about 55, 125, 230 and 350 studs tall) and scales smoothly between them as the bar fills. A separate hub-sized base never scales: a double glowing rune circle at the roots' edge, crystals, stones, grass and flowers.

- **A bounce per seed:** every seed makes the tree squash down and spring back up, ending slightly bigger. Every press gets instant feedback without needing a new model for every seed.
- **A finishing pop:** the last seed gets a bigger moment: a burst of leaves, a short chime, and the tree settles into its final pose. It also tells nearby players the hex is done.
- **Why 4 models:** far cheaper to build and render than a unique model per seed; the per-seed bounce shows progress in between.

## Procedural trees

Every tree is generated from a species recipe plus a random seed number, so no two trees in the forest look alike.

- **Species recipe:** each species is a set of settings: trunk height and thickness, branch angle, how many times branches split, leaf cluster shape and color. Rare species add extras like glowing leaves, crystal branches or particles. One generator makes every species.
- **Seed number:** when a tree is planted, the server picks a random number and saves only that number with the plot. Every player's device runs the same generator with the same number, so everyone sees the identical tree, and saving costs almost nothing.
- **Built on each player's device:** the server stores species, mutation and seed number. Each client builds the model, which keeps the server light.
- **Growth is the generation:** the 4 growth stages are the generator run at about 25%, 50%, 75% and 100% of the recipe, so each species' sprout, sapling and young tree match its final shape.
- **Mutations change the look:** Wet trees drip, Frozen trees get ice, Shocked trees crackle, Cosmic trees float sparkles, Golden trees turn gold.
- **Performance budget:** a forest has about 540 trees, so each one can be more detailed than before, but keep it to a few MeshParts per tree (the low-poly meshes from Blender), particles only on Rare and above, and StreamingEnabled on. Test with a full forest early.
- **Fallback:** if procedural trees are too heavy, use 3 to 5 hand-made models per species with random rotation, size and leaf tint.

## Mutations and weather events

A weather event hits the server about every 10 minutes and lasts 2 to 3 minutes. Trees started during an event have a chance to mutate, which multiplies the coins earned by everyone who feeds them seeds.

| Event | How it looks | Mutation | Multiplier | Base chance per tree |
| --- | --- | --- | --- | --- |
| Rain | Clouds roll in, puddles form | Wet | 2x | 20% |
| Snowfall | Snow covers the forest | Frozen | 3x | 12% |
| Thunderstorm | Lightning strikes random trees | Shocked | 5x | 6% |
| Meteor shower | Glowing rocks fall into the forest | Cosmic | 10x | 3% |
| Golden hour | Everything turns gold for 60 seconds | Golden | 20x | 1% |

**Why it works:** events pull the whole server into a rush. When the sky darkens, everyone sprints to plant before it ends, which is exactly the co-op energy the game needs.

**Stacking:** a tree can carry one mutation in the first version. Allowing two (for example Wet and Shocked) is a good later update once players know the basics.

**Luck:** there is no luck stat in the first version. A luck upgrade (Lucky Soil) comes later with rarity.

## Forest completion and tiers

When the Forest Bar fills, the server triggers the **Forest Awakening**, then the same forest re-themes into the next tier.

**The Ancient Tree.** A colossal tree stands in the middle of the hub and grows as the Forest Bar fills, from a sapling at the start of a forest to a giant several hundred studs tall at 100%, visible from anywhere on the map. It's the forest's pyramid: one giant thing the whole server watches rise together. It shakes and grows a step whenever a ring is completed.

**Forest complete (changed 2026-10-06, see [docs/plans/M6.md](plans/M6.md)):**

1. **Reward:** everyone online when the bar fills gets +500 coins and credit for the forest (+1 forests completed, which unlocks stronger training stations).
2. **Cutscene (about 8 seconds, skippable):** the camera flies up and around the Ancient Tree as it awakens: it glows, its canopy blooms and a beam of light pours down. "Forest complete! +500 coins" shows when it ends.
3. **The break (2 minutes):** the finished forest stays up; every tree sways and animals walk in (placeholders for now). Nobody can plant, since every plot is full, but players can grab seeds, train or look around.
4. **The Ancient Spring:** like the pool inside the pyramid. During the break, the glowing rune circle around the Ancient Tree's roots trains Strength and Speed together, automatically, at a multiplier rolled once per break (2x 75%, 3x 15%, 5x 10%).
5. **Extend the break for Robux:** anyone can add a minute for the whole server. Each extension in a break costs double the one before, and the break stops at 8 minutes in all.
6. **Reset:** a white flash, then the forest starts again as the next tier (MVP: tier 1 again): the same hex grid, empty, with the Ancient Tree back to a sapling.

Music and sound come later. The earlier design's 10-minute 2x coins boost and 50-seed requirement were dropped for now.

**Forest tiers.** Every tier re-themes the same map and forest. Tiers 1 and 2 ship first; tiers 3 to 9 are theme ideas for later updates:

| # | Theme | Look | Signature trees |
| --- | --- | --- | --- |
| 1 | Meadow Woods | Green hills, a stream | Golden apple tree |
| 2 | Cherry Blossom Valley | Pink petals, stone lanterns | Moonlit sakura |
| 3 | Jungle | Vines, waterfalls | Giant fern tree, banana tree |
| 4 | Snowy Taiga | Snow and frozen lakes | Ice pine, aurora tree |
| 5 | Mushroom Swamp | Fog, glowing fungi | Giant toadstool tree |
| 6 | Desert Oasis | Dunes around a pool | Cactus tree, date palm |
| 7 | Crystal Caves | Glowing underground caverns | Amethyst tree |
| 8 | Sky Islands | Floating islands, waterfalls off the edges | Cloud-root tree |
| 9 | Alien Planet | Purple soil, two moons | Tentacle tree, star fruit tree |

**Worlds rotate by roulette (built 2026-10-07).** A new server starts in Meadow Woods. After every forest's break a roulette shows the pool and spins to pick the next world by weight. Rarer worlds pay more coins per seed.

| World | Chance | Coins per seed | Free acorns grow |
| --- | --- | --- | --- |
| Meadow Woods | 80% | 1x | leafy trees and pines |
| Sakura Bamboo Valley | 20% | 2x | wild cherry blossoms and bamboo |

Both use 44 seeds per tree for now. The section below is the earlier plan (a fixed tier 1 → tier 2 loop) and is kept for reference.

**Two forest tiers at launch, about 12 minutes each.** The game ships with Meadow Woods (tier 1) and Cherry Blossom Valley (tier 2). Both use the same map and grid. After tier 2, the server loops back to tier 1. Each tier has a fixed Forest Bar target: Meadow Woods needs 44 seeds per hex (540 × 44 = 23,760 seeds) and Cherry Blossom Valley about 105 (about 62,400; set when tier 2 is built). With about 30 of up to 50 players actively planting at typical stats, each takes about 12 minutes. Targets never change, so as players get stronger over many loops, forests finish faster, the same way a veteran pyramid server finishes in about 6 minutes.

## Economy, upgrades and monetization

Coins come from planting (1 per seed, multiplied by any mutation) and Awakening chests. At launch they're spent only on upgrades.

**Upgrade shop (coins):**

| Upgrade | Effect |
| --- | --- |
| Bulk Pickup | Grab more seeds per press at the rack (holding E repeats) |
| Bulk Plant | Plant more seeds per press (holding E repeats) |
| Planting Range | Plant from farther away, so crowded plots are easier to reach |

Quick Hands (a shorter planting animation) is dropped from the MVP. Seed Pouch and Lucky Soil come later with the seed shop and rarity.

**Robux monetization:**

- **Game passes:** 2x Coins, Seed Magnet (grab seeds from the rack at a distance), and a station unlock for each training tier (2x 49, 5x 99, 10x 199, 25x 399, 50x 699, 75x 899, 100x 1,099 Robux), offered when a player tries a locked station.
- **Developer products:** coin bundles and **weather totems** that summon a weather event for the whole server.
- **Weather totems are the best fit for this game,** because a purchase helps everyone on the server, so paying players are celebrated rather than resented. Show a server-wide message crediting the buyer.
- **Codes and free gift:** redeem codes for coins and stat boosts, plus a free gift for liking, favoriting and joining your group. These are standard for the genre and drive early growth.

Seed packs and a VIP seed shop pass come later with the seed shop (see the backlog).

## Social and retention

- **Starter's name on every tree:** walking near a tree shows who started it.
- **Leaderboards:** seeds planted and forests completed, weekly and all-time, so new players can compete.
- **Daily rewards:** a login streak that ends each week in a big coin and stat boost.
- **Server announcements:** banners for weather events and the Forest Awakening (and for Epic and Legendary trees once rarity ships). This creates hype and shows new players what's coming.
- **Limited events:** a monthly event with themed weather and a special forest theme.
- **Group perks:** group members get a small permanent coin boost and early access to event codes.
- **Trading:** not planned; there are no items to trade at launch.

## Technical notes for Roblox

- **Server owns everything that matters.** The client only sends requests like "pick up" and "plant here." The server checks the player is close enough, is actually carrying seeds, and the target hex is unlocked, unfinished and within the player's planting range before planting. Mutation rolls (and rarity rolls, once added) happen on the server only.
- **Plot grid.** Generate the hex grid in code using axial coordinates, grouped into rings around the center. Store plot state (seeds received, tree species, mutation, and the UserId of the player who started it) in a server-side ForestService module.
- **Forest Bar.** Keep the total on the server and replicate it with an attribute on a single object so every client's bar updates without extra remotes.
- **Lots of big trees.** A full forest holds about 540 big trees plus their hex tiles. Use a small set of meshes with color variations, turn on StreamingEnabled, and keep particle effects only on Rare and above.
- **Camera.** Giant trunks would keep pulling the default camera in, so use Invisicam (obstacles between the camera and the character fade instead), make canopies ignored by the camera, cap the zoom near canopy height (about 60 studs) and brighten the ambient light under the canopy.
- **Saving data.** Use one player profile with a schema version number, session locking, autosave every few minutes, and a save on leave and server shutdown. Save stats, coins and forests completed.
- **Remotes.** Rate-limit plant requests per player so auto-clickers and exploits can't spam them.
- **Structure.** Shared modules for tree data (species, values, mutations) so client UI and server logic read the same table.

## MVP scope and build roadmap

Ship a small version that proves the core loop is fun, then layer rarity and weather on top.

**MVP checklist (tier 1, playable start to finish):**

- [ ] Hub with a free seed rack
- [ ] Carry system using the capacity curve, with the giant seed growing at size milestones
- [ ] Visible hex tile grid with outside-in ring unlocks and the ring complete moment, plant-where-you-stand targeting with the target indicator, the arrow to the nearest open plot and server checks, and the bounce-up animation
- [ ] Forest Bar UI, the Ancient Tree growing with the bar, the Forest Awakening finale and training multipliers
- [ ] Strength and Speed training stations
- [ ] Common trees from the free acorns: the leafy tree and the pine (the seed shop's special trees were added 2026-10-07)
- [ ] Coins, a basic upgrade shop and saving
- [ ] ~~One weather event (Rain) with the Wet mutation~~ (postponed to the first update, 2026-10-06)

**Phases after MVP:**

1. **Weather update:** all five weather events and mutations, weather totems.
2. **Second forest tier:** Cherry Blossom Valley (the same map re-themed), the loop back to tier 1, leaderboards.
3. **Live game:** more forest tiers and monthly events.

**Backlog (not prioritized):**

- ~~**Rarity system** and **seed shop**~~: built 2026-10-07 as the seed shop with special trees that boost training (see "Trees, rarity and seeds"). Lucky Soil and more special trees remain.
- **Starter reward:** a small one-off bonus for whoever starts a rare tree.
- **Pre-set rare hexes:** rarity decided when the forest starts, with glowing tiles players can race to. Fits naturally now that players choose which hex to plant in.
- **Mythic event trees.**
- **Ring completion bonuses:** a reward for everyone who planted in a ring when it's completed.

## Open questions

- Does about 12 minutes per forest feel right? The balancing sheet assumes about 30 active players; the map now has 540 plots at 44 seeds each, with longer early trips than before, and training is 4 times faster than first assumed (4 per second, as measured in the pyramid). Playtests should confirm it.
- Should targets rise on later loops? With fixed targets, strong veteran servers will finish faster over time. For comparison, a veteran pyramid server of about 70 players finished a 171,000-block pyramid in about 6 minutes.
- Does a server's tier progress reset when everyone leaves, or should new servers always start at tier 1?
- Final name: "Plant the Forest" or something punchier like "Grow the Forest" or "Plant a Forest"?
- Mobile controls: should planting be a big on-screen button, or automatic when you walk onto an empty plot?
- Do the long first trips of a new forest (about 12 seconds to the outer ring) feel too slow for brand-new players?
- Do the pyramid-fitted stat curves feel right here? Our map distances and forest sizes differ from the pyramid's, so tune the curve settings after the first playtest.
