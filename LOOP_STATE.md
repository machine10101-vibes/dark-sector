LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: Live-Ops 1
Player-visible what works now:
- The spine still flies: Helion Dock, Brass Lantern, Lease, First Soil, Perimeter, Marchport, Black Quay. Each of those has a star and a body. The red road is not an empty chart.
- A lane refuses while a craft is still out. If the lane is taken anyway, that craft is lost where it was. It does not appear on the new buoy.
- Green capitals refuse a Claim Core. Helion Dock still refuses one by name. Quiet Hollow still takes one. A core crack still needs the full timer. Green grace still keeps a new Helion keel at one hull point. A criminal flag still reads on scan.
- An overloaded Anvil yaws and accelerates like a barn. A naked Vesper that stays in a Red Keel pack and shoots breaks. A Kestrel wins a two-skiff fight. A claim with no fodder and no crate food loses the hold-kine. Starter fodder keeps it through the same window. Patrol heat at hail range brings a cutter in, and guns follow once the heat is hot.
- Salvage, a dock fee, and a grain price each leave a world flag.
- Drop JSON still loads with no script edit. This drop: Cheek Fin, Belly Spine, Lamp Jaw. Cinder millet. Lamp moth. Choir ash window and Unpaid tow. Glass coda on Choir Gate. Stolen coda for Black Sail. False Rain on Nameless Chart. Missed Windows on Clockstream.
- Host the dock and Dedicated host are the same listen sim. Headless: godot --headless --path . --script res://scripts/headless_host.gd. The world log is user://dark_sector_host.json. A host restart keeps the claim, crop, animal, layout, lost craft, cargo, heat, warrant, quest flag, and discovery. A second client can join that host.
What is next (ordered):
1. Live-Ops 2 — player count per system, insurance/wreck tuning, more HC-V1 authored hooks, art loop Gate 2+ on three starters
Blocked by:
- Nothing in this repo blocks Live-Ops 2. Do not add a pillar, a second veil, or a new region pass.
Open design decisions (max 5):
- Planets stay on fixed positions until a later pass adds orbits.
- The Unlet stays unplantable. Helion Dock and green capitals refuse a Claim Core.
- Helion Compact is the dock patrol. Vellum Compact is a different faction and was not renamed.
- The farm cassette carries a hold-kine. It does not grow a crop. Crops grow on a claim plot.
- A pocket takes a core only when claim_slots.json names it. The red box on First Soil keeps the Perimeter atlas id.
Files touched:
- claims/homestead.gd
- data/ships.json
- life/animals/lamp_moth.json
- life/crops/cinder_millet.json
- modules/belly_spine.json
- modules/cheek_fin.json
- modules/fit.gd
- modules/lamp_jaw.json
- quests/authored/glass_coda.json
- quests/authored/stolen_coda.json
- quests/board.gd
- quests/templates/choir_ash_window.json
- quests/templates/unpaid_tow.json
- scripts/game.gd
- scripts/headless_host.gd
- scripts/main.gd
- tests/liveops_sim.gd
- tools/catalog.gd
- ui/menu.gd
- world/hc_v1/streams.json
- world/hc_v1/systems/HC-V1-R6-S2.json
- world/hc_v1/systems/HC-V1-R6-S3.json
- world/hc_v1/trash_origins.json
- world/sector_sim.gd
- PLAYTEST.md
- LOOP_STATE.md
