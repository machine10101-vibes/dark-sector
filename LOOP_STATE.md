LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 2 Survey Probe + Harvest Drone
Player-visible what works now:
- Slice 1 helm still holds. New game picks Vesper Needle, Anvil Barn, or Kestrel Beak. The three silhouettes differ. The Needle plate has bone, glass, and a nozzle inside the same hull.
- Helion Dock (HC-V1-R1-S1): star Helion, Aegis Prime, ice ring, Seized Hold, a moving Helion Compact patrol, Hauler Holt, and The Unlet.
- Thrust coasts. Zoom runs from hull to system. The gun fires. Save and load keep the hull and the position.
- A survey probe seals Aegis Prime in layers, including the Guard's legal title.
- A harvest drone brings ring ice aboard and the seam depletes. The city is not a homestead.
- The yard mast still bolts and lengthens the Needle.
- The Unlet stays marked and closed. A shuttle can fly there and cannot plant it.
What is next (ordered):
1. No further slice was started. The Unlet stays unplantable.
Blocked by:
- Nothing in this repo blocks a later slice.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable while Compact Core law says almost no claims.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- Ring ice is the dock's surveyed cut. The city crust is not a claim.
- Hull loss still wrecks the capital ship in place.
Files touched:
- data/system.json
- data/craft.json
- craft/orders.gd
- ships/silhouette.gd
- tests/slice2_sim.gd
- LOOP_STATE.md
