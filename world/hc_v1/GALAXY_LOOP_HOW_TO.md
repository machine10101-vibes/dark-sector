# DARK SECTOR ONLINE — How to build HC-V1 until the first galaxy is full

The atlas is the map. The galaxy loop is how you fill it. Do not ask an agent to “make a galaxy.” Run slices until all 48 systems have real files.

## Files to keep in `/world/hc_v1/`
- `DARK_SECTOR_ONLINE_GALAXY_LOOP.md` — law
- `HC_V1_FIRST_GALAXY_ATLAS.md` — locked names and jobs
- `GALAXY_LOOP_STATE.md` — scoreboard
- This file

## Continue message

```text
Continue the DARK SECTOR ONLINE galaxy loop for HC-V1.

Rules:
- Do not invent Veil 2 or rename regions/systems.
- Next incomplete slice only (see GALAXY_LOOP_STATE).
- Every system file needs why_visit, legal title, belt or ring, and junk or meteor stream.
- No clone rocks. No "Planet 7."
- Rewrite GALAXY_LOOP_STATE when the slice is done.

Current GALAXY_LOOP_STATE:
<<paste it>>
```

## Slice order
G0 schema → G1 region map → G2 all 48 names locked → G3..G10 fill each region’s 6 systems → G11 lanes/markets → G12 spawns → G13 flagship quest hooks → G14 clone hunt → G15 fly from Core to all 8 regions.

## Done for the first galaxy
- 48 system files validate
- 8 flagships have authored hooks
- Trash has origins
- Meteors have timers
- Claim slots exist where the atlas says they should
- A player can undock at Helion Dock and reach Black Quay without a loading-menu galaxy

## If the agent starts generating mush
Send:

```text
Reject generic bodies. Use the atlas names.
Open system <ID> and write the full schema.
why_visit must be a sentence a player would say.
```
