LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: Helion Dock helm (HC-V1-R1-S1)
Player-visible what works now:
- New game picks exactly one keel: Vesper Needle, Anvil Barn, or Kestrel Beak. The three silhouettes differ. Names were not changed.
- Helion Dock is one top-down system: star Helion, Aegis Prime with an ice ring, Seized Hold (hulls confiscated at inspection), a Helion Compact patrol, civilian Hauler Holt, and The Unlet, a marked pocket that cannot be planted.
- Helm is inertial: thrust, retro, strafe, independent yaw, camera zoom from hull to system.
- The fixed gun fires.
- F5 and F9 write and read the log: hull choice, position, and system id HC-V1-R1-S1.
- Vellum Compact and Red Keel remain in the faction list. They are not this sky, and they were not renamed.
What is next (ordered):
1. Do not open probes, yard modules, claim planting, quests, or PvP on this dock until a later slice asks for them.
2. A second flyable HC-V1 system, still without renaming Helion Dock.
Blocked by:
- Nothing in this repo blocks a later slice. This one stops at the helm gate.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable while Compact Core law says almost no claims.
- Helion Compact is the dock patrol. Vellum Compact is a different faction.
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
- PLAYTEST.md
- LOOP_STATE.md
