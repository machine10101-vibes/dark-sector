GALAXY LOOP STATE
=================
Project: DARK SECTOR ONLINE
Galaxy: HC-V1 The Dark Sector
Slice just completed: G0 folder schema and empty JSON templates

Player-visible what works now:
- Nothing in-engine. Ashen Reach is still the only flyable system.
- HC-V1 has a folder, a locked ID list (8 regions, 48 system names), and empty templates. No system is authored.

What is next (ordered):
G1  Place 8 regions and the spine lanes on a map
G2  Write systems index (all 48 IDs, stars, rule colors, jobs)
G3  Fill Compact Core (R1) — 6 full system files
G4  Fill Charter Belt (R2)
G5  Fill Municipal Skies (R3)
G6  Fill Glass Quarantine (R4)
G7  Fill Garden Shards (R5) + claim slots
G8  Fill Drift and Fall (R6) + meteor/trash tables
G9  Fill Rimward Marches (R7)
G10 Fill Black Sail Grounds (R8)
G11 Cross-region lanes, travel times, markets
G12 Spawn tables (PDO, rogues, traffic)
G13 Authored hooks on 8 flagships
G14 Clone hunt / density audit
G15 Stitch: undock Helion Dock, reach all 8 regions

Blocked by:
- No galaxy loader. Data can sit as JSON until a later slice asks the helm to read it.
- Ashen Reach and the Vellum Compact stay the live tutorial. This slice does not rename them into Helion Dock.

Open design decisions (max 5):
- Continuous space vs instance-per-system with lane jumps (recommend instance-per-system for MMO v1, continuous inside the system)
- How many live players per system before a shadow shard
- Meteor damage vs craft: lethal to probes, bruising to capital ships
- Whether Municipal Skies city interiors are dock menus or flyable
- Claim slot cap per player in HC-V1

Files touched:
- world/hc_v1/schema.json
- world/hc_v1/ids.json
- world/hc_v1/systems/_template.json
- world/hc_v1/regions/_template.json
- world/hc_v1/lanes.json
- world/hc_v1/streams.json
- world/hc_v1/trash_origins.json
- world/hc_v1/claim_slots.json
- world/hc_v1/atlas.md
- world/hc_v1/HC_V1_FIRST_GALAXY_ATLAS.md
- world/hc_v1/DARK_SECTOR_ONLINE_GALAXY_LOOP.md
- world/hc_v1/GALAXY_LOOP_HOW_TO.md
- world/hc_v1/GALAXY_LOOP_STATE.md
- tools/validate_hc_v1.py
