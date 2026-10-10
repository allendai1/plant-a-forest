# Wiping save data

Studio and the live game save to **separate stores in the same game**: `PlayerData_Studio` and `PlayerData` (plus the leaderboards, `Top_<stat>_Studio` and `Top_<stat>`).

## Ways to wipe

1. **Quick, in Studio:** the test panel's **"Reset to new player"**. It resets every number and the seed bag, but not the leaderboards, redeemed codes or seed-shop history.
2. **Full wipe of one player, Studio or live:** a short script in Studio's command bar (Edit mode, not during play) that removes `Player_<userId>` from the player store and the user id from the four leaderboards. Ask Claude for it. For the live wipe, leave the live game first, or your server saves your old data back.
3. **No code:** Creator Hub → your game → **Data Stores Manager**, then delete the `Player_<userId>` entry in `PlayerData`.

## Good to know

- Game passes belong to your Roblox account and don't wipe.
- The forest itself isn't saved; every new server starts fresh.
- To wipe **everyone** before launch, rename the store (for example `PlayerData` to `PlayerData_v2`) in `DataService.luau`. The old data stays in the old store.
