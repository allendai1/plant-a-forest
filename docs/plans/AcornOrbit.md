# Acorn orbit: carried seeds as acorns circling your head

## Goal

Replace the one giant seed over your head with acorns that circle your head. The user's idea, 2026-10-06:
- **Seeds 1–5:** you see 1 to 5 small acorns circling.
- **The 6th seed:** the five merge into one larger acorn.
- **After that:** small ones start again from 1. Two large acorns means 12 seeds, and so on.

There's no single standard name for this. In game design it's usually called a **merge stack** or **tiered counter**: it counts in groups the way coins do (pennies → nickels → quarters), and the merge echoes merge games like 2048.

## What the player sees

**Tiers.** Each tier is worth 6 of the one below:

| Tier | Worth | Looks like |
| --- | --- | --- |
| Small acorn | 1 seed | about head-sized |
| Large acorn | 6 seeds | about twice that |
| Huge acorn | 36 seeds | the size of your body |
| Giant acorn | 216 seeds | today's "size of a house" acorn |

So a player carrying 71 seeds sees 1 huge, 5 large and 5 small acorns (36 + 30 + 5). There are never more than 5 of any tier, so even big numbers stay readable.

**Orbits.**
- Each tier circles your head on its own ring: small acorns closest, bigger ones further out and a little higher.
- The rings turn at different speeds and directions, and each acorn bobs gently, so it reads as a lively swirl.
- A huge or giant acorn sits above your head and spins slowly, instead of circling.

**Merging (picking up).** When a sixth small acorn arrives:
1. The five spin in fast to the merge point.
2. They squash together with a pop, a puff of leaves and a soft "thunk" (only for your own acorns).
3. The large acorn bounces out onto its ring.

Bigger tiers merge the same way.

**Splitting (planting).** Planting 1 seed out of 6 pops the large acorn back into 5 small ones, the merge in reverse. When a press moves many seeds at once (Bulk Pickup or Bulk Plant), the acorns just rebuild with a quick pop, so it doesn't stutter through every merge.

**Everyone sees everyone's acorns**, like the giant seed today.

## Files

| File | Change |
| --- | --- |
| `src/shared/GameConfig.luau` | `GiantSeedMilestones` is replaced by `AcornOrbit`: the merge size (6), each tier's acorn size, ring radius, ring height and orbit speed. These are visual numbers, but they sit next to the other carrying numbers. |
| `src/client/Controllers/CarryController.luau` | The giant seed is replaced by the orbit:<br>- **Per player:** a list of acorn parts per tier, built from `Carried`, with merge and split animations when the count changes by 1 and a quick rebuild for bigger jumps.<br>- **Movement:** one `RenderStepped` loop moves every visible acorn with a single `BulkMoveTo`. Acorns are anchored and non-colliding, placed relative to the head each frame, and they skip players farther than about 150 studs away (no acorns shown) to keep phones fast.<br>- **Kept as they are:** the plant input and the mobile button. |
| `docs/DESIGN_CHANGES.md`, `docs/ARCHITECTURE.md` | Note the change. The giant seed came from the GDD, which this replaces. |

There are no server, remote or save changes: the server already sends `Carried`. The acorn model is the existing Blender acorn (`Assets.Acorn`), scaled per tier.

## Decisions (2026-10-06)

1. Merge every 6 at every tier: large at 6, huge at 36, giant at 216. [default]
2. Small acorns circle at head height; bigger tiers ride higher and wider. [default]
3. **No number above the acorns** (the user's answer). The exact count stays in the HUD's "Capacity: n/max".
4. Merge sound: yes, a low-pitched coin clink as a placeholder "thunk", for your own acorns only. **Removed later the same day at the user's request**; the puff stays.

## Test plan

- **Picking up one at a time:** with Bulk Pickup 0, grab seeds 1 by 1. Check 1–5 small, the merge at 6, small ones again at 7, 2 large at 12, and 1 huge at 36. Screenshots of each.
- **Planting one at a time:** check the reverse split (6 → 5 small).
- **Big presses:** a Bulk Pickup / Bulk Plant press snaps to the right acorns without stuttering.
- **Other players:** a Studio 2-player test, to check the other player's acorns orbit their head.
- **Phone speed:** frame rate with acorns on many players. Studio can't fake 50 players; the 150-stud cut-off is the safeguard. M12 will measure it properly.

## What changed from the plan (2026-10-06, built)

**Changes:**
- **Ring placement:** large acorns ride a little higher (2.2 studs over the head's center). Huge and giant acorns circle above the head like a crown (7 and 15 studs up). At first the huge acorn circled at head height, and it swung between the camera and the character.
- **Leaving acorns:** they keep spinning, faster, while they merge in (this uses the frame time).
- **Parenting:** new acorns are parented only once they're sized and placed. At first, the first frame showed them at the model's full 10-stud size.

**Verified in Studio, one player, using `setCarried`:**
- **The counts:** `acornCounts` gives 5 → 5 small, 6 → 1 large, 12 → 2 large, 36 → 1 huge, 71 → 1 huge + 5 large + 5 small, and 455 → 2 giant + 3 large + 5 small.
- **On screen:** 5 small, 2 large and 71 seeds, with screenshots.
- **Merge, 5 → 6:** the five shrink in and the large acorn pops out at about 3.6 studs, with one thunk.
- **Split, 6 → 5:** the large acorn shrinks away and five small grow out.

**Not verified:**
- a second player's acorns (a multi-client test)
- the acorns with real E presses at a pile
- the frame rate with many players carrying
