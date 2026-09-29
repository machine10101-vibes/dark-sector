LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 6 Quests
Player-visible what works now:
- Slice 1 helm still holds. New game picks Vesper Needle, Anvil Barn, or Kestrel Beak. Thrust coasts. Zoom runs from hull to system. The gun fires in the same view you fly.
- Helion Dock (HC-V1-R1-S1) still has Helion, Aegis Prime, the ice ring, Seized Hold, the Helion Compact patrol, Hauler Holt, and The Unlet. The Unlet stays marked and closed.
- Slice 2 craft still holds. Probes orbit, scan, and return. Drones bring raw mass home. A lost craft stays lost until rebuild spends returned mass.
- Slice 3 modules still hold. The bay bolts and pulls cargo blister, cheek gun, survey mast, farm cassette, and armor belt. Overload is allowed. The silhouette and the handling follow the bolts.
- Slice 4 war still holds. Shots travel in the sector. Hull HP, module HP, and hangar HP still matter. The Red Keel pack holds outside the green. Heat still hails, fines, and brings guns. The dock beacon still welds. A broken keel still leaves a wreck and wakes at the dock.
- Slice 5 claim still holds. The Homestead Road reaches First Soil. Quiet Hollow takes a Claim Core. Helion Dock and Aegis Prime refuse one. Glasswheat can ripen or fail. A hold-kine can live or starve. A raid can freeze the claim. The keel is not deleted.
- J opens a quest log of data objects. Y marks the next system, body, claim, or patrol. The keel does not move. O takes an offered contract.
- Shakedown (authored_shakedown_01) runs on Needle, Barn, or Beak: undock, scan Aegis Prime, cut the ice ring or Seized Hold, bolt one module, live through a Red Keel contact, plant on Quiet Hollow, cut glasswheat, and keep the hold-kine alive for one more tick.
- A legal cut raises Compact standing and waives dock repair. An illegal cut leaves a warrant, and the patrol inspects the next time the keel enters Helion Dock. Both still matter after the arc is filed.
- Clerk Ivo Ram remembers which cut you made. The blueprint is a survey mast, cheek gun, or farm cassette you have not already bolted.
- Vesper hears the survey office. Anvil hears a Charter-adjacent factor ask for grain numbers. Kestrel hears the patrol lead on the pirate contact. The arc is the same.
- Planting the core unlocks homestead contracts on First Soil. The board can also offer a survey, a cull, a grain delivery, a craft recovery, or a pocket defense from live world state. Success and failure change standing, the glasswheat price, patrol presence, salvage, or a rumor.
- Save and load keep quest progress, the harvest flag, the offered contracts, and the mark.
What is next (ordered):
1. Slice 7 — Green / Amber / Red overlays + listen-server + second captain can contest a claim
Blocked by:
- Nothing in this repo blocks the next slice.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable. Helion Dock and Aegis Prime refuse a Claim Core.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- The farm cassette carries a hold-kine. It does not grow a crop.
- Quiet Hollow is the claimable pocket of Green Wound.
Files touched:
- data/quests.json
- quests/board.gd
- quests/log.gd
- tests/slice6_sim.gd
- ui/hud.gd
- world/sector_sim.gd
- world/sector_view.gd
- LOOP_STATE.md
