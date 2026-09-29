GALAXY LOOP STATE
=================
Project: DARK SECTOR ONLINE
Galaxy: HC-V1 The Dark Sector
Slice just completed: G1 region map and spine lanes

Player-visible what works now:
- Nothing in-engine. Ashen Reach is still the only flyable system.
- Eight regions have coordinates. The atlas spine is a lane graph from Helion Dock to every region, including Black Quay. Travel times are blank.

What is next (ordered):
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

Map:
- Unit is catalog_span. x runs Compact Core toward Municipal Skies. y runs rimward toward Black Sail Grounds.
- Glass Quarantine sits off Haven Wheel at (4, -2). Drift sits under the Core at (0, 2). The red road is Perimeter to Marchport to Black Quay.
- Spine colors: green through R1–R3 and the Choir checkpoint, amber on the homestead road and the Writ–Gyre hatch, mixed on the two border hops, red from Marchport to Black Quay.

Files touched:
- world/hc_v1/schema.json
- world/hc_v1/lanes.json
- world/hc_v1/regions/R1.json
- world/hc_v1/regions/R2.json
- world/hc_v1/regions/R3.json
- world/hc_v1/regions/R4.json
- world/hc_v1/regions/R5.json
- world/hc_v1/regions/R6.json
- world/hc_v1/regions/R7.json
- world/hc_v1/regions/R8.json
- world/hc_v1/GALAXY_LOOP_STATE.md
- tools/validate_hc_v1.py
