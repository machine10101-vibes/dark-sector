# DARK SECTOR ONLINE
## Game Design Bible — Top-Down Galactic Survival, Industry, and War

Working title: **DARK SECTOR ONLINE**
View: Top-down (2.5D orthographic allowed)
Loop: Explore → Scan → Extract with detachable craft → Fight or bargain → Upgrade a modular ship → Claim space → Farm and ranch → Quest → Defend or PvP → Repeat
Players: Single-player first, PvP-ready systems, listen-server then dedicated

---

## 1. High concept

You are the captain of one ship that never resets. You pick a starter hull. You fly it from above. You send smaller craft down to worlds. You steal, harvest, bargain, and bleed for parts. You bolt those parts onto the hull until the ship no longer looks like the thing you launched. Somewhere in the dark you plant a Claim Core and try to keep a garden alive while Planetary Defense Organizations and other captains decide whether you are a neighbor, a taxpayer, or a target.

This is not a menu-driven tycoon with a spaceship skin. The ship, the sector, the claim, and the fight share one spatial language.

---

## 2. Player fantasy

- I grew this ugly beautiful ship myself.
- I know this pocket of space because I mapped it with probes I almost lost.
- My claim is a fragile green wound in the void and I will kill to keep the livestock alive.
- The law has a face. Sometimes I pay it. Sometimes I outrun it. Sometimes I wear its colors.
- Another captain can take what I built. That possibility is the point.

---

## 3. Camera, controls, modes

Default camera: top-down, follow capital ship, zoom 4x–40x sector scale.

Modes
- **Helm.** WASD/arrows or thrust-strafe-rotate. Mouse aims turrets or sets burn vector. Inertia is mandatory.
- **Hangar.** Pause-lite or slow-time optional. Select craft, set orbit / scan / extract / escort / return.
- **Away.** Direct control of one shuttle or probe inside a site instance that still reads as top-down.
- **Homestead.** Build grids on the claim: plots, pens, turrets, domes.
- **Command.** Pause-friendly ship bay and dossier. Does not teleport the ship.

Never swap to a first-person cockpit as the primary game.

---

## 4. Starter ships

### Vesper-class Courier
Needle. Fast. Blind spots. Lives on information.
Start: 2 Survey Probes, 1 Harvest Drone, light pulse nose gun, small cargo blister.
Grows: sensor masts, rack spines, long keel, low-signature skin.

### Anvil-class Hauler
Barn. Slow. Rich. The homestead that flies.
Start: 1 Harvest Drone, 1 Salvage Tender, 1 Survey Probe, tractor, empty farm cassette.
Grows: cargo blisters, dome rings, tug engines, refinery hump.

### Kestrel-class Corvette
Beak. Mean. Hungry.
Start: 1 Fighter, 1 Survey Probe, 1 Away Shuttle, twin cheek guns, small barracks.
Grows: turret rings, armor belt, hangar throat, command castle.

All three expose the same module sockets. Balance is frame bonuses + starting sockets, not unique hidden stats.

---

## 5. Module system

Each module is a data record:
- id, family, size class, mass, power in/out, crew required, structure cost
- hardpoint tags, craft capacity, farm capacity
- top-down sprite layer + attach offset + footprint polygon
- heat, signature, weather/rad hardness
- recipe and blueprint flag

Install rules
- Snap to sockets or to compatible hull faces
- Recalculate center of mass (handling changes)
- Silhouette rebuild every time
- Overload is allowed; the ship becomes a pig or a furnace, it does not get a hard “invalid”

Unlimited ways means combinatorial modules, not an infinite stat slider. Add new module defs over the life of the game. Players can keep bolting until the keel rating and power budget scream.

---

## 6. Detachable craft

Shared stats: mass, battery/fuel, autonomy, vulnerability, cargo, skill needed to crew.

Orders: hold, follow, orbit body, scan layer, extract node, salvage wreck, escort craft, defend claim, return, scuttle.

Loss is permanent until rebuilt. A dead probe is a story and a bill.

Planet layers a probe can reveal
1. Orbit traffic and satellites
2. Atmosphere and weather
3. Surface biomes and settlements
4. Crust resources
5. Biosignatures and animal stock
6. Ruin / anomaly
7. Legal title (unclaimed, PDO, player, sacred, quarantine)

---

## 7. Galaxy simulation (minimum viable richness)

One galaxy seed.
Regions with tone: settled cores, charter belts, red marches, garden shards, dead systems.

Each system contains:
- Star and hazard rating
- 1–8 bodies
- Lanes or jump points
- PDO authority value
- Market and rumor table
- Claim slots

Do not generate infinite identical rocks. Hand-author unique worlds for authored quests and sprinkle procedural belts around them.

---

## 8. Factions

### Planetary Defense Organizations
Examples to implement as data, names replaceable:
- **Helion Compact Guard** — legalistic, inspection-happy, excellent response time in green lanes
- **Rimward Charter Authority** — sells protection, slow to arrive, cheaper charters
- **Glass Choir Wardens** — bio-quarantine zealots, will burn a farm for one blight spore
- **Orbital Municipal Navy** — city-state PDOs that only care about their own sky

### Rogue elements
- Black sail clans
- Claim-jump cooperatives
- Feral miner swarms
- Privateers with paper that expires

Reputation is a vector per faction, not one hero meter. Heat is local and decays or gets recorded as a warrant.

---

## 9. Combat design

Ranges: point defense, turret, spinal, missile.
Damage types: kinetic, energy, thermal, disruption (modules/crew).
Called shots against modules at close zoom.
Disengage: accelerate out of weapon envelope or spool a lane drive while eating fire.

Crew: gunners reduce spread, engineers restart modules, medics save wounded.

PvE and PvP ships read the same defense layers. No sponge-health raid bosses.

---

## 10. Claims and husbandry

Claim Core item + legal window.
Planting starts a homestead instance anchored to sector coordinates.

Plots
- Regolith trench
- Sealed dome
- Hydro tower
- Mycelial vault
- Algae curtain
- Gravity pen (animals)

Crops (examples)
- Glasswheat — staple, hates radiation
- Voidbean — nitrogen fixer, low yield
- Ember kale — heat crop, luxury
- Silkreed — fiber
- Ghost gourd — water battery
- Night orchard stock — slow, high value, stealable

Animals (examples)
- Hold-kine — milk analogue, need gravity plates
- Ash hens — eggs, panic in vacuum alarms
- Ribbon goats — fiber + terrible decision-making
- Rock crabs — eat slag, yield shell plate
- Lamp-moths — pollination, die in PDO disinfectant sweeps

Seasons are local timers modified by disaster, raid, and crew skill.
A claim that is only a resource tap has failed the pillar. It must feel like a place.

---

## 11. Quests

Every quest object:
- id, type (systemic / authored)
- giver faction or world flag
- prerequisites
- world mutations on success and on failure
- time pressure optional
- combat / stealth / husbandry / legal solutions when possible

Starter authored beats
1. Shakedown cruise (learn helm + probe)
2. First illegal or legal harvest (learn heat)
3. First module that changes the hull
4. Charter or squat a claim
5. A named enemy who remembers you

Systemic generators
- Escort, survey, cull, deliver live cargo, recover a lost craft, defend a claim for N hours, turn in a warrant, poison a rival field (dark option)

---

## 12. PvP ruleset

Green / Amber / Red overlays on the same map.

Green: fire on a player and PDO response is a real fleet, not a slap.
Amber: flagged hunts, arena buoys, letters of marque.
Red: claim war, wreck rights, no incoming law.

Anti-grief floor for v1:
- New captains get a short green-lane grace
- Claim cores take time to crack (no one-shot delete)
- Destroyed ships leave a wreck with partial cargo, not always full wipe
- Criminal flag is visible on scan

---

## 13. Economy

No single gold sink. Sinks are: repair, seed, feed, bribes, charter taxes, ammo, craft rebuilds, crew pay, dome patches.

Sources: harvest, salvage, contracts, market, livestock, theft.

Prices move with shortages. A blighted region makes glasswheat precious and PDO checkpoints hungrier.

---

## 14. Progression and “unlimited upgrades”

There is no level cap.
Soft caps: keel rating, reactor class, crew population, claim upkeep, heat.
New content is new modules, species, PDO charters, and regions — not a higher number on the same gun.

Looks and size: five visual tiers of hull mass for readability (skiff, courier, corvette, house, castle) but the player can occupy in-between states. An Anvil that only added guns should still read as a fat ship with teeth, not suddenly become a Kestrel.

---

## 15. Content budget for a first public loop

- 3 starters
- 40 modules
- 6 craft types
- 12 crops, 8 animals
- 4 PDOs, 4 rogue groups
- 1 region of ~12 systems
- 15 authored quests
- Systemic contract generator
- 1 claim template with expansion plots
- PvP rule overlay and listen-server

That is “the loop exists.” After that, add regions and modules forever.

---

## 16. Production phases

Phase 0 — Bible and prompt (this document)
Phase 1 — Helm, camera, one system, three hull polygons
Phase 2 — Probes, dossiers, harvest
Phase 3 — Modules that reshape the ship + save
Phase 4 — Combat AI and heat
Phase 5 — Claim + one crop + one animal
Phase 6 — Quest data + first authored arc
Phase 7 — Multiplayer rule layer
Phase 8 — Content density and juicing
Phase 9 — Tools for adding modules/quests without code

---

## 17. Success tests

A stranger can:
- Tell the three starters apart at a glance after ten hours of upgrades
- Lose a probe and care
- Eat food they grew
- Explain why a PDO is angry without opening a wiki
- Point at a patch of space and say “that is mine” and be right until someone takes it
