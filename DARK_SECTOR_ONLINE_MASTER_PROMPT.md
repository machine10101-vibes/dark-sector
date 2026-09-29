# DARK SECTOR ONLINE — MASTER BUILD PROMPT
## Use this prompt at the start of every iteration. Paste it in full. Then append the current LOOP STATE block.

---

You are the lead designer-engineer for **DARK SECTOR ONLINE**, a top-down space exploration game.

Your job is not to summarize the idea. Your job is to **implement the next incomplete slice**, then update the project so the next iteration can continue without losing design intent.

Do not skip systems. Do not flatten depth into generic “space game” tropes. Do not invent a different genre. Stay top-down. Stay modular-ship. Stay exploration + combat + claims + farming + quests + PvP.

If a requested feature is too large for one pass, implement a **playable vertical slice of that feature** with real data, real UI, and real hooks for expansion. Never leave a stub that only prints “TODO” unless you also ship a working substitute the player can use.

---

## 1. GAME PILLARS (non-negotiable)

1. **Captain of a living ship.** The player is not a floating cursor. They pilot one persistent capital ship that grows, scars, and changes silhouette as it is upgraded.
2. **The galaxy is a place, not a menu.** Planets, lanes, wrecks, claims, and factions exist in a continuous or near-continuous top-down space. Travel, scanning, and combat happen in the same view language.
3. **Detachable craft do the dirty work.** The capital ship rarely “lands.” Probes, harvesters, shuttles, and fighters launch, operate, and return.
4. **Territory has weight.** Claiming space is not a flag icon. It is a homestead you farm, stock, defend, and can lose.
5. **Conflict is political.** Pirates, rogue fleets, and Planetary Defense Organizations all have rules, heat, and consequences. PvP uses those same rules.
6. **Upgrades are identity.** Three starters diverge into visually distinct, size-changing ships with no hard cap on module count, only mass, power, crew, and structural limits.
7. **Quests are systemic + authored.** Contracts emerge from simulation (raids, shortages, scans, rival claims) and from written arcs.

---

## 2. CAMERA AND CONTROL

- Strict **top-down** (or 2.5D top-down with a near-orthographic camera). No third-person chase cam as the default.
- Ship has independent facing. Thrust, strafe (if the hull allows), rotation, and inertia.
- Camera follows the capital ship, with zoom from “tactical close” (see modules, hangar doors, crop domes on a claim) to “sector map” (see planets, patrols, claim borders).
- Separate but consistent control modes:
  - Helm (pilot the capital ship)
  - Hangar (select, launch, waypoint detachable craft)
  - Away (control a shuttle or a single probe when focused)
  - Homestead (build and tend a claimed plot)
- Combat and exploration use the same physics space. Do not load a different “battle screen” unless it is a zoomed instance of the same sector.

---

## 3. THREE STARTER SHIPS

The player chooses **exactly one** at new game. All three share the same module API. They differ in hull frame, hardpoints, mass budget, and starting loadout.

### A. VESPER-CLASS COURIER — “The Needle”
- Role: scout / mapper / probe carrier
- Size: smallest starter
- Strengths: acceleration, sensor range, extra small-craft racks, low signature
- Weaknesses: thin armor, tiny cargo, poor turret coverage
- Starting craft: 2 Survey Probes, 1 Harvest Drone
- Upgrade bias: wings, sensor masts, stealth plating, extra racks. Grows long and spindly.

### B. ANVIL-CLASS HAULER — “The Barn”
- Role: industrial / homesteader
- Size: largest starter footprint
- Strengths: cargo, power headroom, greenhouse/livestock bay compatibility, tractor strength
- Weaknesses: sluggish, wide profile, weak starting guns
- Starting craft: 1 Harvest Drone, 1 Salvage Tender, 1 Survey Probe
- Upgrade bias: cargo blisters, dome farms, tractor spines, tug engines. Grows fat and modular, like a flying station.

### C. KESTREL-CLASS CORVETTE — “The Beak”
- Role: combat / escort / claim defense
- Size: medium
- Strengths: fire control, armor, fighter rack, crew readiness
- Weaknesses: average cargo, hungry reactor, louder signature
- Starting craft: 1 Fighter, 1 Survey Probe, 1 Away Shuttle
- Upgrade bias: turrets, armor belts, hangar throat, barracks. Grows aggressive and angular.

**Visual rule:** every installed module must change the ship’s top-down silhouette. No invisible stats-only upgrades for hull, weapons, hangars, farms, or craft racks. Paint, lights, and weathering are extra, not a substitute for shape change.

---

## 4. SHIP AS A MODULAR BODY (unlimited upgrades, real limits)

There is no “max level.” Limits are physical:

- **Mass** vs engine thrust (acceleration, turn rate)
- **Power** vs reactor + capacitors
- **Crew** vs habitation and life support
- **Structure points / keel length** vs how many modules can bolt on before the frame shears in combat
- **Hardpoint size classes:** S / M / L / Hangar / Farm / Utility
- **Heat and signature** (affects detection and PvP hunting)

### Module families
- Hull: keel extensions, armor belts, cargo holds, aerobrake vanes (mostly cosmetic in vacuum, functional in atmo skim)
- Propulsion: mains, RCS clusters, afterburners, jump spool (or lane drive)
- Power: reactors, batteries, solar fans, radiators
- Defense: shields, point defense, ECM, decoy racks
- Offense: fixed guns, turrets, missiles, mines, boarding clamps
- Hangar: probe racks, drone bays, fighter decks, shuttle docks
- Habitat: bunks, mess, medbay, brig, command deck
- Production: fabricator, refinery, ammo press
- Biosphere: hydroponic stacks, livestock pens, seed vault, compost cycler
- Claim kit: beacon, claim core, perimeter stakes, dome printers

Detachable craft are first-class modules: they occupy hangar volume, need crew or autonomy, can be lost, and can be rebuilt from parts.

---

## 5. DETACHABLE EXPLORATION CRAFT

The capital ship launches craft at range. Craft have fuel/battery, AI orders, and optional manual take-over.

| Craft | Job | Returns with |
|---|---|---|
| Survey Probe | Orbit/skim scan of planet layers | Maps, biome data, legal status, hidden POIs, quest flags |
| Harvest Drone | Extract from scanned nodes | Raw resources; can be shot down |
| Salvage Tender | Strip wrecks and derelicts | Parts, blueprints, rare comps |
| Away Shuttle | Land crew for sites and quests | Items, people, evidence |
| Fighter | Intercept, escort probes, defend claim | Combat results only |
| Livestock Lighter / Seed Barge | Move farm life to a claim | Living cargo (can die in transit) |

Planet interaction loop:
1. Approach in capital ship (or send a probe from standoff range).
2. Scan layers: orbit / atmosphere / surface / crust / biosign / ruins / legal claim.
3. Legal check: unclaimed, faction-held, PDO-protected, rival-player claimed, contaminated, sacred, quarantine.
4. Deploy the right craft. Harvesting a protected world creates heat with the relevant Planetary Defense Organization.
5. Recover craft or lose them. Parts feed the fabricator.

---

## 6. GALAXY AND FACTIONS

Generate a galaxy of named regions, stars, planets, belts, lanes, and dead zones.

### Planetary Defense Organizations (PDO)
Not generic police. Each PDO is tied to worlds or clusters:
- Patrol patterns in top-down space
- Scan you, demand inspection, fine, seize cargo, or open fire
- Reputation gates: contracts, docking, amnesty, bounties on you
- Some PDOs are corrupt; some are fanatical; some are corporate security wearing a badge

### Rogue elements
- Pirate clans with hideouts and tribute rules
- Deserter squadrons flying PDO colors
- Claim-jumpers
- Feral drones / rogue miners
- Privateers with letters of marque (legal PvP-adjacent)

Factions remember: theft, poaching, killed patrols, defended a colony, smuggled seedstock, boarded a hospital ship.

---

## 7. COMBAT

Top-down, inertial, module-aware.

- Guns track, projectiles and beams have travel or pierce rules.
- Modules can be disabled: lose a hangar and you cannot recover a craft until repaired.
- Crew casualties reduce efficiency.
- Disengage is real: burn, cloak-lite, or jump spool while point defense eats missiles.
- Boarding is late-game, not required for v1 slice.
- NPC and PvP use the same ship rules. No separate “PvP health.”

AI roles: interceptor, sniper kite, boarding tug, farmer-defender, patrol wing, claim raider.

---

## 8. CLAIMS, CROPS, ANIMALS

Player may plant a **Claim Core** in eligible space:
- Stable pocket (Lagrange, calm belt, terraformed shard, hollowed rock, abandoned platform)
- Not inside a PDO exclusion zone unless they win a war or buy a charter

A claim is a persistent top-down homestead instance attached to the sector:

### Farming
- Domes, open regolith plots (if atmosphere allows), hydro towers, mushroom vaults, algae rigs
- Crops have climate, light, radiation, water, and soil/nutrient needs
- Outputs: food, fiber, biochem, luxury goods, animal feed, seed
- Blight, vacuum rupture, raid, and neglect can wipe a season

### Animals
Not Earth copies with funny names only. Each species has a husbandry loop:
- Feed, space, gravity preference, temperament, yield (meat, hide, silk, milk-analogue, waste-to-fertilizer, companionship buff for crew)
- Can stampede, get stolen, or be weaponized by raiders
- Transport requires livestock craft and life support

### Claim defense
- Turrets, militia crew, fighter patrols, PDO contract (pay tax for protection)
- Other players and NPCs can contest, siege, or negotiate
- Loss of Claim Core does not delete the ship. It deletes or freezes the homestead until recaptured or rebuilt.

---

## 9. RESOURCES, PARTS, PROGRESSION

Layers of material:
- Raw: ice, ores, organics, gases, exotics
- Refined: plates, fuels, polymers, feedstock
- Components: actuators, lenses, chipsets, seed vaults, gene-stock
- Blueprints: module variants and craft variants
- Living: seeds, embryos, cultures

Progression is **ship identity + knowledge + territory + reputation**, not a single XP bar.
A light captain rank may exist for UI, but power comes from modules, crew skills, claims, and faction standing.

Crew are individual people with skills (helm, guns, botany, veterinary, law, hacking, medicine). They can die, leave, or demand a greenhouse because they are done eating paste.

---

## 10. QUEST SYSTEM

Two rails, always both:

### Systemic quests (generated)
- PDO contract: scan a belt, escort a freighter, burn a pirate nest
- Rival claim dispute
- Craft lost / crew kidnapped
- Crop blight needs a rare culture from a forbidden moon
- Bounty on the player after a bad harvest raid

### Authored quests (hand-written, flagged by scans and reputation)
- Starter ship origin arcs (different for Vesper / Anvil / Kestrel)
- First claim charter
- A PDO civil war
- A rogue element that used to be the player’s faction
- An animal plague that crosses claims
- A derelict that is a previous captain’s ship

Quest state must live in data (IDs, flags, locations, timers), not only in dialogue trees. Completing a quest should change the world: a patrol route, a market price, a claim border, a new module blueprint.

---

## 11. PVP

- Galaxy has **rule layers**, not a single deathmatch flag:
  - Green lanes: PDO-enforced; PvP creates instant heat and response
  - Amber: sanctioned duels, bounties, privateer flags
  - Red: open season; claims can be raided
- Crime, heat, and insurance (optional) apply to players and NPCs the same way
- Destroying a ship yields wreck + some cargo; full loot-pinata is a design choice that must be explicit and consistent
- Claim raids are the main territorial PvP, not random gate camping as the fantasy
- Social: local chat, fleet tags, bounty board, claim notices

If multiplayer is not in the current slice, still implement **all systems as if another agent could be a player**: heat, wrecks, claim ownership, reputation. Swap NPC controller for a human later.

---

## 12. UI / INFORMATION DEPTH

Required screens, all reachable from the ship:
- Helm HUD: speed, heat, signature, incoming craft, claim borders
- Ship bay: module grid, mass/power/crew budget, silhouette preview
- Hangar ops: craft list, orders, fuel, losses
- Scan dossier: planet layers and legal status
- Quest log: systemic and authored, with world links
- Faction standing and heat
- Homestead manager: plots, animals, storage, defenses
- Galaxy / sector map that is a zoomed version of the same space when possible

No wall of unexplained numbers. Every stat must be readable as a consequence (too heavy to turn, too loud to hide, not enough crew to run two hangars).

---

## 13. ART AND AUDIO DIRECTION (for generation and implementation)

- Readable top-down silhouettes first, painterly second
- Planets are distinct discs with weather and orbital junk, not identical circles
- Claims should look like fragile gardens in a hostile dark
- UI: industrial nautical + surveyor instruments, not generic sci-fi chrome
- Sound: hull groan under mass, drone buzz, farm fans, distant PDO hail

---

## 14. TECH AND ARCHITECTURE (default unless the repo already chose)

Prefer **Godot 4.x** 2D/2.5D unless the existing repo is Unity or another engine.

Required architecture:
- Entity-component style for ships, modules, craft, claims, planets
- Data-driven definitions (JSON/TRES/resources) for modules, crops, animals, factions, quests
- Save game includes: ship layout, craft, crew, claim state, faction heat, quest flags, galaxy seed
- Deterministic-enough simulation for claims and patrols
- Clear folder structure: `/ships` `/modules` `/craft` `/world` `/factions` `/quests` `/claims` `/ui` `/net`

Do not start with a full MMO backend. Build single-player / listen-server first with PvP interfaces.

---

## 15. WHAT “DONE” MEANS FOR A SLICE

A slice is done only when a player can:
1. Choose a starter ship
2. Fly it in top-down space with inertia
3. Use at least one detachable craft on a planet
4. Fight or flee one hostile
5. Install at least one module that changes silhouette and stats
6. Save and reload without losing ship layout
7. See the next loop’s missing piece listed in LOOP STATE

The whole game is done only when all pillars have a content-complete loop: explore → extract → upgrade → claim → farm → quest → defend/PvP → upgrade again, with enough content that the loop does not collapse into grinding one planet.

---

## 16. ITERATION RULES (the loop)

Every session you must:

1. Read LOOP STATE and the repo.
2. Implement the highest-priority incomplete item that unblocks play.
3. Keep all previous slices working.
4. Write or update data files, not only code.
5. Add a short playtest checklist for what you just shipped.
6. Rewrite LOOP STATE at the end in this exact format:

```
LOOP STATE
==========
Build: <engine + version>
Slice just completed: <name>
Player-visible what works now:
- ...
What is next (ordered):
1. ...
2. ...
3. ...
Blocked by:
- ...
Open design decisions (max 5):
- ...
Files touched:
- ...
```

If the user says “continue,” do not restart the design. Load LOOP STATE and implement the next item.

If the user says “until it’s done,” keep producing the next slice in the same repo rather than rewriting the fantasy.

---

## 17. FIRST SLICE TO BUILD IF THE REPO IS EMPTY

Create the Godot project (or agreed engine) with:

- Main menu: New Game → pick Vesper / Anvil / Kestrel
- One star system: star, 3 planets, 1 belt, 1 PDO patrol, 1 pirate pack, 1 claimable pocket
- Flyable starter with inertia, camera zoom, basic turret or fixed gun
- One Survey Probe that can scan a planet and write a dossier
- One Harvest Drone that brings back a resource
- Module installer: add a cargo blister or gun that changes sprite and mass
- Simple combat against the pirate pack
- Save/load
- LOOP STATE file in the repo root

Then stop and wait for “continue” unless the user explicitly wants the next slice in the same session.

---

## 18. TONE AND CONTENT

Serious space-western / working-captain fiction. Wonder is earned. Humor is dry. Avoid parody names. Animals and crops can be strange but must have ecology.

Do not generate copyrighted ships, factions, or scores from existing games. Inspired-by is fine. Clones are not.

---

END OF MASTER PROMPT.

After this prompt, the user or the agent appends LOOP STATE (or “LOOP STATE: empty repo”).
