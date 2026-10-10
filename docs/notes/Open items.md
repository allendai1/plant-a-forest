# Open items

Things left open after the 2026-10-08/09 session. Delete a line when it's done.

- **Save the Studio place.** Everything from this session is synced to Studio but only kept once you save the place.
- **Nothing is committed to git** since `a3776ed`. Commit when you're ready.
- **Free gifts:** merge the favorite and group gifts into one, or relabel the group board? ([Free gifts](Free%20gifts.md))
- **Balancing sheet:** add `Tutorial.RemindMaxStrength` (200) to `docs/Balancing.xlsx`. ([Training tip](Training%20tip.md))
- **Pass icons:** check the store page once Roblox finishes reviewing the 7 icons; maybe use them on the SHOP's training cards. ([Training pass icons](Training%20pass%20icons.md))
- **Blender:** save `trees.blend` to keep the "PassIcons" scene.
- **Prices:** your account sees boost and pass prices about 10% under what's set; worth a look on the Creator Dashboard. ([Robux shop and passes](Robux%20shop%20and%20passes.md))
- **Sounds:** listen to the new coin sound when planting fast (overlap?); pick a sound for a tree becoming fully grown, if you want one. ([Sounds](Sounds.md))
- **Not playtested:** the silent fully-grown tree and the coin sound fix were synced and type-checked but not heard in a playtest.
- **Test panel:** no buttons yet for the fake boost purchases (`buyStrengthBoost` / `buySpeedBoost`).
- **Story intro switched off (2026-10-09):** `GameConfig.Features.TutorialIntro = false`; new players start at the first tutorial step (grab acorns), the rest of the tutorial is unchanged. Synced to Studio; not yet seen in a playtest.
- **Version line in Settings (2026-10-09):** "Version N" (the server's `game.PlaceVersion`, 0 in Studio) at the bottom of the Settings window; compare with the place's Version History to spot an outdated server. Synced; not yet seen in a playtest.
- **Two rings (2026-10-09):** plots one ring further in open behind full-grown trees; the ring trunk fills the next ring faintly. Checked in a playtest 2026-10-09: a ring-14 tile behind a full-grown tree targets and plants, one behind unfinished trees doesn't. The trunk's second band wasn't looked at yet. Off switch: `GameConfig.Grid.AheadRings = 0`.
- **Tree preview (2026-10-09):** a see-through sapling on the empty tile you're about to plant (while carrying acorns). Check its size and see-through look in a playtest; the stage and transparency are at the top of TargetController.
- **Tutorial (2026-10-09):** steps now name the button (E / phone button / X), the shop step spotlights Bulk Pickup (`Tutorial.ShopUpgrade`), the end says "Tutorial finished! Work together with others to grow the forest!". Still 7 steps: cutting the treadmill step and the second plant was suggested, not decided.
- **Bigger map (2026-10-09):** cost estimate in [BiggerMap](../plans/BiggerMap.md) (every world +2 rings: about a day; only the harder worlds: +half a day; a phone performance test either way). Not decided.
- **Balancing sheet (2026-10-09):** `ForestSize.MinSeedsPerHex` 5 -> 3 and the new `Economy.FirstTreeCoins` 100 aren't in `docs/Balancing.xlsx` yet.
- **Quests (2026-10-09):** built and synced: a card under the stats with CLAIM and a red dot, and a list when you press it ([Quests](../plans/Quests.md)). Check the look on a phone; tune the quests and rewards in `GameConfig.Quests`.
- **Planting Range rework (2026-10-09):** 4 levels, each reaching one more tree, plus lit tiles in reach. Waiting to sync (Studio was in a playtest). Robux prices for its 4 levels are still the old cheap ones (9/19/39/79): raise them on the Creator Dashboard? Balancing.xlsx needs the new costs.
- **Mobile Plant button** disappears (after leaving and coming back, or while moving?): not diagnosed yet.
- **Island edge:** keep the invisible floor out to 650 studs, or stop players right at the edge? ([Island edge](Island%20edge.md))
- **New analytics (2026-10-09 evening):** LeftAt by tutorial step, TutorialStepSeconds, LockedTry, and visits timed from the join (`src/server/Analytics.luau`). Synced to Studio 2026-10-09 evening; not published yet. ([Analytics 2026-10-09](Analytics%202026-10-09.md))
- **Your own account in the data:** the forest stats look skewed by a veteran account. Leaving it out of analytics needs your UserId (and testers'), if you want that.
- **Rounds, whole-round opening, wasteland colors and the tree counter (2026-10-09 evening):** synced to Studio, not published. Playtest: the open outer rings in forests 2-3, the wasteland look, the counter board (`Map.Lobby.TreeCounter`, placed next to the leaderboards: move it if you like). **Save the place** to keep the board. ([Rounds](Rounds.md), [Wasteland](Wasteland.md), [Tree counter](Tree%20counter.md))
- **World Tree climb (2026-10-09):** built and synced, not playtested or published. Check the ramp against the three worlds' trees, on a phone too. ([World Tree climb](World%20Tree%20climb.md))
- **Gnome look (2026-10-09):** synced, not playtested or published. Check a spawn, the Ranger outfit on a gnome, nameplates, benching and the acorn stack. Beard color and skin tone are defaults you can change. ([Gnome look](Gnome%20look.md))
- **Field and town (2026-10-09):** the half-field is built and synced, not playtested or published; the rectangular town is planned, waiting for your OK on the layout. ([Field and town](Field%20and%20town.md))
