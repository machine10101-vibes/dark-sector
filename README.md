# Dark Sector

Top-down working-captain sector. One persistent keel, detachable craft, heat, and a claim pocket. This repo is the Ashen Reach helm slice.

## Run

Godot **4.7.x** with the GL Compatibility renderer. The project does not vendor the editor binary.

```bash
godot --path . --rendering-driver opengl3
```

Headless rules check:

```bash
godot --headless --path . --script res://tests/slice1_sim.gd
```

The log is `user://dark_sector_save.json` (on Linux, under the Godot app-userdata folder for “Dark Sector”).

## Helm

| Input | Action |
|---|---|
| W / S | Thrust / retro |
| A / D | Yaw |
| Q / E | Strafe |
| Space | Gun |
| Wheel, = / - | Zoom, tactical to sector |
| 1 / 2 / 3 | Launch probe / harvester / boat |
| B H D F J K | Bay, hangar, dossier, heat, quests, claim |
| Hold, or Esc | Pause. Write or read the log from that card |
| F5 / F9 | Write / read the log without pausing |

Some window managers bind Esc and F5. The **Hold** button on the helm opens the same card.

Pick one keel at new game: Needle (Vesper), Barn (Anvil), or Beak (Kestrel). The yard has one module. Bolting it changes the top-down silhouette. It does not come off.

## Slice

See `LOOP_STATE.md` for what is in this build and what the next pass should do. `PLAYTEST.md` is the short checklist for this slice.
