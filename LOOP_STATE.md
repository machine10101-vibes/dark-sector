LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 7 Online
Player-visible what works now:
- Slice 1 helm still holds. New game picks Vesper Needle, Anvil Barn, or Kestrel Beak. Thrust coasts. Zoom runs from hull to system. The gun fires in the same view you fly.
- Helion Dock (HC-V1-R1-S1) still has Helion, Aegis Prime, the ice ring, Seized Hold, the Helion Compact patrol, Hauler Holt, and The Unlet. The Unlet stays marked and closed.
- Slice 2 craft still holds. Probes orbit, scan, and return. Drones bring raw mass home. A lost craft stays lost until rebuild spends returned mass.
- Slice 3 modules still hold. The bay bolts and pulls cargo blister, cheek gun, survey mast, farm cassette, and armor belt. Overload is allowed. The silhouette and the handling follow the bolts.
- Slice 4 war still holds. Shots travel in the sector. Hull HP, module HP, and hangar HP still matter. The Red Keel pack holds outside the green. Heat still hails, fines, and brings guns. The dock beacon still welds. A broken keel still leaves a wreck and wakes at the dock.
- Slice 5 claim still holds. The Homestead Road reaches First Soil. Quiet Hollow takes a Claim Core. Helion Dock and Aegis Prime refuse one. Glasswheat can ripen or fail. A hold-kine can live or starve. A raid can freeze the claim. The keel is not deleted.
- Slice 6 quests still hold. Shakedown runs on any starter. A legal cut and an illegal cut still change the world after the arc. Y marks a place and does not move the keel. Save and load keep the flags.
- The same map paints law. Green is the Helion Dock lanes and the Aegis Prime orbit. Amber is the ice-ring lease, First Soil claim country, and Seized Hold when no Compact cutter is on the field. Red is a Perimeter box on the First Soil outer belt, atlas id HC-V1-R5-S6. The color is on the HUD and on the chart.
- A shot on another captain in the green writes a warrant and the patrol closes. Guns in the red do not. A flagged fight, or a fight on a living claim, stays legal in the amber.
- Host the dock opens a listen port. A second captain joins by IP or code. Both fly Helion Dock with the same hull, HP, and module rules. An empty host is still the NPC dock. Offline new game still works.
- Each captain has a player id, layout, cargo, and heat. Quiet Hollow's slot id is HC-V1-R5-S1:green_wound:quiet_hollow.
- A second captain can crack a planted core on a timer. The owner can shoot, recall craft, or pay a Compact hail if they have standing and are not in the red. The crack flares on the chart. Success transfers the homestead and locks the loser out. The loser's ship stays. A broken keel still drops only part of the hold.
- A new keel has a short green grace in Helion Dock. A warrant shows on the ship. Enter is a single local channel.
- The host log keeps both captains, the claim, the wrecks, and the flags.
What is next (ordered):
1. Slice 8 — density: fill Compact Core + First Soil neighbors from the HC-V1 atlas, more modules, more contracts, no clone rocks
Blocked by:
- Nothing in this repo blocks the next slice.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable. Helion Dock and Aegis Prime refuse a Claim Core.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- The farm cassette carries a hold-kine. It does not grow a crop.
- Quiet Hollow is the claimable pocket of Green Wound. Perimeter this slice is a red box on that chart, not a full system.
Files touched:
- claims/homestead.gd
- craft/orders.gd
- data/first_soil.json
- net/listen.gd
- scripts/game.gd
- scripts/main.gd
- tests/slice7_sim.gd
- ui/hud.gd
- ui/menu.gd
- world/law.gd
- world/sector_sim.gd
- world/sector_view.gd
- LOOP_STATE.md
