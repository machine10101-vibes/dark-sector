# Playtest — Helion Dock helm

Godot 4.7, windowed. One pass is enough if each line is done in the window.

1. **New keel.** Needle, Barn, and Beak are different shapes.
2. **Take the Needle.** The sky is Helion Dock. Aegis Prime fills the view; the hull is a speck on the band, not a marble beside the planet. An ice ring, Seized Hold, a Helion Compact patrol, Hauler Holt, and The Unlet are on that band. Flying out of the band returns to the chart. Burning at the city does not land the keel.
3. **Coast.** Thrust, then let go. The hull keeps drifting.
4. **Zoom.** Out until the star and Aegis read together. In until the silhouette is readable.
5. **Gun.** Space fires a shot.
6. **Log.** F5. Leave the dock. F9 or Continue log. Same hull, same place, still Helion Dock.
7. **Band.** The craft line ends with `1 keel here` and a Helion count of at least 14 on the band. Lane to Black Quay and the count changes.
8. **Board.** Press Board. Press Job once to post Brass courier, again to take it. Put food mass in the hold, lane to Brass Lantern, and the log says the courier is on the slate.
9. **Break.** With heat under 40, dying keeps about half the hold and leaves a named wreck. At heat 40 the slate keeps most of it. Another keel cannot strip that wreck while the rights line is up. The layout is still bolted when you wake at the dock.
10. **Keels.** Needle shows a pale vane, Barn shows brown cargo cheeks, Beak shows short cheek barrels. Zoom in until the extra shape is readable.

```bash
godot --headless --path . --script res://tests/slice1_sim.gd
```

Headless host, same sim as Host the dock. It listens on 24565 and keeps `user://dark_sector_host.json`. A second window joins `127.0.0.1:24565`.

```bash
godot --headless --path . --script res://scripts/headless_host.gd
```
