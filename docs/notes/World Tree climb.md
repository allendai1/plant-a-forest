# World Tree climb (2026-10-09)

The user's idea, like Build the Pyramid's well inside the finished pyramid: once a forest is done, you climb the World Tree to the Ancient Spring at the top and train there.

- **The Ancient Spring is now up in the tree:** a round wooden platform 110 studs up (just under Sherwood's canopy, inside the maple's and the cherry blossom's), as wide as the old Spring circle (43 studs out from the trunk). Standing on it during the break trains Strength and Speed together with the usual 2x / 3x / 5x roll. The ground spot is gone.
- **The climb:** a wooden ramp with a low rail spirals around the trunk (49 studs out, 10 wide, about 1.3 turns, ~25 s at a new player's walk speed), starting on the spawn side, with a short bridge onto the platform at the top.
- **Only during the break:** the ramp and platform appear when the forest completes and go when the next forest starts (anyone still up there drops to the hub; Roblox has no fall damage).
- The Spring's glowing field moves up onto the platform, the "2X TRAINING" sign floats over it and says "UP TOP", the tree turns see-through around you on the whole climb, the banner says "Climb the World Tree for a 2x boost!", and the first-break guide arrow points to the foot of the climb, then up to the platform.

## Settings

`GameConfig.Awakening`: `SpringHeightStuds` (110; 0 puts the Spring back on the ground with no climb) and `Climb = { Radius, Width, Slope, StartAngle }`. Wood colors and plank sizes at the top of `src/server/Services/TreeClimbService.luau`.

## Status

Synced to Studio 2026-10-09 evening; not playtested or published. To check in a playtest (the test panel's "Fill forest" gets to the break): the ramp against the three worlds' trees (branches poking through it?), whether it's walkable on a phone, the platform's height in each canopy, and how long the climb takes.
