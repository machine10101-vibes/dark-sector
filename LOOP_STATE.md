LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: Ashen Reach helm
Player-visible what works now:
- New game picks exactly one keel: Vesper Needle, Anvil Barn, or Kestrel Beak. Silhouettes differ before and after the yard module.
- Ashen Reach is one top-down system: Ash Lamp, Cinder, Mire, Vellum, the Slat, Hollow Latch, a Vellum Compact patrol, and a Red Keel pack. Green, amber, and dark rule layers are in the same view.
- Helm is inertial: thrust, retro, strafe, independent yaw, camera zoom from tactical to sector.
- A survey probe writes a layered dossier. A harvest drone returns ore and depletes the deposit. Barn can send a salvage tender; Beak can send a fighter and an away shuttle that marks Hollow Latch surveyed.
- The yard module bolts once, changes the top-down silhouette, and changes mass, power, cargo, or the gun. Spare power can reject a module. The keel warns when the frame is over mass.
- Skiffs and the player share one hull path. Wrecks keep the dead agent id. A green-lane shot or a protected harvest writes heat and faction memory.
- Hold, Esc, F5, and F9 write and read the log: ship layout, craft, crew, claim flag, heat, quest flags, galaxy seed, zoom.
- Origin quests are on the slate and dormant. No claim core is planted.
What is next (ordered):
1. Claim core at Hollow Latch: one dome, one climate crop, one animal, a defense, and core loss that freezes the homestead without deleting the ship.
2. A second module, and keel-shear that can disable a module in combat.
3. One starter origin quest that changes a patrol route or a beacon when it completes.
4. Fabricator rebuild of a lost craft from salvage.
5. PDO hail choices: submit, pay the fine, or refuse.
Blocked by:
- Nothing in this repo blocks the next slice. Multiplayer is not required; heat, wrecks, and claim ownership already use agent ids.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- Wreck loot is one keel-salvage plus at most one cargo unit.
- Kestrel starts without a harvest drone, matching her rack.
- Heat this slice: +8 per green-lane shot, engage at 40, protected harvest +28, killed patrol +36, killed skiff +10 and the pack enrages.
- Hull loss wrecks the capital ship in place. Boarding is later.
Files touched:
- project.godot
- icon.svg
- README.md
- PLAYTEST.md
- LOOP_STATE.md
- data/ships.json
- data/modules.json
- data/craft.json
- data/system.json
- data/factions.json
- data/quests.json
- scripts/game.gd
- scripts/main.gd
- scripts/serde.gd
- scenes/main.tscn
- ships/silhouette.gd
- modules/fit.gd
- craft/orders.gd
- world/sector_sim.gd
- world/sector_view.gd
- factions/heat.gd
- quests/log.gd
- claims/pocket.gd
- net/ownership.gd
- ui/theme_kit.gd
- ui/menu.gd
- ui/hud.gd
- audio/tones.gd
- tests/slice1_sim.gd
