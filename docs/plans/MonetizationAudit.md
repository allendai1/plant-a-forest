# Monetization audit (2026-10-07)

Checked against the `roblox-monetization` skill's checklist and failure cases. The code is `ProductService` (receipts), `PassService` (passes), `DataService.grantPurchase` (saved grants) and the clients' prompt buttons.

## Checklist

| Check | Result |
| --- | --- |
| Prompting is client-side, granting server-side | ✓ Clients only call `Prompt…Purchase`. Grants come from `ProcessReceipt` (products) and the server's `PromptGamePassPurchaseFinished` plus `UserOwnsGamePassAsync` (passes). The clients' "purchase finished" listeners only play the purchase sound and flash, and Analytics only logs funnels. |
| One receipt callback with a product table | ✓ `ProductService.process` is the only `ProcessReceipt`. Products are looked up from GameConfig. |
| Grants are idempotent and receipt ids recorded | ✓ for saved products (upgrade levels, seeds): the grant and the PurchaseId go into the same profile and are saved together. The receipt is acknowledged only once a save holds the id (`grantPurchase`, up to 15 s, else `NotProcessedYet`). Server-wide products: see finding 1. |
| Product configuration is trusted server data | ✓ GameConfig, not client input |
| Unknown product, or buyer not in the server | ✓ `NotProcessedYet` (Roblox redelivers when they rejoin). Server-wide boosts still apply without the buyer, since they're for everyone. |
| Pass ownership: an API failure counts as "not known yet" | **Fixed today.** It used to give up after 3 quick tries on join, leaving a paying player without their pass all session. Now it keeps retrying every 60 s while they're in the server. |
| Paid random items / PolicyService | n/a. Nothing paid is random: seeds and levels are fixed items. The Spring roll and the roulette are free. |
| Prices shown before purchase | ✓ Every Robux button shows the live price (`GetProductInfo`). |

**Verified in a Studio playtest** (fake receipts through the real handler):
- An upgrade receipt raised the level once; the same receipt again didn't raise it.
- +300 bar seeds were added once; the same receipt again added nothing.

The skill's "unknown product" and "buyer absent" cases are handled in code (read, not forced in a test).

## Findings

1. **Server-wide products remember receipts in server memory only** (break extensions, the server boost, Forest Bar seeds). If a server shut down between granting and acknowledging, Roblox would deliver again when the buyer joins another server, and they'd get it twice. That favours the buyer, the value is small, and it's a deliberate trade-off (a `ponytail:` note in ProductService). Accepted.
2. **Value bought while it can't be used is held only in server memory:**
   - an extension bought when no break is running is kept for the next break (`pending`)
   - Forest Bar seeds bought while the forest is full (the break and roulette) are kept for the next forest (`leftover`)

   If the server shuts down first, the buyer paid for nothing. It's rare. The cheapest fix is to hide the Forest Bar seed buttons during the break and roulette. **Not done; the user's call.**
3. **The seed products are still on sale on Roblox while the seed shop is switched off.** The game never prompts them, so nobody can buy them in-game, and any receipt would still grant into the bag. Optional: set them off-sale until the seed shop launches.
4. **No real-money purchase has been tested yet.** See the plan below.

## Real purchase test plan (before launch)

**Free first:** Studio test purchases. In a Studio playtest, Roblox's purchase prompt says it's a test and charges nothing, but `ProcessReceipt` really runs. Click each kind once:
- a Forest Bar seed button
- "BOOST Server Training"
- an upgrade's Robux button
- the Park Ranger card
- a break extension (fill the forest from the test panel first)

Then check the grant, rejoin, and check it's still there.

**Then live, from an alt account** (this costs Robux; the user decides): the cheapest of each kind. The 2x Strength pass (5), Bulk Pickup level 1 (9), Boost Server Training (45) and +300 Forest seeds (45). Your own account owns every pass, so passes have to be tested from an alt.
