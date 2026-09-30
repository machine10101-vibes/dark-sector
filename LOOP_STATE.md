LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: Helion Dock return
Player-visible what works now:
- Cast off, fly past the band, then come back. The chart marks a cyan Helion Dock buoy outside the Aegis well. Flying into that buoy, or back into the well with way on, drops the keel onto the pad and moors it. The helm reads Moored. Cast off and Board return. Chart law stays dark until that approach is real, so a stray Local green is not the pad.
- A sealed Aegis dossier pays 80 into Purse. The ice-ring crate pays 120 when it is brought back to the moored pad, and the crate leaves the hold.
- The helm is a dark glass card: hull, speed, heat, and purse sit in their own chips. Place and mode are the line under them. Cast off, Board, Quests, and Probe are the primary controls. Lane, weld, claim, and the rest sit in a quieter strip. The web build still hides the origin overlay.
- W (or Cast off) leaves the pad and stays gone. A/D yaws and the velocity follows the nose, easing at high speed so the keel carves instead of spinning. Q/E strafes. The camera keeps the ship in frame once you leave the berth, with a lead along the nose. D is still yaw. I is still the dossier.
- Leaving the Aegis band keeps outward speed and opens a readable chart. Aegis Prime and the lanes (Homestead Road, Green Spine, Writ Lane) stay on screen. The city crust still refuses a landing and tells you to turn outward. The web build hides the origin/focus/render overlay.
- On the Helion pad, Board lists two paid slips. Seal Aegis Prime with a probe for 80; pay lands when the dossier seals, on the pad or already underway. Carry a dock crate to the ice ring and back for 120. The helm shows Purse. Each slip pays once and stays in the log.
- Cast off is still W or the Cast off button. D yaws. I opens the dossier. The star sits on the chart offset.
- Helion Dock opens on the Aegis Prime band. The planet is a limb that fills the helm. The keel is a speck on that band, not a toy ball beside a marble. Burning toward the city stays in the band. Flying out returns to the chart with the keel still moving. Entering a well is approach, in kilometers, and matching the shell drops back into the band. The capital ship does not land.
- Starters are 40–180 m. Probes are 4–14 m. Aegis Prime is planetary (6400 km). Green Wound is 320 km across. Quiet Hollow is one 520 m valley. Ash Shelf, Reed Basin, and Glass Scar are other land. The site layer walks the valley at meter scale while the keel stays in the sky. Grow-lights read as a pin from orbit. Animals stay in the pen.
- Aegis traffic is civic, cargo, and PDO shells, plus the yard. Belts and meteor streams are volumes. A probe scan is a flight you can watch, and the time scales with altitude and body size. A lost craft keeps kilometer coordinates.
- The save and the listen snapshot share system id, body id, layer, a rebasing local origin in kilometers, and a local pos. Law and patrol guns stay on distance inside the band.
- The older loop still resolves: lanes, claims, scans, harvest, heat, modules, quests, and the host log.
What is next (ordered):
1. Live-Ops 2 — player count per system, insurance/wreck tuning, more HC-V1 authored hooks, art loop Gate 2+ on three starters
Blocked by:
- Nothing in this repo blocks Live-Ops 2. Do not add a pillar, a second veil, or a new region pass.
Open design decisions (max 5):
- Planets stay on fixed positions until a later pass adds orbits.
- The Unlet stays unplantable. Helion Dock and green capitals refuse a Claim Core.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- The farm cassette carries a hold-kine. It does not grow a crop. Crops grow on a claim plot.
- A pocket takes a core only when claim_slots.json names it. The red box on First Soil keeps the Perimeter atlas id.
Files touched:
- tests/slice1_sim.gd
- world/sector_view.gd
- quests/dock_board.gd
- scripts/main.gd
- data/craft.json
- data/first_soil.json
- data/ships.json
- data/system.json
- craft/orders.gd
- tests/scale_sim.gd
- ui/hud.gd
- world/overhead.gd
- world/scale.gd
- world/sector_sim.gd
- world/sector_view.gd
- world/stage3d.gd
- PLAYTEST.md
- LOOP_STATE.md
