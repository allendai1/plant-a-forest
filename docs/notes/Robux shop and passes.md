# Robux shop and passes

## Game passes are only for characters and training areas (2026-10-08)

- **On sale as game passes:** the Forest Ranger and the 7 training areas (2x, 5x, 10x, 25x, 50x, 75x, 100x).
- **Off sale:** the 12 old Strength and Speed boost passes, and the Lord of the Forest.

## Strength and Speed boosts are now developer products

- 12 developer products with the same names and prices as the old passes: Strength 2x to 128x, Speed 1.5x to 16x. Their ids are in `GameConfig.Boosts`.
- They're still **permanent**: a purchase is saved in the player's data and lasts forever. Only the highest boost counts, and the shop sells the next one up.
- Anyone who owned an old boost pass keeps that boost. Your own account owns every pass (you made the game), so you show 128x Strength and 16x Speed until you reset with the test panel.
- Test-panel commands `buyStrengthBoost` / `buySpeedBoost` (value = which step, 1 = first) fake a purchase in Studio. They have no panel buttons yet.
- Verified in a playtest: a fake 4x Strength purchase saved, and the HUD button moved on to 8x.
- In Studio, Roblox shows your account prices about 10% under what's set (36 instead of 39, 900 instead of 999), for the old passes too. That's on Roblox's side, not the code. Worth a look on the Creator Dashboard.

## Lord of the Forest stays switched off

While `GameConfig.Features.LordOfTheForest` is false, owning its pass gives **neither its 5x pickup/planting speed nor its costume** (fixed 2026-10-08; before, owners still got both). Turning the feature back on returns them automatically.

## Training pass icons (2026-10-09)

See [Training pass icons](Training%20pass%20icons.md).
