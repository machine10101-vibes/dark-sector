ART LOOP STATE
==========
Hero: Vesper Needle (callsign Needle). Barn and Beak are not this pass.
Gate just completed: Material break
Cinematic lead: art/cinematic/needle_hero.png
Realtime catch-up: ships/silhouette.gd paints the same materials inside the existing Needle polygon. Hull points are unchanged, so the long thin planform and the mast extent stay put.
Top-down crops (rendered from that draw, not from the cinematic):
- art/crops/needle_bare.png
- art/crops/needle_mast.png
- art/crops/needle_thrust.png
Regenerate with tools/render_needle_crops.gd
Materials that match:
- Oxidized teal plate #1f6f73
- Pale bone trim #d7e6c8 on the nose cap and the tail collar
- Dark glass canopy just aft of the nose
- Recessed dark nozzle throat, amber only when the keel thrusts
- Survey mast still the bone spar; a dark bolt marks where it meets the hull
What got more real:
1. The plate is broken by a spine seam and three stations, so the hull is no longer one sticker fill.
2. Bone nose and tail collar are a second material, the same trim the cinematic uses.
3. The canopy and the nozzle throat are different from the plate, so the crew station and the engine read as parts.
What still looks CG:
1. The plate is a flat fill. The cinematic has grain and a lamp falloff; the game has neither.
2. The canopy is a flat diamond with no glass highlight, and the thrust plume is still a flat amber triangle.
3. Barn and Beak are still one-color polygons. This gate did not touch them.
What is next (one gate):
1. A single Ash Lamp key on the Needle plate: one lit edge and one shadow edge, same materials, same planform.
Do not:
- Fatten the gameplay hull to match the cinematic's thickness. The cinematic is a little fuller. The realtime ship stays the thin courier.
- Recolor the Needle, or restyle Barn and Beak in this gate.
