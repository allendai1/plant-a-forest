# Dropping acorns

Players can drop all the acorns they carry, anywhere.

- **On a computer** (changed 2026-10-08): small text **"Q to drop"** in the very bottom-right corner, shown only while carrying. It replaced the big "Q Drop Seeds" bar in the middle of the screen, which made dropping look like something you're meant to do all the time. The text can't be clicked; press Q (or Y on a gamepad).
- **On phones:** unchanged, a dark "Drop" button just right of the Forest Bar.
- The text size is `DROP_HINT_SIZE` (16) at the top of `CarryController.luau`.
- Verified in a playtest: 8 pixels from the corner, hidden when not carrying.
