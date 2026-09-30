# Playtest — Helion Dock helm

Godot 4.7, windowed. One pass is enough if each line is done in the window.

1. **New keel.** Needle, Barn, and Beak are different shapes. The helm reads hull, speed, heat, and purse in one glass card. Cast off, Board, Quests, and Probe are the large controls.
2. **Take the Needle.** The sky is Helion Dock. Aegis Prime fills the view; the hull is a speck on the band, not a marble beside the planet. An ice ring, Seized Hold, a Helion Compact patrol, Hauler Holt, and The Unlet are on that band. Flying out of the band keeps speed and opens the chart with named lanes. Burning at the city does not land the keel.
3. **Coast.** Thrust, then let go. The hull keeps drifting. A/D yaws the nose and the keel follows. Q/E steps sideways. The camera stays on the keel once you are off the pad.
4. **Zoom.** Out until the star and Aegis read together. In until the silhouette is readable.
5. **Gun.** Space fires a shot.
6. **Log.** F5. Leave the dock. F9 or Continue log. Same hull, same place, still Helion Dock.
7. **Board.** On the pad, Board. Take Seal Aegis Prime. Probe. It reads Aegis Prime. When that dossier seals while Moored, or the next time you are on the pad, the log pays 80 and the helm reads Purse 80. Take the ring crate, fly to the ice ring, return until Moored. The log pays 120 and the crate leaves the hold.
8. **Chart.** Cast off and hold W past the band. Speed stays above 0. The chart shows Aegis Prime, Homestead Road, Green Spine, and Writ Lane. The log does not lock you on a scrape.

## Ready — Beta #3 trade and tags

Pages build. One fresh Needle, still moored. This pass is the purse and the tag, not the sky.

1. Board, then Market. Purse reads 0. Buy glasswheat. The log says the purse is short, and Purse stays 0.
2. Take scan, seal Aegis Prime on the pad, Purse 80. Market. Buy glasswheat. Purse becomes 68 and the hold shows one glasswheat. Sell it. Purse becomes 76 and the hold shows none. Sell again. Purse stays 76.
3. Cast off past the pad. Market. Buy and sell both refuse, and the purse does not move. Come back, Moored. The same buy and sell work again.
4. Market. Type `Red-Keel!!` and Set tag. The helm callsign line shows Red-Keel. Scan dossier opens with `Corp tag  Red-Keel`. The overhead name on the keel reads the same tag. Clear the field and Set tag. The tag leaves the helm, the dossier, and the name.
5. F5, leave, F9. The tag and the glasswheat count are still there. Scan 80 and haul 120 still add to 200. New keel still flies solo when the page has no listen port.

## Ready — Beta #4 market glass

Same page. This pass is the glass and the phone, after the purse math already passed.

1. **Desk (1280×720).** Market is the first button on the quiet strip, not a new primary. The panel reads Helion market, Purse, the glasswheat count, Buy, Sell, and a corp-tag field. The type is on the glass. Cast off, Board, Quests, and Probe stay in the big bar.
2. **Portrait (~390×844).** Market opens inside the glass. Buy, Sell, and Set tag are tappable. The tag line on the helm does not cover Speed, Purse, or the primary bar.
3. **Landscape (~844×390).** Same panel, scrolled if it is taller than the glass. The helm tag is one short line. Speed, Purse, Cast off, Board, Quests, Probe, the stick, and the gun stay clear of each other.

Still holding, do not regress: haul ribbons and Purse 200, New keel solo, phone reflow, the three hull mounts, and the yard glass.

## Ready — Beta #4 hull mounts

Pages build. One fresh launch. This pass is the three keels looking like different jobs. The phone reflow already passed.

1. **Needle.** New keel, leave the Needle card up. The yard hull wears a long spine mast and a glass dish on the nose. The line reads **Needle is in the yard. Spine mast.**
2. **Barn.** Hover the Barn card, or on a phone make that card the top one. The mast is gone. A wide cargo bay sits across the flanks. The line reads **Wide bay.**
3. **Beak.** Same for the Beak. Wing guns sweep off the cheeks. The line reads **Wing guns.** The three hulls are not the same mesh with a sticker.

## Ready — Beta #3 upgrade functions

Same page. The mounts are hardware. The bolts still do the old jobs.

1. Take the Needle. Board. Fit the survey mast if it is in the yard list. The sensor reach grows. The 3D hull grows a spine, not a bay.
2. A cargo blister still adds hold. On the Barn it reads as the wide bay. On the Needle it reads as flank pods. The purse path is unchanged: scan 80 on the pad, haul 120 after the ring, Purse 200.
3. A cheek gun still adds damage. On the Beak the barrels sweep off the wings. Cast off, the haul ribbon, and New keel solo stay as they were.

## Ready — Beta #4 phone edges

Pages build. One fresh Needle. Two checks, then a glance that the rest still holds.

1. **Portrait title (~390×844).** Continue stays dark, **No log on the slate**, and that whole button sits on the glass. It is not cut off at the bottom of the slate.
2. **Landscape ship-select (~844×390).** The three Takes stay in one row. **Back** sits under that row, fully on screen, and takes a tap back to the slate.

Still holding, do not regress: portrait ship-select, landscape title, landscape helm (Speed/Purse clear of Cast off, Board, Quests, Probe; stick and gun under the bar), solo / Join / New keel, the desk at 1280×720, and the haul (Ice ring meters fall, then Helion Dock meters fall, Purse 200).

## Ready — ring haul

Pages build. One fresh Needle. Moor and Purse 80 already passed. This pass is the crate.

1. Board. Take haul. The helm and the log read **Ice ring N m — hold that way.** The amber beam runs from the keel to the ice ring, and the nose is on that beam. An arrow marks the ring end when it is off the glass. The log also says not to clear the band yet.
2. Cast off or hold W. Speed leaves 0 and climbs through the tens toward a couple of hundred, along the beam. The ice-ring number falls every second until the drop. Holding W out to the shell does not open the chart before the drop.
3. Touch the ring. The line becomes **Helion Dock N m — bring the crate back.** The amber beam swings to run from the keel to the Helion pad, and the nose is on that beam.
4. Hold W along that beam. The Helion Dock number falls every second until **Moored** (under 200 m), or press Dock inside 500 m. Purse is 200 if the scan already paid, or 120 if this is the only slip. The crate is gone.

## Ready — moor and purse

Pages build. One fresh Needle. Incognito is fine. The scale bar is zoom. The card’s `Helion Dock` meters are the range.

1. Cast off. Fly out until those meters climb, or the chart opens.
2. Come back. Do not hunt the buoy mesh. When the card shows **Helion Dock** under 200 m, the line becomes **Moored** from any heading and any speed, including a stop. Local and Tactical both snap. Inside 500 m, **Dock** forces that same snap. Cast off and Board return.
3. Board. Take scan. Probe. The probe reads Aegis Prime. When that dossier seals while Moored, or the next time the pad has the keel, Purse is 80. Sealing the ice ring does not pay this slip.
4. Take the haul. Touch the ice ring. Return until Moored. Purse is 200. The crate is gone.

## Ready — title yard

Windowed or the Pages build. One fresh launch.

1. The title is the Helion limb, the ice rings, and a keel in front of that sky. New keel, Host, Join, and Continue log are still on the left. Continue reads **No log on the slate** until a log exists. That line is not a lock.
2. New keel. One hull is in the yard above the cards. The line names it. Hover a card, or on a phone scroll so that card is the top one. Needle, Barn, and Beak each take the yard in turn. Take the Needle. The helm is moored. No listen port is required.
3. Host the dock, then Take the Needle. On the page the helm still opens. The log reads **No listen port on this board. Flying solo.** Leave the dock. Join a dock and take a keel. The slate returns, New keel still works, and the note reads **No listen port on this page. New keel still flies solo.**

## Ready — dock board

Windowed or the Pages build. One fresh Needle. Incognito is fine.

1. Spawn still reads moored at Helion Dock, hull beside Aegis, not inside the star.
2. W or Cast off leaves the pad. Speed leaves 0. Log has Cast off, then Undocked.
3. D yaws. I opens the dossier. D does not open it.
4. Fly out of the band. Speed stays above 0. The chart names Aegis Prime, Homestead Road, Green Spine, and Writ Lane. There is no scrape lock and no “city stays under the band” dead end. On the web build the origin/focus/render overlay is hidden.
5. Turn around. The cyan **Helion Dock** buoy is the flashing ring on the chart, and the card on the band shows the meters. Come back until that card reads under 200 m. The pad moors from any heading, any speed, and a stop, on Local or Tactical. Inside 500 m the **Dock** button forces it. The line reads **Moored**. Cast off and Board are both on screen again. A held W sits on the pad until you release it, then W or Cast off leaves.
6. Board. Take the Aegis scan. Probe. It reads Aegis Prime. While Moored, or the next time you touch the pad, Purse becomes 80.
7. Take the ice-ring crate. Touch the ring. Bring it back to the pad. Purse becomes 200 if the scan was already paid, or 120 if this is the only job. The crate is gone.

If keys are quiet, click the sky once. The Board, Take, Probe, and Cast off buttons do not need the keyboard.

```bash
godot --headless --path . --script res://tests/slice1_sim.gd
```

Headless host, same sim as Host the dock. It listens on 24565 and keeps `user://dark_sector_host.json`. A second window joins `127.0.0.1:24565`.

```bash
godot --headless --path . --script res://scripts/headless_host.gd
```
