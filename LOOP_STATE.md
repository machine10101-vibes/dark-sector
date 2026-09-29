LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 1 Helm
Player-visible what works now:
- New game picks exactly one keel: Vesper Needle, Anvil Barn, or Kestrel Beak. The three silhouettes differ. Names were not changed.
- Helion Dock (HC-V1-R1-S1) is the flyable system: star Helion, Aegis Prime with an ice ring, Seized Hold (confiscated hulls), a moving Helion Compact patrol, civilian Hauler Holt, and The Unlet, a marked pocket that cannot be planted.
- Helm is inertial: thrust, rotate, follow camera, zoom from hull to system. The ship keeps sliding after thrust stops.
- The gun fires.
- Save and load keep the hull choice and the position in Helion Dock.
What is next (ordered):
1. Slice 2 Survey Probe + Harvest Drone
Blocked by:
- Nothing in this repo blocks Slice 2. This session stops at the helm gate.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable while Compact Core law says almost no claims.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- Meteor damage and claim caps stay with the galaxy loop, not this helm.
- Hull loss still wrecks the capital ship in place.
Files touched:
- data/system.json
- data/factions.json
- world/sector_sim.gd
- world/sector_view.gd
- net/ownership.gd
- factions/heat.gd
- claims/pocket.gd
- ui/menu.gd
- ui/hud.gd
- tests/slice1_sim.gd
- LOOP_STATE.md
