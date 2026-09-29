LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 2 Craft
Player-visible what works now:
- Slice 1 helm still holds. New game picks Vesper Needle, Anvil Barn, or Kestrel Beak. Thrust coasts. Zoom runs from hull to system. The gun fires. Save and load keep the hull and the position.
- Helion Dock (HC-V1-R1-S1): star Helion, Aegis Prime, ice ring, Seized Hold, a moving Helion Compact patrol, Hauler Holt, and The Unlet.
- Hangar lists the rack. Vesper: two Survey Probes and one Harvest Drone. Anvil: one Survey Probe, one Harvest Drone, one Salvage Tender parked. Kestrel: one Survey Probe and one Fighter parked.
- A probe can be ordered to orbit, scan, or return. Orbit writes nothing. Scan seals a dossier.
- Dossier layers for Aegis Prime, the ice ring, and the trash field: orbit, atmosphere, surface, crust, biosign, ruins, legal title.
- Legal titles: Aegis Prime is Helion Compact protected. The ice ring is a Compact lease, limited harvest. The trash field is Compact seized property.
- A harvest drone spends time on a scanned node and brings raw mass back to cargo.
- Cutting Aegis Prime or the trash field adds PDO heat on the helm. A small ice-ring cut adds less.
- A probe or drone that hits the planet, the star, or the patrol is lost. Rebuild spends one unit of returned mass. Save and load keep cargo, heat, and which craft are alive.
- The Unlet stays marked and closed.
What is next (ordered):
1. Slice 3 — one cargo blister or gun module that changes silhouette and mass
Blocked by:
- Nothing in this repo blocks the next slice.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable while Compact Core law says almost no claims.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- Returned mass is one cargo good. Rebuild spends one unit of it.
- The tender and the fighter stay parked until a later slice gives them work.
Files touched:
- data/system.json
- data/ships.json
- data/craft.json
- craft/orders.gd
- world/sector_sim.gd
- world/sector_view.gd
- ui/hud.gd
- tests/slice2_sim.gd
- LOOP_STATE.md
