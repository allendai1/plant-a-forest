# M2b. Interactive training stations

Status: **done 2026-10-06.** A follow-up to M2.

## 1. Goal

- **Bench press:** the player presses E (or taps the button on mobile) at a bench to start benching. Strength keeps rising until they jump off.
- **Treadmill:** stepping onto a treadmill starts the running animation automatically, and Speed rises while they're on it.
- **One station per multiplier:** a bench and a treadmill for each step of the gym ladder (1x, 2x, 5x, 10x, 25x). Any number of players can use the same station at once.

## 2. Design check and decisions

- **GDD change:** "Training is fully automatic ... No tapping is needed, and AFK training is allowed." Now: one press starts benching, and it then runs on its own (still AFK-friendly); the treadmill stays fully automatic. The GDD's stats section gets updated.
- **Multipliers move onto the stations.** M2 used the player's best multiplier on a single bench. Now each station has its own multiplier, and it unlocks with the same ladder as before: 1x at 0 forests, 2x at 1, 5x at 3, 10x at 8, 25x at 15 (`GameConfig.Stats.GymMultipliers`, unchanged). A rep on a station pays +1 × that station's multiplier. The GDD already says "Finishing forests unlocks stronger Training Groves"; this makes it literal.
- **Rate unchanged:** a rep every 0.25 s, with the per-player timer from M2.
- **Shared benches:** everyone on the same bench is placed on it at once. To avoid a pile of overlapping players, each client shows only one player per bench: yourself if you're on it, otherwise whoever got on first. The others are hidden for you only (a local-only transparency setting), so the server and other players are unaffected. Treadmills show everyone running in place, overlapping, as you said.
- **Locked stations sell themselves:** a locked station looks like any other. Trying to use it (pressing the bench's E, or stepping onto a locked treadmill) shows a message ("Complete 3 forests to unlock the 5x station") and a popup with a button to unlock it now with Robux. The unlock is a Roblox **game pass**, one per locked tier (2x, 5x, 10x, 25x), owned forever. A pass unlocks only its own tier: buying the 10x pass with no forests gives the 1x and 10x stations, not 2x or 5x. This is new monetization, so the GDD's economy section gets updated.
- **Server authority:** the server decides who is benching (it sets a `Benching` attribute on the player and holds the character in place on the bench) and who is on a treadmill. It pays the reps and refuses locked stations. Clients only show prompts, play animations and hide extra bench users.

## 3. Files

| File | Change |
| --- | --- |
| `src/server/Services/TrainingService.luau` | Stations are found by tag: `BenchStation` and `TreadmillStation`, each with a `Multiplier` attribute. **Bench:** the prompt's Triggered event (server side) checks the player is within reach, the station is unlocked for them and they aren't already benching, then places the character on the bench, holds it there (root anchored by the server) and sets `Benching = <station name>`. While benching, reps pay Strength × the station's multiplier. `LeaveBench` (or the player dying or leaving) releases them. **Treadmill:** the M2 zone check, now paying Speed × the station's multiplier, and nothing on a locked one. |
| `src/client/Controllers/TrainingController.luau` | **New.** Locked stations: shows the "Complete N forests" message and the unlock popup (the price comes from Roblox, and the Buy button opens Roblox's own purchase dialog). Bench: hides other players on the same bench (one shown per bench), plays a sitting pose, and fires `LeaveBench` when the player jumps (keyboard, gamepad or the mobile jump button). Treadmill: while the local character is on a treadmill's belt, plays its own run animation in place and scrolls the belt texture. The animation replicates, so other players see you running. Locked stations show "Complete N forests". |
| `src/shared/Remotes.luau` | **Adds `LeaveBench`** (C→S, no payload) and **`StationLocked`** (S→C: `multiplier, forestsNeeded`), which tells the client to show the message and popup when the server refuses a locked station. |
| `src/shared/GameConfig.luau` | **Adds** `GameConfig.StationPasses = { [2] = 0, [5] = 0, [10] = 0, [25] = 0 }`: the game pass id for each tier, filled in once you create the passes. While an id is 0, the popup shows the message without a Buy button. |
| `src/server/Services/PassService.luau` | **New.** Checks each player's passes on join (`UserOwnsGamePassAsync`, retried and cached), and listens to `PromptGamePassPurchaseFinished` on the server to update the cache after a purchase. Exposes `ownsTier(player, multiplier)`. TrainingService unlocks a station when the player has enough forests for it **or** owns that tier's pass. |
| `src/server/Services/DevService.luau` | Adds a Studio-only `grantPass` command (value = the tier's multiplier), so pass ownership can be tested before the real passes exist. `setForestsCompleted` already tests the forest unlocks. |
| Studio place | Replace the two placeholder stations with **5 benches** (in an arc in the 150° sector) and **5 treadmills** (in the 210° sector), each labeled with its multiplier ("Bench Press 2x") and, when locked, its requirement. Each bench gets a `ProximityPrompt` ("Bench Press [E]"). |
| Docs | GDD (stats section: how benching and the treadmill work, per-station multipliers), ARCHITECTURE (the `LeaveBench` remote, the `Benching` attribute, the new TrainingController), MVP_PLAN (an M2b entry). |

## 4. Remotes and data

- **New remote `LeaveBench`** (C→S, no payload). Server checks: rate limit, and that the player is benching. Otherwise it's ignored. This is a change to ARCHITECTURE section 5.
- **New remote `StationLocked`** (S→C). The server sends it only when it refuses a locked station; nothing the client sends can unlock anything.
- **Purchases:** the client opens Roblox's purchase dialog. Ownership is always checked on the server with `UserOwnsGamePassAsync`, never taken from the client. In Studio, purchases are test purchases and no Robux are spent.
- **Starting a bench uses Roblox's ProximityPrompt**, whose Triggered event fires on the server, so there's no custom start remote. The server still re-checks the distance (about 10 studs) and the unlock.
- **New player attribute `Benching`:** the station name, or empty. Server-set, read by clients for hiding.
- **Saved data:** none new.

## 5. Decisions and questions

**Decided:**
1. Each station's multiplier unlocks with the forest ladder, and any lower station can still be used.
2. On a shared bench you see yourself if you're on it, otherwise whoever got on first.
3. Locked stations aren't greyed out. Using one shows "Complete N forests" and a popup to unlock it with Robux.
4. A sitting pose on the bench until a real animation exists.

5. **Passes are placeholders for now.** You'll create the 4 passes later (Creator Dashboard: your experience → Monetization → Passes → Create a Pass) and set their prices there; then their ids go into `GameConfig.StationPasses`. Until an id is set, that tier's popup shows the message and a disabled "Coming soon" button.
6. **A pass unlocks only its own tier**, not the tiers below it.

## 6. Test plan

1. **Bench:** press E at the 1x bench → the character is placed on it, `Benching` is set, +4 Strength in 1 s. Jump → released, `Benching` cleared, no more Strength.
2. **Unlocks:** at 0 forests the 2x bench refuses. `setForestsCompleted 1` → the 2x bench pays +2 per rep and the 1x bench still pays +1.
3. **Treadmill:** stepping onto the 1x treadmill plays the run animation in place and pays +10 Speed in 2.5 s; stepping off stops both. The 5x treadmill refuses until 3 forests.
4. **Locked station:** at 0 forests, pressing E at the 5x bench shows the message and popup, and the player isn't seated. With the placeholder ids, the popup shows "Coming soon". The ownership logic is tested with a Studio-only `grantPass` dev command: granting the 5x pass makes the 5x bench work with 0 forests while 2x stays locked. Real purchases get tested once you've set the pass ids.
5. **Exploits:** `LeaveBench` spam while not benching is ignored. Triggering a bench from far away (simulated on the server) is refused. Faking a purchase from the client unlocks nothing; only the server's ownership check counts. A client un-anchoring its own character doesn't stop the server's benching state or let it walk away. Dying while benching releases the player.
6. **Two players (your test: Test tab → Clients and Servers → 2 players):** both bench the 1x bench; each sees only themselves on it, and a third view (not benching) sees just the first one. Both run on the same treadmill and see each other overlapping.

## What changed from the plan

- **Streaming fix in TrainingController.** With StreamingEnabled, a bench's parts (the bar, and the part holding the prompt) can be unloaded and reloaded as new objects. The first version remembered those parts, so after a reload it moved and disabled stale copies: the bar didn't lift and the prompt stayed on. It now keeps only the bench model and looks the parts up each time, and re-applies the current state when a bench's parts stream back in.
- **No scrolling belt.** Scrolling the belt needs a texture image, and there's no image asset yet. The run animation alone reads as running; the belt can scroll in the art pass.
- **Config names:** the station numbers live in `GameConfig.Stations` (prompt distance 10, server reach check 14, `LeaveBench` rate) next to `GameConfig.StationPasses`, and `GameConfig.forestsForMultiplier` gives a tier's requirement. `GameConfig.gymMultiplier` (the old per-player multiplier) was removed, since nothing uses it any more.
- **`tools/studio_sync.py --fetch`:** Studio now downloads changed scripts from a local server (`python -m http.server 34877 --bind 127.0.0.1` from the repo root, this computer only) and checks each byte count, so syncing no longer means pasting whole files.

**Verified in Studio (one player, through the Studio connection):**
- Startup: 5 services, 3 controllers, no errors from game code.
- Bench 1x: E seats the player in 0.07 s (anchored on the seat, sitting), +4 Strength in 1 s, the bar lifts (4.6 → 5.9 studs), and every bench's prompt is hidden while benching. Leaving: `Benching` cleared, unanchored, standing, no more Strength, prompt and bar back.
- Locked: at 0 forests the 2x bench refuses and the popup reads "2x station locked / Complete 1 forest to unlock it, or unlock it now." with "Coming soon". The locked 25x treadmill shows "Complete 15 forests...". A locked treadmill gives no Speed, doesn't start the run, and sends exactly one popup per visit.
- Passes: `grantPass 5` makes the 5x bench pay +20 per second (4 reps × 5) at 0 forests, while 2x stays locked.
- Forests: with 1 forest, the 2x bench pays +8 per second and the 1x bench +4.
- Treadmill 1x: `Running` set, the character's `RunAnim` plays in place, +9 to 10 Speed in 2.5 s; stepping off stops both.
- Dying while benching releases the bench; Strength stops. After respawning, walk speed is reapplied.
- 50 `LeaveBench` requests while not benching: ignored, no errors.
- Selene, StyLua and luau-lsp pass. All 15 scripts in Studio match the disk byte for byte.

**Not verified:**
- **Jump to leave:** the simulated tests sent `LeaveBench` directly, since jump input can't be simulated from here. Press Space (or the mobile jump button) on a bench to check it.
- **Two players** (Test tab → Clients and Servers → 2 players): bench visibility (each sees only one person on a shared bench) and overlapping treadmill runners.
- **A real purchase:** needs the pass ids. After setting them in `GameConfig.StationPasses`, the popup shows the price, and buying in Studio makes a test purchase.

**Place changes to save:** `Map.TrainingGrove` (5 benches and 5 treadmills), the synced scripts.
