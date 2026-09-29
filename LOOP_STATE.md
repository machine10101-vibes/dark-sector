LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 5 Claim
Player-visible what works now:
- Slice 1 helm still holds. New game picks Vesper Needle, Anvil Barn, or Kestrel Beak. Thrust coasts. Zoom runs from hull to system. The gun fires in the same view you fly.
- Helion Dock (HC-V1-R1-S1) still has Helion, Aegis Prime, the ice ring, Seized Hold, the Helion Compact patrol, Hauler Holt, and The Unlet. The Unlet stays marked and closed.
- Slice 2 craft still holds. Probes orbit, scan, and return. Drones bring raw mass home. A lost craft stays lost until rebuild spends returned mass.
- Slice 3 modules still hold. The bay bolts and pulls cargo blister, cheek gun, survey mast, farm cassette, and armor belt. Overload is allowed. The silhouette and the handling follow the bolts.
- Slice 4 war still holds. Shots travel in the sector. Hull HP, module HP, and hangar HP still matter. The Red Keel pack holds outside the green. Heat still hails, fines, and brings guns. The dock beacon still welds. A broken keel still leaves a wreck and wakes at Helion Dock.
- L at the Homestead Road buoy, off the green in Helion Dock, jumps the same keel to First Soil (HC-V1-R5-S1). The buoy there jumps back.
- First Soil has its G-warm star, the flagship shard Green Wound, the Garden Belt, and Quiet Hollow. Quiet Hollow is a claimable Lagrange. No Compact exclusion sits on that pocket.
- A Claim Core starts in the hold. M fabricates another from four harvested mass.
- C inside Quiet Hollow plants the core. A dome, a glasswheat plot, a gravity pen, a crate, and a weak beacon anchor there. The claim shows in system view as a border and dome lights.
- The same plant in Helion Dock, including on Aegis Prime, is refused under Helion Compact law. The core stays in the hold.
- Glasswheat needs time, light, and water. G waters a growing plot and cuts a ripe one into food mass. The crop fails if the water runs out or the dome is ruptured.
- A hold-kine starts in the pen. N feeds it glasswheat, crate food, or starter fodder. It yields milk analogue while fed and dies if starved.
- U loads the kine. Anvil can carry one bare. Needle and Beak need the farm cassette, or a livestock pen fit with three harvested mass.
- T parks a perimeter gun. A feral miner ruptures an empty dome, can take a kine on the next pass, and cracks the core after that. The homestead freezes. The keel is not deleted. The ship in the pocket, or the parked gun, turns the miner away.
- Save and load keep the system, the claim, the crop timer, the kine, and the turret.
What is next (ordered):
1. Slice 6 — authored shakedown quest + one systemic Compact or Charter contract, both mutating world flags
Blocked by:
- Nothing in this repo blocks the next slice.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable. Helion Dock and Aegis Prime refuse a Claim Core.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- The farm cassette carries a hold-kine. It does not grow a crop.
- Quiet Hollow is the claimable pocket of Green Wound.
Files touched:
- claims/homestead.gd
- claims/pocket.gd
- data/first_soil.json
- data/modules.json
- data/system.json
- scripts/game.gd
- tests/slice5_sim.gd
- ui/hud.gd
- world/sector_sim.gd
- world/sector_view.gd
- LOOP_STATE.md
