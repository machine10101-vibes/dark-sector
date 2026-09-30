# Playtest — Helion Dock helm

Godot 4.7, windowed. One pass is enough if each line is done in the window.

1. **New keel.** Needle, Barn, and Beak are different shapes. The helm reads hull, speed, heat, and purse in one glass card. Cast off, Board, Quests, and Probe are the large controls.
2. **Take the Needle.** The sky is Helion Dock. Aegis Prime fills the view; the hull is a speck on the band, not a marble beside the planet. An ice ring, Seized Hold, a Helion Compact patrol, Hauler Holt, and The Unlet are on that band. Flying out of the band keeps speed and opens the chart with named lanes. Burning at the city does not land the keel.
3. **Coast.** Thrust, then let go. The hull keeps drifting. A/D yaws the nose and the keel follows. Q/E steps sideways. The camera stays on the keel once you are off the pad.
4. **Zoom.** Out until the star and Aegis read together. In until the silhouette is readable.
5. **Gun.** Space fires a shot.
6. **Log.** F5. Leave the dock. F9 or Continue log. Same hull, same place, still Helion Dock.
7. **Board.** On the pad, Board. Take Seal Aegis Prime. Probe. When the dossier seals, the log pays 80 and the helm reads Purse 80, even if the keel has already left the pad. Take the ring crate, fly to the ice ring, return to the pad. The log pays 120 and the crate leaves the hold.
8. **Chart.** Cast off and hold W past the band. Speed stays above 0. The chart shows Aegis Prime, Homestead Road, Green Spine, and Writ Lane. The log does not lock you on a scrape.

## Ready — title yard

Windowed or the Pages build. One fresh launch.

1. The title is the Helion limb, the ice rings, and a keel in front of that sky. New keel, Host, Join, and Continue log are still on the left.
2. New keel. One hull is in the yard above the cards. The line names it. Hover a card, or on a phone scroll so that card is the top one. Needle, Barn, and Beak each take the yard in turn.
3. Take the Needle. The helm is still moored at Helion Dock. Cast off and Board are up. Purse is 0.

## Ready — dock board

Windowed or the Pages build. One fresh Needle. Incognito is fine.

1. Spawn still reads moored at Helion Dock, hull beside Aegis, not inside the star.
2. W or Cast off leaves the pad. Speed leaves 0. Log has Cast off, then Undocked.
3. D yaws. I opens the dossier. D does not open it.
4. Fly out of the band. Speed stays above 0. The chart names Aegis Prime, Homestead Road, Green Spine, and Writ Lane. There is no scrape lock and no “city stays under the band” dead end. On the web build the origin/focus/render overlay is hidden.
5. Turn around. The cyan **Helion Dock** buoy is the big flashing ring on the chart, and the same name rides an arrow on the band. Fly into that buoy from any heading. Within about 50–100 m the pad moors the keel even if the helm still says Tactical. The line reads **Moored**. Cast off and Board are both on screen again. On the band the card also shows `Helion Dock` and the meters to the buoy, which is not the scale-bar length. A held W sits on the pad until you release it, then W or Cast off leaves.
6. Board. Take the Aegis scan. Probe. Bring the keel back if you left. When the dossier seals, Purse becomes 80.
7. Take the ice-ring crate. Touch the ring. Bring it back to the pad. Purse becomes 200 if the scan was already paid, or 120 if this is the only job. The crate is gone.

If keys are quiet, click the sky once. The Board, Take, Probe, and Cast off buttons do not need the keyboard.

```bash
godot --headless --path . --script res://tests/slice1_sim.gd
```

Headless host, same sim as Host the dock. It listens on 24565 and keeps `user://dark_sector_host.json`. A second window joins `127.0.0.1:24565`.

```bash
godot --headless --path . --script res://scripts/headless_host.gd
```
