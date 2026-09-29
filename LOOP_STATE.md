LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 4 War
Player-visible what works now:
- Slice 1 helm still holds. New game picks Vesper Needle, Anvil Barn, or Kestrel Beak. Thrust coasts. Zoom runs from hull to system. The gun fires in the same view you fly.
- Helion Dock (HC-V1-R1-S1) still has Helion, Aegis Prime, the ice ring, Seized Hold, the Helion Compact patrol, Hauler Holt, and The Unlet.
- Slice 2 craft still holds. Probes orbit, scan, and return. Drones bring raw mass home. A lost craft stays lost until rebuild spends returned mass.
- Slice 3 modules still hold. The bay bolts and pulls cargo blister, cheek gun, survey mast, farm cassette, and armor belt. Overload is allowed. The silhouette and the handling follow the bolts. Save and load keep the layout.
- Combat stays in the sector. Shots travel. The capital keel has hull HP and module HP. A dark module stops lending its bonus. A hangar at zero will not recall craft and will not take them aboard until it is welded.
- Three Red Keel skiffs hold just outside the green lane, off Seized Hold. They wear scavenged parts. One closes. One holds range. They hunt a probe or drone before they hunt the keel. Burn into the deep green and they break off unless you keep firing.
- Helion Compact heat is on the helm. A first shot in sight of the patrol hails you. Higher heat fines one unit of cargo. At the gun line the patrol fires. Shooting the patrol spikes the slate and makes them hostile. A pirate who shot you first eases the slate. An unprovoked kill in the trash field adds a little heat.
- The dock beacon by Aegis Prime spends one harvested mass to weld hull, hangar, and modules. A broken keel leaves a wreck with part of the hold, keeps the layout, and wakes you at Helion Dock. Save and load keep heat, the slate marks, hull and hangar damage, and wrecks.
- The Unlet stays marked and closed.
What is next (ordered):
1. Slice 5 — Claim Core + one crop + one animal on a Garden Shards pocket (HC-V1-R5-S1 First Soil / Green Wound). Do not allow planting in Compact Core.
Blocked by:
- Nothing in this repo blocks the next slice.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable while Compact Core law says almost no claims.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- The farm cassette is a bolted dome. It does not grow anything yet.
- Red Keel names and the helion_compact faction id stay as they are.
Files touched:
- data/system.json
- world/sector_sim.gd
- world/sector_view.gd
- craft/orders.gd
- modules/fit.gd
- net/ownership.gd
- ui/hud.gd
- tests/slice1_sim.gd
- tests/slice2_sim.gd
- tests/slice4_sim.gd
- LOOP_STATE.md
