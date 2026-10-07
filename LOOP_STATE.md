LOOP STATE
==========
Build: Godot 4.7.2 stable, GL Compatibility
Slice just completed: Plasma gatherer, ore belts, wreck plate, fabrication
Player-visible what works now:
- New game picks exactly one keel: Vesper Needle, Anvil Barn, or Kestrel Beak. Silhouettes differ before and after the yard module.
- Ashen Reach is one top-down system: Ash Lamp, Cinder, Mire, Vellum, the Slat, Hollow Latch, a Vellum Compact patrol, and a Red Keel pack. Green, amber, and dark rule layers are in the same view.
- Helm is inertial: thrust, retro, strafe, independent yaw, camera zoom from tactical to sector.
- A survey probe writes a layered dossier. A harvest drone returns ore and depletes the deposit. Barn can send a salvage tender; Beak can send a fighter and an away shuttle that marks Hollow Latch surveyed.
- The yard module bolts once, changes the top-down silhouette, and changes mass, power, cargo, or the gun. Spare power can reject a module. The keel warns when the frame is over mass.
- Skiffs and the player share one hull path. Wrecks keep the dead agent id. A green-lane shot or a protected harvest writes heat and faction memory.
- Hold, Esc, F5, and F9 write and read the log: ship layout, craft, crew, claim homestead, heat, quest flags, galaxy seed, zoom.
- Origin quests are on the slate and dormant.
- Hollow Latch takes a Claim Core printed from two cinder-ore and planted inside the pocket. An ash dome, one ember-kale sowing (cinder-heat), one ash hen that dies if unfed, and a stake turret bought with keel salvage. A Red Keel on an undefended stake cracks the core and freezes the dome, crop, and hen without deleting the ship. Replanting wakes the same stake.
- Every keel mounts a plasma gatherer. Right-click a rock, torn plate, or abandoned hull inside beam range and the barrel extends a plasma column until the node is a husk, the hold is full, or the keel slips out of range. Rust Arc (iron), Pale Shelf (aluminum), Copper Vein, and King's Drift (gold) are large belts. Keel Grave and Quiet Debris are torn-plate fields. Five abandoned hulls drift in the dark. A kill throws extra battle plate around the wreck; the tender's one keel-salvage is unchanged.
- The bay fabricator spends that ore. Coil Cannon, Ion Booster, and Plated Armor bolt onto Weapon, Drive, and Plate hardpoints, change the silhouette, and stay on. Reactor spare can refuse a drawing. Depleted seams and battle debris survive the log.
What is next (ordered):
1. A second module, and keel-shear that can disable a module in combat.
2. One starter origin quest that changes a patrol route or a beacon when it completes.
3. Fabricator rebuild of a lost craft from salvage.
4. PDO hail choices: submit, pay the fine, or refuse.
5. A second climate and a second species, still on this stake, before any new system.
Blocked by:
- Nothing in this repo blocks the next slice. Multiplayer is not required; heat, wrecks, and claim ownership already use agent ids.
Open design decisions (max 5):
- Planets stay on fixed positions until a later slice adds orbits.
- Wreck loot from the tender is still one keel-salvage plus at most one cargo unit. Plasma plate around a fresh wreck is extra, and it does not spend wreck rights.
- Fabricated parts do not come off. The gatherer is on every playable keel, including the Beak, which still has no harvest drone.
- Ember kale is the only crop that matches Hollow Latch cinder-heat. The ash hen eats that kale and dies of hunger; a freeze pauses her and does not kill her.
- Core crack is a living Red Keel inside the stake radius while the turret is down, or sitting on the stake even if the turret is up. Replant uses a new core and the same dome.
Files touched:
- project.godot
- icon.svg
- README.md
- PLAYTEST.md
- LOOP_STATE.md
- CONTINUE_PROTOCOL.md
- DARK_SECTOR_ONLINE_GDD.md
- DARK_SECTOR_ONLINE_MASTER_PROMPT.md
- data/ships.json
- data/modules.json
- data/craft.json
- data/system.json
- data/factions.json
- data/quests.json
- data/claim.json
- data/harvest.json
- export_presets.cfg
- tools/export_web.sh
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
- tests/slice5_claim.gd
- tests/slice_harvest.gd
- world/plasma_harvest.gd
- world/body_render.gd
