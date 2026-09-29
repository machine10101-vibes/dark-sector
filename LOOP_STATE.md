LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: 9 Tools + atlas fill
Player-visible what works now:
- Slice 1 helm still holds. New game picks Vesper Needle, Anvil Barn, or Kestrel Beak. Thrust coasts. Zoom runs from hull to system. The gun fires in the same view you fly.
- Helion Dock (HC-V1-R1-S1) still has Helion, Aegis Prime, the ice ring, Seized Hold, the Helion Compact patrol, Hauler Holt, and The Unlet. The Unlet stays marked and closed. Green grace still arms here.
- Slice 2 craft still holds. Probes orbit, scan, and return. Drones bring raw mass home. A lost craft stays lost until rebuild spends returned mass. The fighter stays in the rack.
- The Salvage Tender launches when a wreck or a seized field is in reach, including the Swallow in Gyre. Away from a field it stays parked. The Livestock Lighter moves a hold-kine between the pen and the keel. Anvil can launch one bare. Any other hull wants the lighter dock.
- Slice 3 modules still hold. Overload is still allowed. A keel stretch, extra hold, heavy turret, and missile rack make the reactor and the yaw complain. Two fits on the same starter no longer share an outline.
- Drop a module JSON in modules/ and the yard can bolt it. Keel Cage lengthens any starter. F3 opens the data desk: reload, spawn a system by id, grant a module, crop, animal, or quest flag, and print why_visit with the rule color.
- Slice 4 war still holds. Shots travel in the sector. Hull HP, module HP, and hangar HP still matter. Heat still hails, fines, and brings guns. Heat and standing survive a lane.
- Slice 5 claim still holds. The Homestead Road still reaches First Soil. Quiet Hollow takes a Claim Core. Helion Dock and Aegis Prime refuse one. Glasswheat can ripen or fail. A hold-kine can live or starve. A raid can freeze the claim. The keel is not deleted.
- Voidbean, ember kale, and ghost gourd can be sown on a living claim. Silkreed is data: motion kills it. Ember kale dies without heat or in the wet. Ghost gourd dies if the keeper leaves. Ash hens need grit. Rock crabs drink the plot. Ribbon goats are data: hunger or an open dome kills them.
- Slice 6 quests still hold. Shakedown runs on any starter. Contracts still send you to Ledger, Towline, Gyre, and Brass Lantern. Aegis Prime inspection, Tallyrock fine print, Green Wound blight, and the Swallow recovery each move a price, a fee, or a rumor.
- Authored quests and the meteor-window template load from JSON. The jurisdiction hole run is Dock, Not Ours, Empty Tithe. Spindle, Ash Hymn, Step, Quay, and the Swallow change standing, heat, prices, patrols, claim law, or rumors. They do not grant XP.
- Slice 7 online still holds. Two captains can still contest Quiet Hollow. The loser is locked out. The keel is not the prize. Green, amber, and red still come from the system files. A bad JSON file is logged and skipped. It does not take down the host.
- Slice 8 spine still holds: Brass Lantern, Writ, White Wake, Ledger, Quiet Sun, Lease, Towline, Ore Choir, Two Weathers, Broken Charter, Perimeter, and Gyre. Helion Dock and First Soil remain.
- Municipal Skies, Glass Quarantine, the rest of the Drift, the Rimward Marches, and Black Sail Grounds are on the board as data. Each has a star, bodies, a belt or ring, junk or a stream, a legal color, a why_visit, scan layers, and one living use.
- The red road runs Perimeter, Marchport, Black Quay. Black Quay is a red port. Choir Gate is a checkpoint: living cargo is taken unless the hold has Glass standing.
- Claims sit only on filed slots: First Soil, Two Weathers, Broken Charter, Perimeter, and Claimwake. Not Ours does not take a core.
- The listen board loads the new systems from the same data. Save and load keep discoveries, claims, flags, and market prices.
What is next (ordered):
1. Live-ops only — more modules, quests, balance, dedicated server, art-gate climb. First game is complete. Do not invent Veil 2 until HC-V1 stays full under real players.
Blocked by:
- Nothing in this repo blocks live-ops. Do not start a new region or a new rules pass.
Open design decisions (max 5):
- Planets stay on fixed positions until a later pass adds orbits.
- The Unlet stays unplantable. Helion Dock and Aegis Prime refuse a Claim Core.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- The farm cassette carries a hold-kine. It does not grow a crop. Crops grow on a claim plot.
- A pocket takes a core only when claim_slots.json names it. The red box on First Soil keeps the Perimeter atlas id.
Files touched:
- claims/homestead.gd
- craft/marker_buoy.json
- factions/black_sail.json
- factions/glass_choir.json
- factions/municipal_navy.json
- life/animals/ribbon_goats.json
- life/crops/silkreed.json
- modules/keel_cage.json
- quests/authored/ash_hymn.json
- quests/authored/jurisdiction_hole.json
- quests/authored/quay.json
- quests/authored/spindle.json
- quests/authored/step.json
- quests/authored/swallow.json
- quests/board.gd
- quests/templates/meteor_window.json
- scripts/game.gd
- scripts/main.gd
- tests/slice9_sim.gd
- tools/catalog.gd
- ui/debug_pane.gd
- world/hc_v1/claim_slots.json
- world/hc_v1/lanes.json
- world/hc_v1/streams.json
- world/hc_v1/systems/
- world/hc_v1/trash_origins.json
- world/sector_sim.gd
- LOOP_STATE.md
