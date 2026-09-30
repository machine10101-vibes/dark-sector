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
| W / Up | Thrust. From the dock this casts off. Hold it. |
| S / Down | Retro. Also casts off. |
| Cast off | Button under the flight line while moored. Same as holding W. |
| A / D | Yaw nose left / nose right. D is yaw. |
| Q / E | Strafe |
| Space | Gun |
| Wheel, = / - | Zoom, tactical to sector |
| 1 / 2 / 3 | Launch probe / harvester / boat |
| I | Scan dossier |
| Board, or [ | Helion Dock board. Scan and ring-haul slips, paid into the purse. |
| B H I F J K | Bay, hangar, dossier, heat, quests, claim |
| Hold, or Esc | Pause. Write or read the log from that card |
| F5 / F9 | Write / read the log without pausing |

Some window managers bind Esc and F5. The **Hold** button on the helm opens the same card.

### Cast off

The title is the Helion limb and the ice rings, with one keel in that sky. New keel puts that hull in the yard. Take the Needle and the pad is still the start.

A new Needle starts moored at the Helion Dock pad. The flight line reads “Moored at Helion Dock. Hold W or Cast off.”

1. In the browser build the canvas is focused when the sector starts. If the keys stay quiet, click the sky once.
2. Hold **W** or **Up**. The log says “Cast off. Helion Dock is behind you.” and speed leaves 0.
3. The **Cast off** button does that same shove if a hint, scroll, or leftover text field has focus. W is also the UI “up” key, so the helm records it before any focused control can eat it.

A and D yaw while moored. They do not leave the pad. S, Q, and E do. Once you are off the pad, A/D turns the path with the nose, Q/E steps sideways, and the camera follows the keel.

### Helion Dock board

The **Board** button sits beside Cast off while the keel is on the Helion pad. The same slate is on the bottom action row. `[` opens it too.

1. **Take Seal Aegis Prime.** Launch a probe (Probe button or 1). It reads Aegis Prime, not the nearer ice ring. When that dossier seals while Moored, or the next time the pad has the keel, the log says “Aegis scan filed. Helion Dock paid 80. Purse 80.”
2. **Take Crate to the ice ring.** A dock crate enters the hold. The log says “Hold toward the ice ring — don't clear the band yet.” An amber marker reads **Aegis ice ring** and the meters. Hold toward it. That burn stays on the band. Touch the ring, then bring the crate back to the pad. The log says “Ring haul filed. Helion Dock paid 120.” The purse line on the helm shows the total.

### Open chart

Hold W outward. Past the band the keel stays moving and the chart names Aegis Prime plus the lanes (Homestead Road, Green Spine, Writ Lane). The city stays closed if you burn into the crust; the log points back out to those lanes. The origin/focus/render overlay is omitted on the web build.

Slips are taken only on the pad. A full hold refuses the crate. Each slip pays once. Cast off is unchanged: W or the Cast off button still leaves the dock.

To come back, fly until the card shows **Helion Dock** under 200 m. That moors from any heading and any speed, including a stop, whether the line says Local or Tactical. Inside 500 m the **Dock** button forces the same snap. The line reads Moored, and Cast off and Board are available again. The card’s Helion Dock meters are the range to the pad. The scale bar is only the zoom. A key that is still held down waits until you release it.

Pick one keel at new game: Needle (Vesper), Barn (Anvil), or Beak (Kestrel). The yard has one module. Bolting it changes the top-down silhouette. It does not come off.

## Slice

See `LOOP_STATE.md` for what is in this build and what the next pass should do. `PLAYTEST.md` is the short checklist for this slice.
