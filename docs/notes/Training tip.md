# Training tip

The reminder that reads **"Tip: train to carry more and walk faster"**, with an arrow to a training pad.

## When it shows (all must be true)

- The player has **finished the tutorial**.
- Their **Strength is 200 or less**. Above 200 it never shows (added 2026-10-08, so veterans aren't nagged).
- They've **emptied 4 loads of acorns in a row without training**. Any gain in Strength or Speed resets the count.
- It hasn't shown in the **last 5 minutes**.
- The intro cutscene isn't playing.

## While it's up

- It stays for **12 seconds**, or until their Strength or Speed goes up.
- The arrow points to the best training pad they've unlocked by finishing forests. Standing on the pad hides the arrow, not the text.

## Good to know

- "Emptied a load" means the acorns they carry went from some to zero, by any means (planting, dropping, and so on).
- The count and the 5-minute timer reset when the player rejoins.
- The numbers live in `GameConfig.Tutorial`: `RemindTrips` 4, `RemindSeconds` 12, `RemindCooldown` 300, `RemindMaxStrength` 200.
- `RemindMaxStrength` is new and still needs adding to `docs/Balancing.xlsx` (see [Open items](Open%20items.md)).
