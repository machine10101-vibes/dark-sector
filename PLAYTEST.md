# Playtest — Dark Sector Online

The game is Dark Sector Online. Ashen Reach is a star system, not the title. This pass opens on Helion Dock.

Godot 4.7, windowed. One pass is enough if each line is done in the window.

1. **New keel.** Needle, Barn, and Beak are different shapes.
2. **Take the Needle.** The sky is Helion Dock. Aegis Prime fills the view; the hull is a speck on the band, not a marble beside the planet. An ice ring, Seized Hold, a Helion Compact patrol, Hauler Holt, and The Unlet are on that band. Flying out of the band returns to the chart. Burning at the city does not land the keel.
3. **Coast.** Thrust, then let go. The hull keeps drifting.
4. **Zoom.** Out until the star and Aegis read together. In until the silhouette is readable.
5. **Gun.** Space fires a shot.
6. **Log.** F5. Leave the dock. F9 or Continue. Same hull, same place, still Helion Dock. The menu title is Dark Sector Online; Helion Dock is the system under it.

```bash
godot --headless --path . --script res://tests/slice1_sim.gd
```

Headless host, same sim as Host the dock. It listens on 24565 and keeps `user://dark_sector_host.json`. A second window joins `127.0.0.1:24565`.

```bash
godot --headless --path . --script res://scripts/headless_host.gd
```
