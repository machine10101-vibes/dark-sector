LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 8 Density
Player-visible what works now:
- Slice 1 helm still holds. New game picks Vesper Needle, Anvil Barn, or Kestrel Beak. Thrust coasts. Zoom runs from hull to system. The gun fires in the same view you fly.
- Helion Dock (HC-V1-R1-S1) still has Helion, Aegis Prime, the ice ring, Seized Hold, the Helion Compact patrol, Hauler Holt, and The Unlet. The Unlet stays marked and closed. Green grace still arms here.
- Slice 2 craft still holds. Probes orbit, scan, and return. Drones bring raw mass home. A lost craft stays lost until rebuild spends returned mass. The fighter stays in the rack.
- The Salvage Tender launches when a wreck or a seized field is in reach, including the Swallow in Gyre. Away from a field it stays parked. The Livestock Lighter moves a hold-kine between the pen and the keel. Anvil can launch one bare. Any other hull wants the lighter dock.
- Slice 3 modules still hold, and the catalog is wider. Overload is still allowed. A keel stretch, extra hold, heavy turret, and missile rack make the reactor and the yaw complain. Two fits on the same starter no longer share an outline.
- Slice 4 war still holds. Shots travel in the sector. Hull HP, module HP, and hangar HP still matter. Heat still hails, fines, and brings guns. Heat and standing survive a lane.
- Slice 5 claim still holds. The Homestead Road still reaches First Soil. Quiet Hollow takes a Claim Core. Helion Dock and Aegis Prime refuse one. Glasswheat can ripen or fail. A hold-kine can live or starve. A raid can freeze the claim. The keel is not deleted.
- Voidbean, ember kale, and ghost gourd can be sown on a living claim. Voidbean dies in open light. Ember kale dies without heat or in the wet. Ghost gourd dies if the keeper leaves. Ash hens need grit and die hungry or in an open dome. Rock crabs drink the plot and die dry.
- Slice 6 quests still hold. Shakedown runs on any starter. Contracts now also send you to Ledger, Towline, Gyre, and Brass Lantern. Aegis Prime inspection, Tallyrock fine print, Green Wound blight, and the Swallow recovery each move a price, a fee, or a rumor.
- Slice 7 online still holds. Two captains can still contest Quiet Hollow. The loser is locked out. The keel is not the prize.
- Flyable atlas systems, each with a star, two or more bodies, a belt or ring, junk with an origin or a stream with a timer, a legal color, a reason to visit, scan layers, and someone living: Brass Lantern, Writ, White Wake, Ledger, Quiet Sun, Lease, Towline, Ore Choir, Two Weathers, Broken Charter, Perimeter, and Gyre. Helion Dock and First Soil remain.
- The spine runs Helion Dock, Brass Lantern, Lease, Towline, First Soil, Perimeter. Writ leaves the dock. Gyre is the hatch from First Soil and from Writ. Lane buoys use the atlas colors. Compact patrols the Core. Lease sells charter paper. Gyre and Perimeter keep a small rogue presence.
- Claims sit on garden pockets: First Soil, Two Weathers, Broken Charter, and Perimeter. Perimeter's law is red, so a hail still will not answer there. The old red box stays on the First Soil chart.
- The listen board includes the new systems. Save and load keep discoveries, claims, flags, and market prices.
What is next (ordered):
1. Slice 9 — data tools so a designer can add a module, crop, animal, system, or quest without rewriting code. Then fill the remaining atlas systems (Municipal, Glass, Marches, Black Sail) as content drops.
Blocked by:
- Nothing in this repo blocks the next slice.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- The Unlet stays unplantable. Helion Dock and Aegis Prime refuse a Claim Core.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- The farm cassette carries a hold-kine. It does not grow a crop. Crops grow on a claim plot.
- Garden pockets that take a core are First Soil, Two Weathers, Broken Charter, and Perimeter. The red box on First Soil keeps the Perimeter atlas id.
Files touched:
- claims/homestead.gd
- craft/orders.gd
- data/craft.json
- data/density.json
- data/factions.json
- data/first_soil.json
- data/modules.json
- data/quests.json
- data/ships.json
- data/system.json
- quests/board.gd
- scripts/game.gd
- tests/slice8_sim.gd
- world/chart.gd
- world/law.gd
- world/sector_sim.gd
- world/sector_view.gd
- LOOP_STATE.md
