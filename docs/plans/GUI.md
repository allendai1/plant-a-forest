# GUI pass: a Build-the-Pyramid-style HUD, Robux shop and prompts

## Goal

Make the HUD look and read like Build the Pyramid's (the user's reference shots, 2026-10-06): big chunky numbers with icons, a big Forest Bar, Robux buttons around them, and a custom "E" prompt. It also adds the Robux items the pyramid sells around that HUD:
- buttons that buy seeds for the Forest Bar
- Strength and Speed boost passes
- a Robux shop
- Robux prices on the upgrades
- the Friend Boost

## What the player sees

```
┌──────────────────────────────────────────────────────────────┐
│           [██████████  12,340 / 23,760  ░░░░░░░░]            │
│        [+150 R$45] [+700 R$117] [+1,500 R$225] [+7,000 R$630]│
│                                                              │
│ (coin) 1,468                                       [ SHOP ]  │
│ (bolt) 53,148                                      (bolt)    │
│        Walk Speed: 157                           1.5x Speed  │
│ (arm)  103,766                                     R$3       │
│        Capacity: 58/170                            (arm)     │
│ (tree) 14         <- forests completed            2x Strength│
│                                                    R$5       │
│ (faces) Friend Boost: +20%                                   │
└──────────────────────────────────────────────────────────────┘
```

- **Style everywhere:** the Fredoka One font (the giant seed's counter already uses it), white text with a thick black outline, bars and buttons with a dark border, rounded corners and a color gradient. It all scales down on phones.
- **Forest Bar (top):** about twice as tall, a cream-to-gold fill, `12,340 / 23,760` in big text. It still pulses at section moments.
- **Left column:**
  - Coins, with the "+N" pop.
  - Speed, with "Walk Speed: N" under it.
  - Strength, with "Capacity: carried/max" under it. The "Full! Go plant." hint stays, restyled.
  - Forests completed.
- **Icons are placeholders:** an empty image slot with an emoji in it until you send the asset ids. They're listed in one table (`UIStyle.Icons`), so swapping each in is one line.
- **Restyled to match:** the banner, the break countdown and its extend button, the Ancient Spring label, the upgrades panel and the locked-station popup.
- **Test panel:** moves to the bottom right and starts collapsed.
- **Removed:** the E / Q hints at the bottom right of the reference are left out.

## New things

### 1. Custom "E" prompt (the user's 4th reference shot)

Replaces Roblox's standard prompt on every ProximityPrompt (acorn piles, benches):
- **The look:** a dark see-through rounded panel with a gold outline, a dark key square with "E" on the left, the object's name in big bold text ("Acorns", "Bench Press") and the action under it in grey ("Pick Up", "Train").
- **Other inputs:** it shows the gamepad button instead of E on a gamepad, and on a phone the whole panel is a button you tap.
- **How:** `ProximityPrompt.Style = Custom` plus one client controller that builds a BillboardGui when Roblox reports a prompt shown (the standard way to do custom prompts).

### 2. Buy seeds for the Forest Bar (4 Robux buttons under the bar)

- **Amounts:** scaled from the pyramid's by our forest's size. Their +1,000/+5,000/+10,000/+50,000 on a 171,700 bar becomes +150/+700/+1,500/+7,000 on our 23,760, at the same prices: R$45, R$117, R$225, R$630. +7,000 is about 30% of a forest, like theirs.
- **What it does:** the seeds go straight into the open row's trees, row by row, as if someone planted them. Trees grow, row and section moments play, and if it fills the forest, the Awakening starts.
- **Banner for everyone:** "Allen added 1,500 seeds!"
- **Coins:** the buyer gets the usual 1 coin per seed.
- **Leftover seeds:** seeds that don't fit (bought near the end of a forest or during the break) go into the next forest when it starts. They're lost only if the server shuts down first.

### 3. Boost passes (right side)

- **What they do:** permanent game passes, priced cheap like the pyramid's. They multiply every Strength or Speed gain: benches, treadmills and the Ancient Spring.
- **Two ladders:**
  - Strength: 2x R$5 → 4x R$14 → 8x R$39 → 16x R$99
  - Speed: 1.5x R$3 → 2x R$9 → 3x R$25
- **The buttons:** each button shows the next pass you don't own and its price. Once you own the whole ladder it shows "MAX".
- **Owning more than one:** only your highest pass counts; they don't multiply together.

### 4. The Robux shop (the SHOP button)

A separate panel from the upgrades panel at the altar; everything in it costs Robux:
- **"BOOST Server Training!"** (R$45): 2x training for everyone in the server for 15 minutes. Buying again adds 15 more minutes. A timer shows under the bar while it runs, and everyone sees a banner. It stacks with the boost passes and station multipliers.
- **Two characters** that make pickup and planting quicker: postponed by the user (2026-10-06), to be designed later.
- **The boost passes** from section 3.
- **The 7 training station passes** (2x … 100x), which today only show in the locked-station popup.

### 5. Upgrades for coins or Robux

The upgrades panel at the altar (Bulk Pickup, Bulk Plant, Planting Range) gets a second button on each row: buy the next level with Robux.
- **Products:** one Developer Product per upgrade level, so 15. Prices rise with each level.
- **Coins:** buying a level with coins works the same as now.
- **Saving:** these grant saved levels, so the ids of handled purchases are saved in the profile. Without that, a receipt Roblox resends after a crash could grant a level twice or lose it.

### 6. Friend Boost (bottom left)

- **What it does:** +10% coins from planting for each Roblox friend in your server, up to +50%. The label shows your current %.

## Files

| File | Change |
| --- | --- |
| `src/client/UIStyle.luau` (new) | font, colors, icon ids, and small helpers (outlined text, a bordered gradient button, a UIScale for small screens) |
| `src/client/Controllers/PromptController.luau` (new) | the custom E prompt |
| `src/client/Controllers/RobuxShopController.luau` (new) | the SHOP button's panel |
| `src/client/Controllers/HUD.luau` | rebuilt layout: bar and bar buttons, the left column, the right-side buttons, Friend Boost, the server boost timer; break UI and test panel restyled or moved |
| `src/client/Controllers/ShopController.luau` | restyled, plus the Robux button per row |
| `src/client/Controllers/TrainingController.luau` | restyled locked-station popup |
| `src/shared/GameConfig.luau` | `BarBoosts`, `BoostPasses`, `ServerBoost` (2x, 15 min, product id), `UpgradeProducts`, `FriendBoost` |
| `src/server/Services/PassService.luau` | checks every pass by id. Sets the `StrengthBoost` and `SpeedBoost` player attributes. |
| `src/server/Services/ProductService.luau` | grants bar seeds, the server boost and upgrade levels. Upgrade receipts are saved in the profile. |
| `src/server/Services/TrainingService.luau` | gains × the player's boost pass × the server boost |
| `src/server/Services/ForestService.luau` | `ForestService.addSeeds(player, n)` fills open rows in order and keeps the leftover for the next forest. Planting coins × the friend boost. |
| `src/server/Services/FriendService.luau` (new) | counts each player's friends in the server and sets the `FriendBoost` attribute |
| `src/server/Services/DataService.luau` | new saved field `Purchases` (recent handled receipt ids), schema version 2 |
| `tools/build_map.luau` | prompts get `Style = Custom` and their ObjectText/ActionText |

Creating the 4 seed products, the server boost product, the 15 upgrade products and the 7 boost passes happens through Open Cloud. The pass and product images are left blank until you send icons.

## Remotes and data

- **Remotes:** no new ones. Purchases go through Roblox's own prompts and receipts.
- **Saved data:** one new saved field, `Purchases`.
- **ARCHITECTURE.md:** gets a note about the new attributes and that field.

## Decisions (2026-10-06)

1. The two characters are postponed; design them later.
2. Ladders: Strength 2x R$5, 4x R$14, 8x R$39, 16x R$99; Speed 1.5x R$3, 2x R$9, 3x R$25.
3. Speed passes multiply the Speed gained from training.
4. Server training boost: 2x for 15 minutes; buying again adds 15 more.
5. Upgrade levels 1–5 for Robux: R$9, 19, 39, 79, 149 each.

## Test plan

- **Screenshots in Studio** (play mode) at desktop size and at phone size, next to the reference shots, including the custom prompt at an acorn pile and a bench.
- **Purchases:** real purchases can't complete in Studio, so a Studio-only `DevCommand` feeds a fake receipt into the same handler for each product. Then check:
  - the bar, the trees and the row moment, and that leftovers carry over after `fillAll` and the break
  - the server boost timer and the doubled gains
  - an upgrade level, and that a repeated receipt id doesn't grant twice
- **Passes:** grant each boost pass with a test command. Check that gains multiply, and that the button moves on to the next pass and then MAX.
- **Friend Boost:** only checkable with a real friend on a live server. In Studio I'll fake the friend count and check the coin math and the label.
- **Before syncing:** stylua, selene and luau-lsp clean.

## What changed from the plan (2026-10-06, built)

**Changes from the plan:**
- **Schema version:** the profile's schema version stayed at 1. ProfileStore's Reconcile fills in the new `Purchases` field, so no migration step was needed.
- **Prompt texts:** the prompts now read "Seeds / Pick Up" and "{m}x Bench Press / Train". The 50x, 75x and 100x benches had wrongly said "25x" before. This is set in Studio and in `tools/build_map.luau`.
- **Placement:** the free gift button moved to the top right, and the tutorial hint now sits under the bar buttons. The test panel sits at the bottom right and starts collapsed; when opened, it covers the Strength button (Studio only).
- **Friend Boost on phones:** on touch screens it shows under the stats, so it stays clear of the thumbstick.
- **Created on the universe:** 7 boost passes and 20 developer products (ids in GameConfig).
- **Bug fixed during testing:** with +20%, 150 seeds paid 179 coins instead of 180 (floating point). It's fixed with an epsilon.

**Verified in Studio (play mode, one player):**
- **Layout:** the layout, the Robux shop panel, the altar panel with its Robux buttons, the break countdown and extend button, and the server boost timer.
- **Prices:** loaded from Roblox. Studio shows regional prices (e.g. 41 instead of 45).
- **Fake receipts through the real handler:**
  - +150 seeds landed in the open row and paid 150 × 1.2 coins.
  - The server boost started a 15-minute timer.
  - Bulk Pickup went 2 → 3, and the same receipt sent again didn't grant a second level.
- **Training rates:** 4/s base, 8/s with the server boost, 12/s with the 1.5x Speed pass on top.
- **The custom prompt:** it appears at the acorn pile with "Seeds / Pick Up". It was checked with AlwaysOnTop off, since Studio's screen capture leaves AlwaysOnTop billboards out.

**Not verified:**
- **Real purchases:** real Robux purchases, and real pass buys moving the HUD button to the next pass. In Studio your account owns every pass, so the buttons show MAX; "Clear boost passes" on the test panel resets that.
- **Friend Boost with a real friend.**
- **Other inputs:** phone layout and touch prompts, and gamepad.
- **The banner other players see** when someone buys.

## Follow-up: font, text shadow, icons (2026-10-06)

- **Font:** Gotham Black, everywhere: the HUD, the panels, the prompt, the giant seed counter, the plot meter and the map signs. It's the closest Roblox font to the pyramid's, chosen by rendering candidates in Studio. Changing it is one line: `UIStyle.FONT`.
- **Text shadow:** done like the pyramid, with two text labels. `UIStyle.dropShadow` hides the label's own text and draws a dark copy 14% of the text size lower, with the outlined copy on top. The copies follow the label's Text, TextSize and so on, so callers set the label as before.
  - **Left stats and Friend Boost:** outline only, no shadow (the user found it too thick there).
  - **TextScaled labels:** the signs, the seed counter and the meter outline with `StrokeSizingMode.ScaledSize`.
  - **Map signs:** `tools/build_map.luau` styles them at the end; they've been styled in Studio too.
- **Icons:** the user's images for coins, speed, strength and forests are in `UIStyle.Icons`. Friends, shop and the server boost are still emoji.
- **Verified:** screenshots of the HUD, the shop and the training pad signs.
- **Not verified:** the cutscene's skip button, the locked-station popup and the gift popup with the new font, by eye.

## Follow-up: phone layout (2026-10-06)

Laid out after the pyramid's mobile screen. `UIStyle.isTouch()` is TouchEnabled without a keyboard; the layout is picked once, at start.
- **The Forest Bar group:** moves to the bottom center, with the buttons above the bar. On phones the bar is 500 wide (640 on PC) and the buttons are smaller, so it clears Friend Boost.
- **SHOP and the boost column:** start at the top right, so they end above the jump and Plant buttons.
- **Other moves:**
  - The break countdown goes to the top center.
  - The gift button goes to the top left.
  - The Studio test panel moves to the top left.
  - The Robux shop is 560 tall (it scrolls).
- **The E prompt:** scales with the screen, like the HUD.
- **Notch:** every ScreenGui keeps the default `ScreenInsets = CoreUISafeInsets`, so the iPhone notch and the Roblox top bar are avoided automatically.

**Verified** with Studio's device emulator (phone, landscape, 666×374): the element bounds don't overlap, and there are screenshots of the HUD and the shop. The prompt is 210×43 there.

**Not verified:**
- **A real iPhone 16e.** The emulator doesn't draw a notch.
- **The dynamic thumbstick:** the emulator shows the classic one, which sits over Friend Boost the way the pyramid's does.
