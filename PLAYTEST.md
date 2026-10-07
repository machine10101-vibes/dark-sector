# Playtest — Ashen Reach helm

Godot 4.7, windowed, GL Compatibility. One pass is enough if each line is actually done in the window, not only in the headless script.

1. **New keel.** Menu shows New keel, Continue log (disabled until a log exists), and Leave. Open the yard and confirm Needle, Barn, and Beak are different shapes, including the bolted preview. Zoom the card: Needle is narrow spine plates and a glass canopy, Barn is large rectangular plates with hatches, Beak is faceted armor with a red lamp. Seams and rivets read as separate pieces of steel.
2. **Take the Needle.** The sector is Ashen Reach: Ash Lamp, Cinder, Mire, Vellum, the Slat belt, Hollow Latch, a Vellum Compact patrol, and a Red Keel pack. The ship is not a cursor: yaw is independent of the velocity vector.
3. **Fly.** Thrust, retro, strafe, and coast. Zoom out until the planets read as a sector, then back in until the keel's steel plates, rivets, and nozzles are readable. A Red Keel skiff should look patched. A Compact cutter should look regulation-grey with a dome. Boats in the dark are small plated hulls, not flat wedges.
4. **Probe.** Press 1 near Cinder. The probe returns. Dossier (D) lists orbit, atmosphere, surface, crust, biosign, ruins, and legal status. Cinder reads unclaimed.
5. **Harvest.** Press 2 on Cinder. The drone returns cinder ore into the hold, and the deposit ticks down.
6. **Bolt.** Bay (B). Bolt on the survey mast. The top-down shape gets longer. Mass is up, spare power is down, yaw is worse. The bolt control is gone; there is no uninstall.
7. **Fight or leave.** Space on a Red Keel skiff, or burn away. A kill leaves a wreck stamped with that skiff’s agent id. Shooting inside the green lane around Vellum raises heat. Harvesting Vellum raises more.
8. **Log.** Hold (or Esc, if the window manager lets it through). Write the log. Leave the Reach. Continue log. The mast is still on the keel, the hold still has the ore, and the galaxy seed is still 48291.
9. **Other keels, once.** Barn’s yard module is the cargo blister (wider, keel warning). Beak’s is the gun sponson. Beak has no harvest drone; her third craft is the away shuttle, and a walk of Hollow Latch sets the survey flag without planting a claim.
10. **Claim.** On the Barn, harvest at least four cinder-ore from Cinder. Press K inside Hollow Latch. Print a Claim Core (two ore), plant it, raise the ash dome (one ore), sow ember kale, and wait until the homestead card says the kale is ready. Take it aboard.
11. **Hen.** Stock an ash hen (one ore). Feed her the kale before the hunger line runs out. Leave her unfed on a second try and the card should say she died. The keel is still yours.
12. **Stake.** Salvage a wreck, stake the turret, and pull a Red Keel skiff into the Latch. The turret shoots. With the turret down, a skiff sitting on the stake cracks the core: the dome goes dark, the card says frozen, and the ship is not deleted. Print and plant another core to wake the same dome.

13. **Plasma.** On the first screen, Hollow Latch is already cluttered with dark rocks. Iron reads as rust-red metal on the stone, aluminum as pale silver, copper as orange with green patina, gold as yellow flecks. A large asteroid is in that same neighborhood, and torn plate is mixed in. You do not have to fly to a named belt to see ore. Left-click a rock: a gold ring and the log name it. Right-click it inside beam range. A barrel extends from the keel and a plasma column locks on. The hold gains that metal, the count drops, and a nodule disappears. Left-click Cinder, a ship, Ash Lamp, and the Latch cross. Right-click Cinder to send a probe and open the dossier. Right-click the Latch cross to open the homestead. Right-click your keel to open the bay. Right-click empty dark to stow the beam. Outside range, the log says the beam falls short. Zoom out until Rust Arc, Pale Shelf, Copper Vein, or King's Drift reads as a belt. Those arcs are denser, and the dark between them still has rocks.
14. **Plate and hulks.** Kill a Red Keel or visit Keel Grave. Right-click a torn plate until wreck plate is aboard. An abandoned hull (Abandoned courier, Cold hauler, and the others) yields plate and metal the same way.
15. **Fabricate.** Bay (B). With 2 copper, 2 iron, and 1 gold, fabricate the Coil Cannon. The nose gains the coil and the gun hits harder. Ion Booster wants 3 aluminum and 1 copper. Plated Armor wants 3 iron and 2 wreck plate, and the hull number goes up. A second copy of a part is refused. Write the log and read it back: the depleted rock and the bolted part are still there.
16. **Chandlery, refinery, boats.** Inside Hollow Latch, Bay, sell a stack of iron. The purse gains scrip and the hold loses the iron. Fly outside the pocket and the same button will not sell. Pour an alloy billet from 2 iron and 1 aluminum; the button counts up, and the billet appears when it finishes. With circuit lace and an alloy billet, start the Shard Lance and wait until it bolts. Hull resin and alloy make the Composite Belt. Lay a Prospector and launch her on a meteor; one unit comes home and the rock drops. Lay a Pathfinder; if the dossiers are sealed she marks the richest rock with a diamond. A full rack refuses another boat. A lost boat can be rebuilt onto the same rack.

Headless harvest check:

```bash
godot --headless --path . --script res://tests/slice_harvest.gd
```

Expect `HARVEST PASS`.

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
