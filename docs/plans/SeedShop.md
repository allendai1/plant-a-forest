# Seed shop: special seeds that grow boosting trees

Status: **built and tested in Studio on 2026-10-07** (approved with the default answers to every open question; results at the end). This moves the seed shop and rarity out of the backlog (CLAUDE.md lists both as "not yet"), at the user's request on 2026-10-07. The user's note: if the boosts turn out too strong, the feature can be tuned down or removed.

## Goal

Add a Grow a Garden-style seed shop with a stock that changes every 5 minutes. It sells four special seeds for coins. Planting one turns a tree in the open row into a special tree. Once it's full grown, its owner trains faster until the forest ends, and the rarest trees speed up training for the whole server.

## Why boosts, not coins

- **Coins per acorn don't scale.** A tree only takes 44 acorns, and a strong player fills one in a single press (Bulk Plant's top level plants everything carried; capacity passes 170). Even 5x coins per acorn adds up to only about 176 extra coins for everyone combined.
- **Coins run out of uses.** They only buy the 3 upgrades, about 41,000 coins to max everything, so seeds that pay back in coins are worthless to veterans.
- **Training never maxes out**, so a percentage boost to training stays worth having at every level.
- **The shop becomes what coins are for.** New players weigh upgrades against seeds; veterans finally have something to spend on.

## How it plays

1. **The free acorns don't change.** The six acorn piles stay free and unlimited and grow Common trees only (Leafy or Pine), as now.
2. **The shop** is a new **Seeds** tab in the existing shop at the altar ring, next to Upgrades.
   - **Restock:** every 5 minutes, with a countdown ("New seeds in 3:42").
   - **What's in stock:** each restock rolls which seeds are in stock and how many. Rarer seeds show up less often.
   - **Same stock everywhere:** every server and every player sees the same stock at the same time, worked out from the clock.
   - **Per player:** the stock counts are per player. If 2 Cherry Blossoms are in stock, every player can buy up to 2 in that restock. Rejoining doesn't reset that.
3. **Your seed bag:** seeds you buy are saved and kept until you plant them, with no limit on how many you hold. A **bag button** on the HUD opens it and shows your seeds with their counts.
4. **Planting a special seed:**
   - **Pick it:** tap a seed in the bag to hold it.
   - **Plant it:** walk to the open row; your target outline turns the seed's rarity color, with "Plant Cherry Blossom (E)". Press E (or the plant button). The tree you're targeting turns into that type, keeping the acorns it already has, and the special seed counts as one more seed in it. One seed starts one tree, then it's gone from your bag.
   - **Allowed targets:** an empty plot, or an unfinished **Common** tree, in the open row. A tree that's already special can't be changed, and full-grown trees can't take seeds.
   - **Limit:** each player can plant **3 special seeds per forest**. The rest stay in the bag for later forests.
5. **Everyone keeps feeding it with free acorns**, as with any tree. A special tree still takes exactly 44 seeds, pays 1 coin per acorn like any tree, and fills the Forest Bar normally.
6. **The boosts start when the tree is full grown and last until the forest is complete.** Planting early in a forest gives the longest boost; planting near the end barely matters.
   - **Owner's boost:** the owner's training gains (Strength and Speed, on every station and in the Ancient Spring) go up by the tree's boost. Several of your trees **add up, capped at +300%**. If you leave, your boost stops; it comes back if you rejoin the same server before the forest ends.
   - **Server-wide boost:** Redwoods and Crystal Trees also boost everyone in the server, whoever owns them. These **add up, capped at 2x**.
7. **Big moments:** Epic and Legendary trees show the owner's name over the tree. When one is full grown, everyone gets a banner: "Allen's Crystal Tree: everyone trains 1.5x!"
8. **On the HUD:** a boost line next to the others, for example "Trees: +150% · Server: 1.5x". It only shows while one of the two is active.

## The four seeds (starting numbers, all in GameConfig, tuned after a playtest)

| Seed | Rarity (color) | Owner's boost | Server-wide | Price (coins) | Chance to be in a restock | Stock |
| --- | --- | --- | --- | --- | --- | --- |
| Palm | Uncommon (green) | +25% | none | 250 | 80% | 1–3 |
| Cherry Blossom | Rare (blue) | +50% | none | 750 | 45% | 1–2 |
| Redwood | Epic (purple) | +100% | +0.25x | 2,000 | 15% | 1 |
| Crystal Tree | Legendary (gold) | +200% | +0.5x | 6,000 | 4% | 1 |

**How it stacks:**
- **Your own trees:**
  - Crystal + Redwood + Palm = +325%, capped at +300%.
  - Palm + Palm + Palm = +75%.
- **Server-wide:**
  - 1 Crystal = 1.5x.
  - 2 Crystals = 2x.
  - More = still 2x.
- **With the boosts that already exist,** it multiplies like the Robux server boost does today:

> gain per rep = station multiplier × boost pass × Robux server boost × (1 + your trees) × server-wide tree boost

Example: on the 10x bench with the 4x Strength pass, your trees at +150% and one Crystal in the server, a rep gives 10 × 4 × 2.5 × 1.5 = **150** instead of 40.

**How often:**
- **Restocks per forest:** about 2.5.
- **Palm:** in stock almost every forest.
- **Cherry Blossom:** in stock most forests.
- **Redwood:** in stock every 2–3 forests.
- **Crystal Tree:** in stock about every 1.5 hours.

## How the stock works

- **The restock number:** restock n is `floor(time / 300)`. The server uses `os.time()`, and clients use `workspace:GetServerTimeNow()`.
- **The roll:** a pure function in GameConfig, `seedStock(n)`, rolls each seed's chance and amount from `Random.new(n)`. Roblox's `Random` gives the same numbers for the same seed on every machine, so every server and every client gets the same stock with no messages between servers.
- **The server decides:** a client can show "New seeds" a second early. The server checks a purchase against its own restock number.

## Design check

- **CLAUDE.md:** "Every seed counts instantly". A special seed counts as one seed: the bar ticks, 1 coin pays and the tree grows.
- **CLAUDE.md:** "A hex needs many seeds... 44". Unchanged for every type, so the Forest Bar target stays fixed.
- **CLAUDE.md:** "Trees are shared. Anyone's seeds can grow any unfinished tree". Unchanged. Special trees are fed by everyone, and feeding someone's tree speeds up their boost (and the server's).
- **CLAUDE.md:** "Store the UserId of the player who started it". For a special tree, `starterUserId` becomes the owner when the special seed lands. That's also the name the label shows.
- **CLAUDE.md:** "Planting never gives stats". Still true: the tree speeds up training; planting itself gives no Strength or Speed.
- **GDD changes:** the GDD planned rare trees that pay more coins per seed. This plan replaces that with training boosts, for the reasons above. "Epic and Legendary trees get a server announcement and show the name of the player who started them": kept. "Shop-bought rare seeds skip the roll": there is no roll; the shop is the only source of special trees (open question 1).
- **GDD performance budget:** "particles only on Rare and above". Cherry Blossom gets falling petals and the Crystal Tree gets sparkles, both from stage 4. Palm and Redwood have none.
- **Later tiers with more seeds per tree** (for example ~105 in tier 2): nothing here depends on 44. The stages are fractions of a tree's seeds, and boosts start at full grown however many seeds that takes.

## Files

| File | Change |
| --- | --- |
| `tools/blender/build_assets.py` | Done in the design session: `sakura`, `crystal`, `redwood`, `palm` (8 stages each) and the four seeds. Add them to `build_all()` and the export. |
| `src/shared/Trees.luau` | `Species` becomes `{ "Leafy", "Pine", "Palm", "Sakura", "Redwood", "Crystal" }`, plus `Trees.CommonCount = 2` (the free acorns pick from the first two) and a lookup from seed id to species index. |
| `src/shared/GameConfig.luau` | `GameConfig.SeedShop`: `RestockSeconds` 300, `PerForestLimit` 3, `OwnerBoostCap` 3 (+300%), `ServerBoostCap` 2, the rate limits, and per seed: rarity, `OwnerBoost`, `ServerBoost`, `Price`, `StockChance`, `StockMin`/`StockMax`, `ProductId`. Plus the pure `GameConfig.seedStock(n)`. |
| `src/server/Services/DataService.luau` | New saved fields (below). Helpers `addSeed(player, id, n)` / `takeSeed(player, id)` that also set the `Bag_<id>` attributes. `devReset` clears them. |
| `src/server/Services/EconomyService.luau` | `BuySeed` handler: rate limit, a known seed id, standing in the shop ring (reuses `inShopRing`), in stock this restock, not bought out by this player, enough coins. Then take the coins, add the seed and count the purchase, with no yields in between. |
| `src/server/Services/ForestService.luau` | **Free acorns:** `startTree` picks Common only. **`PlantSpecial` handler:** rate limit, types, a known seed, the plot open and unfinished and Common, in range (the same check as PlantSeeds), a seed in the bag, under the per-forest limit; then it sets the species and owner, takes the seed and plants it as one seed. **Full grown:** adds the tree's boosts (by owner UserId). New `ForestService.ownerBoost(player)` and `serverBoost()`, both capped, mirrored as the `TreeBoost` player attribute and the `ServerTreeBoost` ForestState attribute, plus `TreeBoostBy` / `TreeBoostSeed` / `TreeBoosts` (a count) for the banner, like the bar boosts. **Reset:** boosts and per-forest counts clear in `reset()`. |
| `src/server/Services/TrainingService.luau` | `gain()` also multiplies by `(1 + ForestService.ownerBoost(player)) * ForestService.serverBoost()`. Every station and the Ancient Spring go through `gain()`, so that's the one change. |
| `src/server/Services/ProductService.luau` | One developer product per seed ("Buy for R$"), granted through `DataService.grantPurchase`, like the upgrade levels. |
| `src/shared/Remotes.luau` | `BuySeed` (C→S: seedId), `PlantSpecial` (C→S: seedId, q, r). |
| `src/client/Controllers/ShopController.luau` | The Upgrades / Seeds tabs. Each seed row has a 3D preview of the seed (ViewportFrame, only while the panel is open), its name in the rarity color, its boost ("+50% training"), "x2 left" / "Sold out" / "Not in stock", a coin Buy button and a Robux button. The countdown sits at the top. |
| `src/client/Controllers/HUD.luau` | **Bag:** the bag button and its panel (seeds with counts; tap to hold, tap again to put away). **Boost line:** "Trees: +150% · Server: 1.5x". **Banner:** the Epic and Legendary banner, reusing the bar-boost banner. |
| `src/client/Controllers/TargetController.luau` | While holding a seed, the outline uses the rarity color and the meter says "Plant Cherry Blossom". E and the plant button send `PlantSpecial` instead of `PlantSeeds`. Not allowed (already special, or over the limit): a red outline and the reason. |
| `src/client/Controllers/ForestController.luau` | The new species build like Leafy and Pine (models come from `Trees.Species`, so nothing new). New: petals or sparkles on Cherry Blossom and Crystal Trees from stage 4, and the owner name label on Epic and Legendary trees. |
| `tools/build_map.luau` | Import `Palm1–8`, `Sakura1–8`, `Redwood1–8` and `Crystal1–8` into `Assets.Trees`, and the four seeds into `Assets.Seeds`, with their colors. The crystal shards are Neon, dimmed like the other neon. |
| `tests/SeedShopCheck.luau` | Pure checks: `seedStock(n)` is the same twice in a row, stays within each seed's range, and changes between restocks; and the boost sums and caps. |
| Docs | GDD (seed shop, special trees and boosts replace the rarity coin table), [ARCHITECTURE.md](../ARCHITECTURE.md) (remotes, saved fields, attributes), [CLAUDE.md](../../CLAUDE.md) (move the seed shop and rarity out of "not yet"), [HANDOFF.md](../HANDOFF.md), and the spreadsheet numbers in "Waiting on the user". |

**Two particle images** get uploaded with Open Cloud: a pink petal and a small sparkle star, generated as PNGs.

## Remotes and data

- **Remotes:**
  - `BuySeed`: C→S, a seed id.
  - `PlantSpecial`: C→S, a seed id plus q, r.
  - Both get the usual server checks listed above. No new S→C remote: special trees reach clients in the existing `HexBatch` (species and `starterUserId`), and the boosts and banner go through attributes.
- **Saved fields** (ProfileStore's `Reconcile` adds them to old saves; no version bump):
  - `SeedBag`: `{ [seedId]: count }`.
  - `ShopRestock`: the restock number your purchases belong to.
  - `ShopBought`: `{ [seedId]: count }` bought in that restock. It resets when the restock number changes.
- **Not saved:** the boosts and the per-forest planting count. Both are kept by UserId in server memory and end with the forest.
- **Attributes:**
  - **Player:** `Bag_<id>`, `Bought_<id>`, `ShopRestock` and `TreeBoost`.
  - **ForestState:** `ServerTreeBoost`, `TreeBoostBy`, `TreeBoostSeed` and `TreeBoosts`.
- **This changes ARCHITECTURE.md** (sections 5 and 7). Both get updated in the build.

## Open questions (my defaults in brackets)

1. **Free acorns:** should they get a small chance to start a special tree too? [no, the shop is the only source, which makes the shop matter]
2. **Robux:** a "Buy for R$" button per seed? [yes, it works even when the seed isn't in stock: 4 developer products at about 19 / 49 / 99 / 249 Robux. No paid early restock for now.]
3. **Where the shop is:** a Seeds tab in the altar shop, or a separate seed stall in the plaza (more like Grow a Garden, but a new map piece)? [the tab]
4. **The held seed over your head:** show the seed you're holding floating above your head, for others to see? It needs one more remote. [not in this version; the HUD and the outline show it]
5. **Numbers:** the boosts, caps, prices and odds above. [these, retuned after a playtest]
6. **Does the boost carry into the break?** The forest is complete during the 2-minute break, and the Ancient Spring trains everyone then. [yes, boosts end at the reset, after the break, so the Spring gets them too]

## Steps

1. **Art:**
   - Add the four trees and seeds to `build_all()`, export, upload, and import with `build_map`. They're already designed and trimmed: lineup pictures are in `docs/plans/*_lineup.png`.
   - Generate and upload the petal and sparkle images.
2. **Code:**
   - **Shared:** Trees, GameConfig and Remotes first.
   - **Server:** DataService, EconomyService, ForestService, TrainingService, ProductService.
   - **Client:** ShopController, HUD, TargetController, ForestController.
   - Run the checks (StyLua, Selene, luau-lsp) and sync to Studio.
3. **Create the 4 developer products** if open question 2 is yes.
4. **Test in Studio** (below), then the docs.

## Test plan

- **Stock:** run `tests/SeedShopCheck.luau`. In play, the Seeds tab's countdown and stock match what the server reports, and a restock changes them at zero.
- **Buying:**
  - With coins (`setCoins`), buy a Palm: coins go down, the bag shows 1, and "x left" goes down.
  - Not enough coins, sold out, not in stock, or not standing in the ring: refused, and the shop doesn't change.
  - Fire `BuySeed` from the client with junk (a wrong id, a number, nil, 100 times a second): nothing happens.
- **Saving:** buy a seed, leave and rejoin: it's still in the bag, and the per-restock count still holds.
- **Planting:**
  - **Allowed targets:** hold a seed and plant it on an empty plot, and on a Common tree at 20 seeds. Each turns into that type at the right stage, keeps its seeds, +1, and the bag goes down.
  - **Refused targets:** a special tree, a full-grown tree, a plot outside the open row, out of range, a seed not in the bag, and a 4th special seed in one forest. Each is refused, with the reason shown.
- **Boosts:**
  - **Start:** fill a Cherry Blossom. The owner's rep on the 1x bench goes from 1 to 1.5 (with no passes), and other players' reps don't change. The HUD shows "Trees: +50%".
  - **Server-wide:** fill a Crystal Tree. Every player gets 1.5x, the banner shows on both clients, and the owner's name is over the tree.
  - **Caps:** plant 3 Crystals: the owner is capped at +300%. Fill 3 Crystals from different owners: everyone is capped at 2x.
  - **Leaving:** the owner leaves: their own boost stops, the server-wide one stays.
  - **Spring:** the boosts apply in the Ancient Spring during the break.
- **Reset:** finish the forest (`fillAll`) and let the break end. Every boost goes back to none, the next forest starts all-Common, and the per-forest limit is back to 3.
- **Robux:** fake receipts through the test panel grant one seed each, and only once each (`resendReceipt`).
- **Performance:** fill a forest with about 1 in 7 special trees and check the frame rate, as a first look for M12.

## What changed from the plan (2026-10-07, built)

**Built as planned, with the defaults:**
- **Free acorns:** no chance of a special tree.
- **Robux:** "Buy for R$" on every seed.
- **Where:** a Seeds tab in the altar shop.
- **Held seed:** not shown over the head.
- **Break:** boosts last through the break.

**Assets:**
- **Models:** the four trees (8 stages each) and seeds were uploaded as model 82132044125234 and imported into `Assets.Trees` and `Assets.Seeds`. `tools/build_map.luau` routes any `<Name><stage>` model to `Assets.Trees` and `*Seed` models to `Assets.Seeds`, and colors them through `SPECIAL_LOOK`. The crystal shards are Neon and dimmed like the rest.
- **Images:** petal 130093552340519 and sparkle 88252539838654, made by `tools/make_particle_textures.py`.
- **Products:** Palm 3717008517 (19 Robux), Cherry Blossom 3717008518 (49), Redwood 3717008521 (99), Crystal Tree 3717008522 (249).

**Small additions:**
- **Restock banner:** "Redwood seeds are in the shop!" when an Epic or Legendary seed comes into stock.
- **Own boost banner:** "Your trees: +50% training!" when your own boost grows.
- **Test panel:** a "+1 of each special seed" button (`grantSeed`); `buySeed <1-4>` fakes the Robux purchase.
- **Shop:** the boost text is on two lines, so it stays clear of the buttons.

**Decided after the build (the user):** a special seed may go on any unfinished Common tree, even one at 43 of 44 acorns. It finishes the tree at once, so the boost starts immediately and the planter becomes the owner. That's intended.

**Gotcha:** Blender adds ".001" to names that already exist in the file, and the importer colors parts by name. The preview collections from the design session made every special piece ".001" on the first import. Those collections are deleted now. Keep preview copies out of the `.blend` before exporting.

**Verified in Studio (one player):**
- **Stock:** `tests/SeedShopCheck.luau` passes. Each restock is the same every time, within range, and in stock about as often as its chance over 4,000 restocks. Every seed has its 8 tree models, a seed model and a product.
- **Buying:**
  - With Palm ×2 and Cherry Blossom ×1 in stock, both Palms and the Cherry Blossom were bought, and coins dropped by exactly 1,250.
  - Refused: the third Palm (sold out), a Redwood (not in stock), and junk (a number, nil, "Leafy").
  - The Seeds tab showed the countdown, "x2 in stock" / "Sold out" / "Not in stock", and the next restock reset the counts.
- **Saving:** the bag and this restock's purchase counts were still there after stopping and restarting play.
- **Planting a seed into an empty plot:** holding a Cherry Blossom turned the outline blue, and E planted it. The bar went to 1, +1 coin, and the bag emptied.
- **Converting a tree:** a Palm turned a 13-seed Common leafy tree into a 14-seed Palm owned by the player.
- **Refused targets:** a tree that's already special, a full-grown tree, an out-of-range plot, a seed not in the bag, junk (NaN, strings, unknown ids), and a 4th special seed in one forest.
- **Boosts:**
  - A full-grown Cherry Blossom gave "Trees: +50%" on the HUD, and the 1x treadmill paid 4.5 Speed per rep (1 × the 3x pass × 1.5).
  - The Redwood added +100% for the owner (+150% total) and 1.25x for everyone, with the banner and the owner's name label over the tree.
  - Petals fell from the full-grown Cherry Blossom.
- **Reset:** after "fill forest", the boosts held through the break (+175%, 1.25x). After the break they went back to 0 and 1x, the per-forest count went back to 0, and the forest was empty.
- **Robux:** a fake receipt gave one Cherry Blossom seed, and resending it gave nothing.

**Not verified:**
- **Needs two players:** another player seeing a converted tree rebuild, the banners on their screen, and the server-wide boost speeding up their training. The owner leaving and rejoining.
- **Not observed:** the Crystal Tree's sparkles in play (the code path is the petals' with other settings), and the "seeds are in the shop" banner (it only fires when an Epic or Legendary seed rolls into stock).
- **Real Robux purchases.**
- **The phone layout.**
- **Frame rate** with many special trees (left for M12).

## Later the same day (2026-10-07, the user's requests, built without a plan at their request)

**Seed stall:** the seed shop moved out of the altar into its own stall, where the fountain was (285°).
- **Look:** a wooden market stand with a pink-and-white striped awning, a seed of each kind in its five crates, a SEEDS sign and a pink ring.
- **Opening it:** the ring is tagged `SeedShopZone`. The stall's ring opens the Seed Shop page and the altar's ring the Upgrades page; there are no tabs.
- **Server:** `BuySeed` now checks the stall's ring.
- **Built by:** `seed_stall` in `build_assets.py` and the "seed shop" block in `build_map.luau`.

**Bamboo:**
- **The tree:** `bamboo` in `build_assets.py` is a clump of segmented stalks with node rings and spear leaves, 8 stages, about 920 triangles full grown.
- **The seed:** `bamboo_seed` is a stoppered bamboo tube with a sprouting shoot.
- **Shop numbers:** Rare, +50% training, 900 coins, 35% chance per restock, 1–2 in stock, 49 Robux (product 3717012082).
- **Particles:** the shop's Bamboo drops green leaves (the petal texture).
- **Assets:** uploaded with the stall as model 92750405660669. Two earlier uploads of the same FBX (96663342630493 and 126704155280954) are unused and can be deleted.

**Worlds and the roulette:**
- **The list:** `GameConfig.Tiers` is the world list. Each tier has a `Weight` (the roulette's odds), a `CoinMultiplier` (coins per seed planted) and `Commons` (what free acorns grow).
  - **Meadow Woods:** 80, 1x, Leafy and Pine.
  - **Sakura Bamboo Valley:** 20, 2x, `WildSakura` and `WildBamboo`.
- **Wild trees:** these are Common species that reuse the Sakura and Bamboo models (`Trees.Models`). They give no boost and have no particles, so the shop's Cherry Blossom and Bamboo still stand out in that world. `Trees.isSpecial` now means "sold in the seed shop".
- **When it spins:** a new server starts in Meadow Woods. When a break ends, `AwakeningService.finish` picks the next tier by weight, sets ForestState `NextTier` and `TierRolls`, waits `Roulette.SpinSeconds + HoldSeconds` (6 + 2.5 s), then calls `ForestService.setTier` and resets.
- **What clients see:** `WorldRouletteController` plays the roulette: a strip of world cards (each with its tree, name and coins) in the pool's proportions, slowing to a stop on the pick under a gold marker, ticking as cards pass, with the pool's chances underneath. It also shows the world's name (and "2x coins") under the Forest Bar.
- **Same target:** both worlds still need 44 seeds per tree (the client reads `Tiers[1].SeedsPerHex`), so the Forest Bar target is the same.
- **Studio test panel:** "Next world (new forest)" (`setTier`).

**Settings:** a Settings button under the boost passes opens a panel with:
- **Walk speed limit:** − / + / MAX, moved there from under the Speed stat. A "Speed limit" button under the Walk Speed line opens it.
- **Guide arrow:** ON/OFF, saved as `GuideArrow` (1/0) through `SetGuideArrow`. Off hides both the plot arrow and the tutorial's.

The guide arrow now points straight at the plot, since the fence no longer blocks.

**Verified in Studio:**
- **Shops:** the stall opens the Seed Shop with 5 seeds and buying there works. The altar opens Upgrades, and a seed purchase from there is refused.
- **Roulette:** it spun after the break and landed on Sakura Bamboo Valley (a 20% roll that happened to come up).
- **The new world:** the next forest grew wild sakura and bamboo, 132 seeds paid 264 coins, and the world label read "Sakura Bamboo Valley · 2x coins".
- **Settings:** the walk speed limit (−) and the guide arrow toggle (hides the arrow, saved) both work.
- **Checks:** `tests/SeedShopCheck.luau` passes, including the 80/20 pick and every world's tree models.

**Not verified:**
- the roulette landing back on Meadow Woods (the same code path)
- the shop Bamboo's falling leaves in play
- anything with two players
