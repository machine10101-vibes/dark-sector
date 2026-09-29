# Playtest — Ashen Reach helm

Godot 4.7, windowed, GL Compatibility. One pass is enough if each line is actually done in the window, not only in the headless script.

1. **New keel.** Menu shows New keel, Continue log (disabled until a log exists), and Leave. Open the yard and confirm Needle, Barn, and Beak are different shapes, including the bolted preview.
2. **Take the Needle.** The sector is Ashen Reach: Ash Lamp, Cinder, Mire, Vellum, the Slat belt, Hollow Latch, a Vellum Compact patrol, and a Red Keel pack. The ship is not a cursor: yaw is independent of the velocity vector.
3. **Fly.** Thrust, retro, strafe, and coast. Zoom out until the planets read as a sector, then back in until the keel silhouette is readable.
4. **Probe.** Press 1 near Cinder. The probe returns. Dossier (D) lists orbit, atmosphere, surface, crust, biosign, ruins, and legal status. Cinder reads unclaimed.
5. **Harvest.** Press 2 on Cinder. The drone returns cinder ore into the hold, and the deposit ticks down.
6. **Bolt.** Bay (B). Bolt on the survey mast. The top-down shape gets longer. Mass is up, spare power is down, yaw is worse. The bolt control is gone; there is no uninstall.
7. **Fight or leave.** Space on a Red Keel skiff, or burn away. A kill leaves a wreck stamped with that skiff’s agent id. Shooting inside the green lane around Vellum raises heat. Harvesting Vellum raises more.
8. **Log.** Hold (or Esc, if the window manager lets it through). Write the log. Leave the Reach. Continue log. The mast is still on the keel, the hold still has the ore, and the galaxy seed is still 48291.
9. **Other keels, once.** Barn’s yard module is the cargo blister (wider, keel warning). Beak’s is the gun sponson. Beak has no harvest drone; her third craft is the away shuttle, and a walk of Hollow Latch sets the survey flag without planting a claim.
10. **Claim.** On the Barn, harvest at least four cinder-ore from Cinder. Press K inside Hollow Latch. Print a Claim Core (two ore), plant it, raise the ash dome (one ore), sow ember kale, and wait until the homestead card says the kale is ready. Take it aboard.
11. **Hen.** Stock an ash hen (one ore). Feed her the kale before the hunger line runs out. Leave her unfed on a second try and the card should say she died. The keel is still yours.
12. **Stake.** Salvage a wreck, stake the turret, and pull a Red Keel skiff into the Latch. The turret shoots. With the turret down, a skiff sitting on the stake cracks the core: the dome goes dark, the card says frozen, and the ship is not deleted. Print and plant another core to wake the same dome.

Headless claim check:

```bash
godot --headless --path . --script res://tests/slice5_claim.gd
```

Expect `SLICE5 PASS`.

Headless stand-in, if the window is unavailable:

```bash
godot --headless --path . --script res://tests/slice1_sim.gd
```

Expect `SLICE1 PASS`.
