LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: Ring haul cue
Player-visible what works now:
- A fresh keel moors on a berth ring beside Aegis, in clear space. The pad is not a planet-sized disc, and the hull is not inside the city or the ice.
- Phone portrait and landscape keep Speed, Purse, the bars, the stick, the gun, and the scale in separate bands. The scale sits above the bars on a tall phone and beside the stick on a short one.
- The Helion sky sits closer to the yard. Aegis’s night side carries distinct city lamps, the ice ring glints, and Seized Hold is a pile of lifted rocky clusters beside the planet. Helion’s corona is a spoke card past the soft glow, separate from the star’s grain. Needle, Barn, and Beak in flight keep their mounts and pick up a rounded keel and deck plates.
- On the Helion pad, Market buys one glasswheat for 12 and sells it for 8 against the purse. Off the pad the stall refuses. The posted crop price does not move. A captain clicks the corp field and types `Red-Keel!!`; a repeated flight key does not append. Set tag stores Red-Keel on the helm as one line on a short phone, and on the dossier and the overhead name. The market glass on that phone still scrolls beside the helm, clear of Speed, Purse, the bars, the stick, and the gun. F5 writes the log without leaving the helm, and F9 brings the tag and the glasswheat back.
- Take haul puts the line Ice ring N m — hold that way on the helm and in the log. The amber beam is the vector from the keel to the ice-ring drop, and the nose turns onto that vector. Cast off and W leave 0 m/s along the beam and climb through the tens toward a couple of hundred. The ice-ring number falls every second until the touch. The shell still refuses a chart dump until the ring has the crate. Touching the ring switches the line to Helion Dock N m — bring the crate back, swings the amber beam from the keel to the Helion pad, and puts the nose and the way-on on that beam. Holding it makes the Helion Dock number fall every second until Moored. Moored on the pad pays 120, or 200 if the scan already paid.
- Cast off, fly out, and come back. When the card shows Helion Dock under 200 m the keel is Moored from any heading, speed, or stop, on Local or Tactical. Inside 500 m the Dock button forces that snap. A fresh cast-off that never leaves the bubble is not grabbed. The card meters are the range. The scale bar is zoom.
- Take scan sends the probe to Aegis Prime. The ice ring is closer to the pad, and sealing it does not pay. When the Aegis Prime dossier seals while Moored, or on the next pad contact, Purse becomes 80. The ice-ring crate pays 120 on the next Moored pad, 200 if the scan was already paid, and the crate leaves the hold.
- The title is the Helion sky: a lit Aegis limb, ice, a dock ring, and a twinkling starfield, with the glass slate over the left of that scene. New keel opens the hull on a turntable under a key light. Hover, or the top card on a phone, swaps Needle, Barn, and Beak. The yard dresses each keel with its own hardware: Needle a spine mast, Barn a wide bay, Beak wing guns. The same mast, bay, gun, and probe bolts still change sensor, hold, and damage. In flight those bolts wear that keel's mount, not a shared sticker. A wide desk keeps the full cards under the yard. A phone portrait stacks three short cards (callsign, class, Take) so they stay inside the glass, and the title slate is tall enough that Continue sits on the glass. A phone landscape puts the slate on the left, with Continue on the glass, and the three cards in one row on the right with Back directly under that row. Take the Needle still moors at Helion Dock. On the page, Host with no listen port still reaches that helm and the log says flying solo. Join returns to the slate with the same fallback. New keel never opens a socket. Continue stays dark until a log exists.
- The helm glass keeps speed and purse as the strong chips, the haul cue under them, and Cast off, Dock, Board, Quests, and Probe in one bar that stays on the glass. Lane and the rest stay in a quieter strip. On a short phone, including landscape, that bar sits above the stick and the gun, and Speed and Purse stay clear of it. The web build still hides the origin overlay.
- W (or Cast off) leaves the pad and stays gone. A/D yaws and the velocity follows the nose, easing at high speed so the keel carves instead of spinning. Q/E strafes. The camera keeps the ship in frame once you leave the berth, with a lead along the nose. D is still yaw. I is still the dossier.
- Leaving the Aegis band keeps outward speed and opens a readable chart. Aegis Prime and the lanes (Homestead Road, Green Spine, Writ Lane) stay on screen. The city crust still refuses a landing and tells you to turn outward. The web build hides the origin/focus/render overlay.
- On the Helion pad, Board lists four paid slips. Seal Aegis Prime with a probe for 80. The probe goes to Aegis Prime. Pay lands when that dossier is sealed and the keel is on the pad. Carry a dock crate to the ice ring and back for 120. Tow a tag from Seized Hold back to the pad for 40. Show the Compact cutter the lane and stand the pad for 60. The helm names the live target and the distance. A live crate still owns that line and the amber ribbon. The helm shows Purse. Each slip pays once and stays in the log.
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
- world/overhead.gd
- quests/dock_board.gd
- scripts/web_moor_proof.gd
- tests/dock_board_sim.gd
- tests/dock_market.gd
- tests/layout_fit.gd
- PLAYTEST.md
- LOOP_STATE.md
- README.md
