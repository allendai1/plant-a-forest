# Free gifts

There are **two separate gifts**, both labeled "FREE GIFT" and both worth **+500 coins**, which makes them easy to mix up.

| Gift | How you claim it | Where it shows |
| --- | --- | --- |
| **Favorite gift** | Favorite the game | The "+500" coin button at the top of the screen, and the "Claim Free Gift" box in the lobby |
| **Group gift** | Join the group | The "Join our group: +500 coins!" board in the lobby |

## How they hide

- The "+500" button and the "Claim Free Gift" box share one claimed flag, so claiming either one hides both. Checked in a playtest (2026-10-08).
- The group board hides once the group gift is claimed.
- In Studio the favorite gift can never be claimed (Roblox can't finish a favorite there), so the "+500" button and box always show in Studio tests.

## Fixed: "Thanks for joining! +500 coins" on every join (2026-10-08)

Players who had joined the group on an earlier visit saw this message every time they joined. Loading their save looked like a fresh claim. Now it only shows for a claim made during that visit. Nobody was ever paid twice; it was only the message.

## Open question

Should joining the group and favoriting count as **one** gift (claim either, everything hides, 500 coins total), or should the group board get a different label such as "GROUP GIFT"? See [Open items](Open%20items.md).
