# Analytics, 2026-10-09 (first week, ~190 new players)

Read through the Open Cloud Analytics API (`tools/funnels_report.py funnels 7`; see [Open items](Open%20items.md)). Last 7 days, data up to about 11 am. Small numbers: read the pattern, not the exact percentages.

## Onboarding (new players, all platforms)

| Step | Players | Lost from the step before |
| --- | --- | --- |
| Joined | 187 | |
| Started the tutorial (after the story intro) | 158 | 15% |
| Picked up acorns | 141 | 11% |
| Planted | 131 | 7% |
| **Trained (tutorial: 20 Strength)** | **95** | **27%** (the biggest drop) |
| Bought an upgrade | 59 | 38% |
| Completed a forest | 17 | |

- **Phones and computers look the same** (planted 70% vs 71%, trained 51% vs 50%), so the mobile Plant button isn't the main leak.
- **Tutorial:** 158 started, 127 reached the training step, 88 finished it, 66 reached the shop step, 54 finished.
- **Locked stations:** 45 players walked onto a locked station and 44 got a Robux purchase popup (0 bought). That's a quarter of all new players, likely around the tutorial's training step.

## When and where they leave

- **Session length:** of the visits, 95 reached 1 minute, 60 reached 3, 36 reached 5, 22 reached 10, 9 reached 30.
- **Where in the forest:** 111 of 213 leaves happened while the first ring was 0–24% done (average visit about 4 minutes). Most players never see a ring finish.
- **Alone:** 117 of 213 leaves were from players alone in their server (average visit 4.7 min); 2–4 players 3.5 min; 5–9 players 11 min.
- **Strength when leaving:** 129 of 218 had a carry capacity under 10 (barely trained).
- Day-1 retention showed 0 (probably too early to have data).

## What it suggests (by impact)

1. **Publish**: the live game still plays the story intro; 15% leave before the tutorial starts.
2. **No Robux popup from locked stations, at least during the tutorial**: a purchase popup a minute in is a common reason to leave.
3. **The training step**: about a third leave there. The new button hints help; the step could also be shorter.
4. **A first win sooner**: alone, the first ring (84 trees) takes far longer than a 4-minute visit.
5. **Empty servers**: players alone leave fastest. Helpers (NPC planters) or a solo-friendly pitch.

## Evening update (data to about 8 pm UTC, ~257 new players)

All of this traffic arrived today (launch day), so day-1 retention can't show until about 2026-10-11. The live game is still the older build (story intro on), so these numbers describe that build.

**Where new players are lost (the Tutorial funnel; a step counts when it's reached):**

| Step reached | Players | Lost |
| --- | --- | --- |
| Joined (save loaded) | 257 | |
| Pick up acorns | 216 | 16% (the story intro) |
| Plant | 197 | 9% |
| **Train (bench to 20 Strength)** | **177** | |
| Treadmill | 121 | **32%, the biggest drop** |
| Pick up more | 102 | 16% |
| Plant more | 93 | 9% |
| Shop | 89 | 4% |
| Finished | 74 | 17% |

- **The Train step is a "can't find / can't start the bench" problem, not a slow grind:** of the 177 who reached it, only 131 ever did a single rep (the Onboarding "Trained" step). About 46 players never trained at all. The last 6 hours look the same (94 → 64).
- **Locked stations:** 63 players walked onto a locked station and 58 got a Robux popup in the live build (0 bought). The current code only shows a banner, so publishing fixes the popup. That many locked tries suggests new players head for the wrong (locked) bench.
- **Half the visits end within about a minute or two:** 131 of 257 reached the 1-minute mark; 180 of 296 leaves had a carry capacity under 10.
- **Phones, computers and tablets look alike** (tutorial finished: computer 38%, phone 30%, tablet 31%).
- **Alone in a server:** 149 of 287 leaves were alone (traffic is ~14 new players an hour, so servers stay small).
- **The first ring is slow:** ring 1 (84 trees) takes about 8 minutes on average; rings 2–9 take 0.4–3 minutes each. A new player's first tree took about a minute.
- Only 24 newcomers completed a forest; 16 forests were completed in all (solo forests about 8 min, 2–4 players 18 min, 5–9 players 29 min).
- **Break:** of 41 players who saw a full break, 26 spent most of it in the Spring; 9 left during a break.
- **Robux:** 20 shop openings, 6 prompts, 0 purchases from the shop funnel.

**Caution:** the forest stats look skewed by a veteran (median Strength about 1.76 million, 4 leaves at capacity 1000+), probably your own or a tester's account. Forest numbers are based on very few forests so far.

## New logging (2026-10-09 evening; in the source, not synced to Studio or published yet)

- **LeftAt** names the tutorial step ("Tutorial Train") while a player is still in the tutorial, instead of "Ring 1 0-24%" (which every newcomer showed, so it said nothing).
- **TutorialStepSeconds:** the seconds spent on each tutorial step (the step name in CustomField1). Tells "gave up fast" from "tried for minutes".
- **LockedTry:** which locked station and which tutorial step ("2x Tutorial Train"), to confirm players get lost on the way to the 1x bench.
- **Visit length is timed from the join.** It used to start at the first 30-second playtime check, so every session was up to ~30 s short.
- `tools/analytics_query.py` takes "6h" (the last 6 hours) instead of days, so after a publish you can read only the new build. `funnels_report.py` now includes the Quests funnel.

**Still not measurable:** which build an event came from (use the hours window after each publish and write the publish time down), and leaves before the save loads (never counted at all).

## What to do next, by impact

1. **Publish**, and write down the time: removes the story intro (16% lost) and the locked-station popup.
2. **Make the 1x bench impossible to miss during the Train step** (the arrow to the bench, the locked benches out of the way or clearly locked). Then check LockedTry and LeftAt "Tutorial Train".
3. **A quicker first win alone:** the first ring takes ~8 min, longer than most first visits.
4. Check day-1 retention on about 2026-10-11.
