# Gnome look (2026-10-09)

Every player is a forest gnome, like Build the Pyramid dressing everyone as a pyramid worker. The whole avatar is replaced: the player's own avatar isn't loaded at all.

- **The look (the user's picks):** the [Gnome Cap Fitted](https://www.roblox.com/catalog/15349453580) (red), the [Man Face](https://www.roblox.com/bundles/949/Man-Face) (its head, mood and brows), gnome skin on the whole body and no shirt or pants. The white [Chin Beard](https://www.roblox.com/catalog/15349673453) from the cap's creator is my default (the same creator has it in orange, yellow, black and brown).
- **Skin:** `Color3.fromRGB(240, 190, 150)`, a warm peach; in Studio's light it reads a bit pale.
- **The Forest Ranger** keeps the gnome's face, skin and beard; the ranger uniform and hat go on top, in place of the cap.
- **Leaderboards** still show players' real avatars (their headshots come from Roblox, not from the in-game character).
- Free: Roblox lets a game put any catalog item on players; nothing is bought.

## Settings

`GameConfig.Gnome`: `Enabled` (false = everyone's own avatar again), `Hat`, `Beard`, `Head`, `Mood`, `Brows` (catalog ids) and `Skin`. Code: `src/server/Services/OutfitService.luau`; nameplates re-attach when the gnome's head replaces the default one (NameplateController).

## Status

Synced to Studio 2026-10-09 evening. A preview built in Edit from the same look loaded every item (cap, beard, Man Face head). Not playtested or published: check a real spawn, buying the Ranger, the nameplate, benching and the acorn stack on the gnome body.
