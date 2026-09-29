LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 3 Modules
Player-visible what works now:
- Slice 1 helm still holds. New game picks Vesper Needle, Anvil Barn, or Kestrel Beak. Thrust coasts. Zoom runs from hull to system. The gun fires.
- Helion Dock (HC-V1-R1-S1) still has Helion, Aegis Prime, the ice ring, Seized Hold, the Helion Compact patrol, Hauler Holt, and The Unlet.
- Slice 2 craft still holds. Probes orbit, scan, and return. Drones bring raw mass home. Illegal cuts raise Helion Compact heat. A lost craft stays lost until rebuild spends returned mass.
- The ship bay lists a module grid with mass, power, crew budget, and a live top-down silhouette. Center of mass and thrust-to-weight update when a part is bolted or pulled.
- Five parts, data in modules.json: cargo blister, cheek gun, survey mast, farm cassette, armor belt. Each one changes the outline. The hull planform underneath stays Needle, Barn, or Beak.
- The blister fattens the waist and adds hold. The cheek gun breaks the outline and draws power. The mast lengthens the ship and raises signature and sensor range. The farm cassette is a dome bump. The armor belt widens the profile and sheds starter-gun damage.
- Overload is allowed. A pig-heavy keel turns and accelerates worse. Pulling the parts restores the old silhouette and the old handling. The bay stays shut while a fight is on.
- Hangar craft stay in the rack when modules are bolted. Save and load restore the layout, the silhouette, the stats, the cargo, the heat, and which craft are alive.
- The Unlet stays marked and closed.
What is next (ordered):
1. Slice 4 — pirate pack combat + PDO heat consequences in Helion Dock / adjacent pocket
Blocked by:
- Nothing in this repo blocks the next slice.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable while Compact Core law says almost no claims.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- One of each module this slice. The grid is the pattern for a larger catalog later.
- The farm cassette is a bolted dome. It does not grow anything yet.
Files touched:
- data/modules.json
- data/ships.json
- modules/fit.gd
- ships/silhouette.gd
- world/sector_sim.gd
- world/sector_view.gd
- ui/hud.gd
- ui/menu.gd
- tests/slice3_sim.gd
- LOOP_STATE.md
