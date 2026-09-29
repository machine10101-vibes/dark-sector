# Playtest — Helion Dock helm

Godot 4.7, windowed. One pass is enough if each line is done in the window.

1. **New keel.** Needle, Barn, and Beak are different shapes.
2. **Take the Needle.** The sky is Helion Dock: star Helion, Aegis Prime, an ice ring, Seized Hold (confiscated hulls), a moving Helion Compact patrol, Hauler Holt, and The Unlet marked closed.
3. **Coast.** Thrust, then let go. The hull keeps drifting.
4. **Zoom.** Out until the star and Aegis read together. In until the silhouette is readable.
5. **Gun.** Space fires a shot.
6. **Log.** F5. Leave the dock. F9 or Continue log. Same hull, same place, still Helion Dock.

```bash
godot --headless --path . --script res://tests/slice1_sim.gd
```

Headless host, same sim as Host the dock. It listens on 24565 and keeps `user://dark_sector_host.json`. A second window joins `127.0.0.1:24565`.

```bash
godot --headless --path . --script res://scripts/headless_host.gd
```
