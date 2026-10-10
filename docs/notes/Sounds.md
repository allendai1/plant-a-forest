# Sounds

## Coins landing in your counter

- **New sound (2026-10-08):** "Coin sfx", id **109742263473623**, 1.6 seconds long. It was a short "plop" (773858658).
- One sound per handful of coins, at most 4 per second, volume 0.35 (`COIN_SOUND_VOLUME` in `HUD.luau`).
- **The pitch climbs during a streak:** each coin sound within 1.5 seconds of the last plays 4% higher, up to 32% higher; after a 1.5-second pause it resets. Each sound also wobbles up to 5% so repeats don't sound identical.
- Fixed: each sound used to be cut off after 1 second, which clipped the new, longer clip. Now it plays to the end.
- Still to judge by ear: whether overlapping coin sounds get cluttered when planting fast.

## Trees growing

- **Growth stages:** a "bling" (id 4612374393) on every 2nd stage (stages 2, 4 and 6), and only for the person whose acorns grew it.
- **Tree fully grown:** now **silent**, just the leaf burst (2026-10-08). The old sound was a placeholder ping and was removed. Send a sound id to bring one back.
- **A whole ring finished:** rising notes, still using that same placeholder ping.

## Other planting sounds

A soft grass sound on each plant press.
