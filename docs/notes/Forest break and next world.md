# Forest break and the next world

What happens after a forest is complete: a cutscene, then a **break** with a training bonus (for example "5X TRAINING" over the hub), then the next world starts.

## Buying the next world skips the wheel (2026-10-08)

- Normally a **wheel spins** at the end of the break to pick the next world at random.
- If someone **bought the next world**, the wheel no longer spins: that world starts as soon as the break ends.
- Verified in a playtest both ways (bought: no wheel, straight to that world; not bought: the wheel spins).

## Test panel fix: "Next world" ends the break (2026-10-08)

- Bug: filling the forest with the test panel and then pressing **"Next world"** left the last forest's training bonus switched on (the "5X TRAINING" sign stayed, and training kept the bonus).
- Cause: that button started the new world without ending the break first. Normal play was never affected.
- Fix: "Next world" now ends the break first. Verified in a playtest.

## Testing tip

The test panel's command remote ignores commands sent without a number, even ones that don't need one (like `endAwakening`). Send `0`.
