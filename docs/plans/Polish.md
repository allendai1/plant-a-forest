# Polish pass: shops, sound, characters, codes, seed shop, leaderboards, badges (2026-10-07)

Built at the user's request ("Do 3, 4, 5, 6, 7", plus leaderboards, badges and a mobile check), without a plan round. The user wants features built straight away (see their feedback in memory). Icons were left out at the user's request ("dont work on icons, i will find them later"): every new icon slot shows an emoji until an image id goes into `UIStyle.Icons`.

Screenshots from a Studio playtest are in `docs/plans/polish/`.

## What was built

### Shops and purchases (3)
- **Shared pieces** (`src/client/UIStyle.luau`):
  - `clicky()`: every button squashes when pressed and plays a click; on a mouse it also grows a little with a hover sound. All `UIStyle.button`s get it, and the HUD's own buttons call it.
  - `deny()`: shakes the button with the error sound.
  - `flash()`: a white glow over a card.
  - `card()`, `closeButton()` and `short()` (1.2K / 3.4M).
- **Upgrade shop:**
  - Each row has an icon, level pips, and "3 per press → 4 per press" with the next value in green.
  - A button you can't use shakes, and the bottom line says why ("You need 3,718 more coins", "sold out", "max level").
  - A level bought flashes its row with the level-up sound.
  - The X closes the panel until you step out of the ring.
- **Seed shop:**
  - A seed arriving in your bag flashes its card with the purchase sound.
  - The page scrolls on phones.
  - The panel sits lower, clear of the Forest Bar.
- **Robux shop** (`RobuxShopController`):
  - Three tabs: Boosts, Characters and Stations.
  - Ribbons ("POPULAR" on the server boost, "BEST" on the Forest Lord) and a one-line pitch per card.
  - Station cards say "or N forests" and "Unlocked" once earned.
  - A finished Robux purchase plays the purchase sound and flashes its card.
- **Banners** draw on the top layer, so they show over open shops. They can take a color; rare seed banners use the rarity color.

### Sound (4)
- **`src/client/Sounds.luau`:** one table of sound ids, `play(name)`, and two SoundGroups, Effects and Music. Every existing sound now goes through Effects.
- **New sounds** (free Creator Store audio, each checked to load):

  | Sound | Asset |
  | --- | --- |
  | UI click | 15675059323 (Roblox) |
  | Hover | 139800881181209 |
  | Purchase | 10066947742 (Roblox) |
  | Error | 87519554692663 |
  | Level up | 112485797063762 |
  | Notification | 104000340117740 |
  | Forest complete fanfare | 9047103106 (APM) |

- **Footsteps** (`FootstepController`):
  - Every character near the camera steps by distance walked, at most 7 steps a second.
  - The surface is grass, stone (plaza, trails, altar, treadmill decks) or wood (bridges, seed stall).
  - Running on a treadmill steps in place, and Roblox's default running sound is muted.
- **Music** (`MusicController`): two calm tracks (98002463968288, 125021936389109) loop at volume 0.25 and duck under the fanfare.
- **Coin streak:** coin sounds rise in pitch through a fast planting streak (`COIN_STREAK_*` in HUD).
- **Other moments:**
  - The roulette result plays the notification sound, or the level-up sound for the 2x world.
  - A rare seed coming into stock plays the notification sound.
- **Settings:** Music and Sound effects toggles, saved. `SetGuideArrow` became `SetSetting(name, on)`, allowlisted to GuideArrow, Music and Effects.
- **Not done:** a separate merge sound for the acorns (the user removed it before).

### Park Ranger and Forest Lord (5)
- **The passes:** the two Hands passes are now characters (`GameConfig.HandsPasses`: Name, Outfit, Pitch). The pass ids and speeds are unchanged.
- **Outfits** (`tools/blender/build_assets.py` `outfits()`, uploaded as asset 138623917027942, turned into Accessories by `tools/build_outfits.luau`, stored in `ReplicatedStorage.Assets.Outfits`):
  - **Ranger:** campaign hat, gold star badge, leather backpack with a bedroll.
  - **Lord:** leaf crown with antlers, a glowing gem and sparkles; moss-green cape with a leaf hem; leaf sprays on both shoulders.
- **OutfitService:**
  - Owners wear their best outfit on every spawn and as soon as they buy.
  - An NPC of each character stands beside the upgrade altar's ring: idle animation, name label, and a prompt that opens that pass's purchase.
  - A dressed copy of each goes to `Assets.Outfits.<Outfit>Preview` for the shop's turning 3D previews.
- **Meshes:** the raw meshes are in `ServerStorage.OutfitMeshes` (renamed from `Import_…`, so build_map's import pickup leaves them alone).

### Codes (6)
- **The panel:** a CODES button beside SETTINGS opens it (`CodesController`). Type a code and press Redeem or Enter.
- **The server** (`CodeService`, RemoteFunction `RedeemCode`):
  - Matches ignoring case and spaces, once per player (saved `RedeemedCodes`), rate-limited.
  - Answers "Redeemed: …", "already used" or "doesn't work".
- **Codes:** they live in `GameConfig.Codes.List`, each with coins and/or seeds and an optional expiry. The defaults are mine, so change or remove them before launch:

  | Code | Reward |
  | --- | --- |
  | RELEASE | 1,000 coins |
  | SEEDS | 2 Palm seeds |
  | SAKURA | 1 Cherry Blossom seed |

### Seed shop (7)
- **Rebalance** (the one proposed earlier):

  | Seed | Your boost | Everyone's | Coins (was) |
  | --- | --- | --- | --- |
  | Palm | +5% | none | 600 (250) |
  | Cherry Blossom | +10% | none | 1,800 (750) |
  | Bamboo | +10% | none | 2,000 (900) |
  | Redwood | +20% | +0.05x | 6,000 (2,000) |
  | Crystal Tree | +40% | +0.1x | 18,000 (6,000) |

  The caps are +75% for your own trees and 1.2x for the server (were +300% and 2x). Robux prices are unchanged.
- **Restock line:** above the Seeds button, "New seeds in 3:42". While an Epic or Legendary seed is in stock it turns to the rarity color: "Crystal Tree in the seed shop! 3:42".
- **Rare restock announcement:** a banner in the rarity color plus a chime.
- **Not done:** a Robux "restock now". The stock is the same in every server and comes from the clock, so a personal restock would need per-player stock. Say if you want it.

### Leaderboards
- **LeaderboardService:**
  - Strength, Speed and Forests are saved to OrderedDataStores (Studio uses `_Studio` stores) every 2 minutes, only when they change, and when players leave.
  - The top 50 are read every 2 minutes with display names and published as JSON in `ReplicatedStorage.Leaderboards`.
- **In-server:** a leaderstats folder (Strength, Forests) makes Roblox's player list show and sort them.
- **The boards** (`tools/build_map.luau`):
  - Three wooden boards, 18 × 20 studs, behind the 330° acorn pile.
  - `LeaderboardController` draws them: gold, silver and bronze for the top three, your own row in green, and they scroll.

### Badges
- **BadgeAwardService:**

  | Badge | When |
  | --- | --- |
  | Welcome | join |
  | First Forest | 1 forest |
  | Forest Keeper | 10 forests |
  | World Tree Legend | 100 forests |
  | Rare Bloom | planted a special seed |

  Players who already passed a forest count get the badge on their next join.
- **Not created yet:** our Open Cloud key has no badge permission. Create the five on the Creator Dashboard (the first 5 a day are free, as far as I know), then put their ids in `GameConfig.Badges`. A badge with id 0 is never awarded.

### Mobile check
- **Studio's phone emulator wasn't used:** screen control was declined, and the emulator has no script API.
- **Checked in code instead,** at phone landscape (844 × 390, so the UI scale is 0.5):
  - Robux shop: about 340 × 290 px.
  - Upgrades: about 200 px tall.
  - Codes: about 145 px tall.
  - Settings: about 196 px tall.
  - HUD column: the same height as before (Settings and Codes share a row).
  - Restock line: about 11 px text that ends well left of the bottom Forest Bar.
- **The one problem found:** the seed page (about 370 px) was taller than the space under the top bar. It now scrolls on touch screens (300 px).

## Later the same day
- **Badges:** all 5 created through the API for free (`expectedCost` 0). Ids are in `GameConfig.Badges`, and Welcome and First Forest were awarded in a playtest.
- **Passes:** renamed on Roblox to Park Ranger / Forest Lord.
- **Seed shop:** now behind a feature flag, `GameConfig.Features.SeedShop = false`, kept out of the MVP (see HANDOFF).

## Verified in a Studio playtest
- No errors on start (14 services, 18 controllers).
- **Upgrades:** buying one took the coins, raised the level and flashed the row. Clicking an upgrade I couldn't afford showed "You need 3,718 more coins".
- **Seeds:** buying a Palm moved the seed into the bag and the stock line to "Sold out".
- **Codes:** "release" gave 1,000 coins once, then "already used". "nope" doesn't work. " Seeds " gave 2 Palm seeds, "sakura" 1 Cherry Blossom seed.
- **Robux shop:** all three tabs render, and the character cards switch between Owned, Wearing and the price as the Hands pass changes.
- **Characters:** the Forest Lord outfit shows on the player, both NPCs are dressed, and the NPC prompt exists.
- **Leaderboards:** the boards show the real stored values (your test account is #1 on all three), and leaderstats exist.
- **Studio matches disk:** every script's size matches the file on disk (44 files).

## Not verified
- **By ear:** all new sounds and music were picked by name and checked to load, not listened to.
- **Footsteps:** not heard. The surface detection isn't tested on every surface.
- **Purchase flashes after a real Robux purchase:** they need a real prompt.
- **NPC prompts:** whether they open the purchase (your own account owns the passes).
- **Badges:** not created, so never awarded.
- **The emulator view of the phone layout.**
- **Two players:** seeing each other's outfits and footsteps.
