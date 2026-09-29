# DARK SECTOR ONLINE — FIRST GALAXY LOOP
## Build HC-V1 “The Dark Sector” until it is full, authored, and playable

Paste this prompt at the start of every galaxy session. Append GALAXY_LOOP_STATE. Continue the next slice only. Do not invent a different galaxy.

---

You are the galactic cartographer and systems designer for **DARK SECTOR ONLINE**.

Your job is to **build the first playable galaxy: Helion Catalog Veil 1 (HC-V1), commonly called The Dark Sector.** You fill it with stars, planets, moons, belts, meteor streams, wrecks, trash fields, stations, legal overlays, and hooks — until a captain can fly for dozens of hours without hitting a cloned rock.

Do not generate infinite procedural mush. Do not place bodies that have no scan layers, no legal title, and no reason to visit. Space junk is gameplay. Meteors are gameplay. Empty beauty is a loading screen.

If a slice is too large, ship **one complete region or one complete system** with data files, then update GALAXY_LOOP_STATE.

---

## 1. WHAT HC-V1 IS

HC-V1 is not “the universe.” It is the MMO’s first shard: one mapped volume with 8 regions, 48 systems, and enough unique worlds that the loop (scan → extract → fight → claim → quest → PvP) has places to land.

Later galaxies are later. Do not start Veil 2.

Scale lock for v1:
- 8 regions
- 48 star systems (6 per region, named)
- ~160 major bodies (planets / large moons / claimable shards)
- Belts, streams, and trash fields in **every** system
- 4 PDOs + 4 rogue groups already named in the GDD
- Claim slots only where the physics and law allow them

---

## 2. PILLARS FOR THIS GALAXY

1. **Every system has a job.** Fuel, food, law, salvage, hunt, hide, farm, or die. No tourist voids.
2. **Bodies have layers.** Orbit, atmosphere, surface, crust, biosign, ruins, legal title — even if some layers read “none.”
3. **Junk is a resource and a hazard.** Debris fields hide tenders, block sensors, and feed fabricators.
4. **Motion exists.** Meteor streams, patrol orbits, drift wrecks, seasonal blight on garden shards.
5. **Law is painted on the map.** Green / Amber / Red is a property of lanes and pockets, not a server slider.
6. **Unique before clone.** Hand-author flagship worlds. Proceduralize only belts, small rocks, and trash variants around them.
7. **Claims need pockets.** Not every pretty planet is plantable. Quiet Lagrange hollows, shards, and abandoned platforms are the homestead land.

---

## 3. THE EIGHT REGIONS (fixed)

Do not rename. Fill these.

### R1 — COMPACT CORE  (Green heavy)
Helion Compact Guard home sky. Fast inspections, bright lanes, expensive docking, poor salvage.
Job: tutorial law, markets, first contracts, bad place to poach.

### R2 — CHARTER BELT  (Amber)
Rimward Charter Authority sells protection. Mining leases, tug traffic, claim paperwork.
Job: first legal harvest, first paid escort, first charter.

### R3 — MUNICIPAL SKIES  (Green near worlds, Amber between)
Orbital Municipal Navy. City-worlds that only care about their own sky.
Job: high-value trade, political quests, “not my jurisdiction” jokes that get people killed.

### R4 — GLASS QUARANTINE  (Green that shoots)
Glass Choir Wardens. Bio locks, disinfectant sweeps, burned farms.
Job: smuggle cultures, blight arcs, lamp-moth politics.

### R5 — GARDEN SHARDS  (Amber / claim country)
Terraformed splinters, dome ruins, good soil under bad stars.
Job: first homesteads, livestock routes, claim wars.

### R6 — DRIFT AND FALL  (Amber / Red pockets)
Meteor weather, trash gyres, unnamed wrecks, no one maintains the charts.
Job: salvage, probe losses, surprise streams, space-trash industry.

### R7 — RIMWARD MARCHES  (Red)
Thin law, privateer paper, starving outposts.
Job: PvP, bounty, claim raid, deserter squadrons.

### R8 — BLACK SAIL GROUNDS  (Red)
Rogue ports, tribute rocks, false PDO beacons.
Job: pirate faction content, stolen seed vaults, player dens.

---

## 4. WHAT EVERY SYSTEM FILE MUST CONTAIN

A system is not a star and three circles. Minimum data:

```
system_id
name + catalog code (HC-V1-R#-S#)
region
rule_overlay: green | amber | red | mixed (list pockets)
star: class, color, hazard, light_bible notes
bodies[]:
  id, name, type, size, orbit, scan_layers, resources, legal_title,
  settlements, biosign, ruins, claimable (yes/no + why)
belts[]: composition, density, hidden POIs
meteor_streams[]: timing, vector, damage, harvestable ice/metal
trash_fields[]: origin (battle, yard, lost convoy), loot table, sensor penalty
lanes[]: from/to, rule color, traffic, PDO response time
stations_or_platforms[]
npcs_spawn: PDO patrols, rogues, miners, haulers
claim_slots[]
market_modifiers[]
rumor_table[]
quest_hooks[]     # at least 2 systemic, 1 authored if flagship
danger_budget     # how hard this system is allowed to be
why_visit         # one sentence a player would say
```

If `why_visit` is empty, delete the system and write a real one.

---

## 5. BODY TYPES (use the full set)

Stars: main sequence, dwarf, giant, binary, gutter (dim, good for hiding).

Worlds:
- Rock barren
- Ocean / ice ocean
- Garden / shard-garden
- Desert
- Tidally locked oven-freezer
- Gas giant + harvestable skimmers
- Ice ball
- Volcanic
- Toxic / quarantine
- City-world / ecumenopolis light
- Hollowed rock / claim platform
- Dead world with ruins

Also place:
- Large moons with their own title
- Rings that are belts in all but name
- Lagrange junk pockets
- Derelict hulls the size of stations
- Seeded “trash moons” (compacted wreck)

Meteors are not planets. They are streams and weather. They can:
- Damage craft on a timer
- Drop ice and rare comps
- Force a claim to close domes
- Hide a quest wreck at a predicted crossing

---

## 6. FILL RULES (depth without sludge)

Per system, targets:
- 1 star (or binary counted as one system)
- 2–5 major bodies
- 1 belt or ring **minimum**
- 1 meteor stream **or** 1 trash gyre **minimum** (both in Drift systems)
- 1 legal complication
- 1 economic reason
- 1 thing that can kill a probe
- 0–2 claim slots (Garden Shards higher, Compact Core near zero)

Per region:
- 1 flagship authored world (must have an authored quest later)
- 1 “empty looking” system that is a trap or a salvage jackpot
- 1 PDO or rogue landmark
- Distinct palette so the player knows the region from the window

No two flagship worlds share biome + law + job.

Trash must have origin stories in data: lost Helion convoy, municipal yard purge, claim war of 27, glassed farm evacuation. Loot follows origin.

---

## 7. GALAXY BUILD SLICES (mandatory order)

Do not jump to R8 lore novels before R1 is flyable data.

| Slice | Deliverable |
|---|---|
| G0 | Folder schema + IDs + this atlas skeleton |
| G1 | Region map: 8 regions placed, lane graph between them |
| G2 | All 48 system names, jobs, rule colors, star types (index only) |
| G3 | Compact Core — 6 full system files |
| G4 | Charter Belt — 6 full system files |
| G5 | Municipal Skies — 6 full |
| G6 | Glass Quarantine — 6 full |
| G7 | Garden Shards — 6 full + claim slot pass |
| G8 | Drift and Fall — 6 full + meteor/trash weather tables |
| G9 | Rimward Marches — 6 full |
| G10 | Black Sail Grounds — 6 full |
| G11 | Cross-region lanes, markets, and travel times |
| G12 | Spawn tables (PDO, rogues, traffic) hooked to systems |
| G13 | Authored flagship hooks (8 worlds) written into quest IDs |
| G14 | Density audit: clone hunt, dead systems, missing junk |
| G15 | Playable stitch: player can undock in Core and reach all 8 regions |

A region slice is done only when all 6 system files validate against the schema and each has `why_visit`.

---

## 8. CLONE HUNT (required at G14 and after every region)

Kill these on sight:
- Three ice balls in a row with the same text
- Belts that only say “asteroids”
- Planets with no legal title
- Trash with no origin
- Claim slots on holy / quarantine / municipal capital worlds with no war cost
- Stars that do not change the lighting bible
- Names like Planet 7, Rock-3, Meteor Field A

Rename or specialize. Do not pad.

---

## 9. ONLINE / MMO RULES FOR THE MAP

- System IDs are stable forever. Never renumber after G2.
- Claim slots have fixed coordinates and IDs.
- Rule overlays can change in play (war, charter, blight) but default colors live in data.
- Population is simulated: traffic density, not 10,000 authored NPCs per rock.
- PvP is invited by R7/R8 and amber pockets, not by deleting PvE from the Core.
- Instancing: one HC-V1. Multiple shards copy the same atlas; they do not get different planet names.

---

## 10. OUTPUT FILES

```
/world/hc_v1/atlas.md
/world/hc_v1/regions/<region_id>.json
/world/hc_v1/systems/<system_id>.json
/world/hc_v1/lanes.json
/world/hc_v1/streams.json
/world/hc_v1/trash_origins.json
/world/hc_v1/claim_slots.json
/world/hc_v1/GALAXY_LOOP_STATE.md
```

After every slice, rewrite GALAXY_LOOP_STATE.

---

## 11. CONTINUE COMMAND

```
Continue the DARK SECTOR ONLINE galaxy loop for HC-V1.
Implement the next incomplete slice only.
Do not invent Veil 2. Do not skip schema.
Validate why_visit on every system you touch.
Update GALAXY_LOOP_STATE.
```

END OF GALAXY LOOP PROMPT.
