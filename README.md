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

The log is `user://dark_sector_save.json` (on Linux, under the Godot app-userdata folder for “Dark Sector”). In the browser build that same path is the origin’s IndexedDB, so Continue log stays on this machine.

## Browser

Play at [https://machine10101-vibes.github.io/dark-sector/](https://machine10101-vibes.github.io/dark-sector/).

The site is a Godot **4.7** HTML5 export with **thread support off**. GitHub Pages cannot send Cross-Origin-Isolation headers, so SharedArrayBuffer / threaded wasm would fail there. The `gh-pages` branch is only the static export (`index.html` at the branch root). Game source stays on `main`.

Export (needs Godot 4.7.x and the matching `web_nothreads_*` export templates):

```bash
./tools/export_web.sh
```

That writes gitignored files under `export/web/`. Asset URLs use `<base href="/dark-sector/">`, so a local smoke test must serve the folder as that path prefix, not as `/`. Publish the folder to `gh-pages` with `./tools/export_web.sh --deploy`.

If the URL 404s, the repo still needs Pages pointed at the `gh-pages` branch, folder `/` (Settings → Pages → Deploy from a branch). The Pages API is often blocked; pushing the branch is the part this repo can do on its own.

## Helm

| Input | Action |
|---|---|
| W / S | Thrust / retro |
| A / D | Yaw |
| Q / E | Strafe |
| Space | Gun |
| Wheel, = / - | Zoom, tactical to sector |
| 1 / 2 / 3 | Launch probe / harvester / boat |
| B H D F J K | Bay, hangar, dossier, heat, quests, homestead |

Homestead (K), inside Hollow Latch: print a Claim Core from cinder-ore, plant it, raise the ash dome, sow ember kale, stock an ash hen and feed her kale. A stake turret wants keel salvage. If a Red Keel sits on an undefended core, the homestead freezes and the ship stays.
| Hold, or Esc | Pause. Write or read the log from that card |
| F5 / F9 | Write / read the log without pausing |

Some window managers bind Esc and F5. The **Hold** button on the helm opens the same card.

Pick one keel at new game: Needle (Vesper), Barn (Anvil), or Beak (Kestrel). The yard has one module. Bolting it changes the top-down silhouette. It does not come off.

## Slice

See `LOOP_STATE.md` for what is in this build and what the next pass should do. `PLAYTEST.md` is the short checklist for this slice.
