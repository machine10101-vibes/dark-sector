extends RefCounted
## Procedural bodies for the sky: cratered asteroids, faceted ice, crystal
## clusters, rubble piles, and torn hull sections. Every mesh is smooth or
## faceted on purpose and carries its undisplaced direction in COLOR so the
## stone and ice shaders can paint craters and veins without stretching.


const SKY_SHADER := "shader_type sky;
float h31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float n3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * n3(p);
		p = p * 2.07 + vec3(3.1, 1.7, 8.3);
		a *= 0.5;
	}
	return v;
}
vec3 star_layer(vec3 d, float scale, float density, float size, float gain) {
	vec3 p = d * scale;
	vec3 c = floor(p);
	vec3 f = fract(p);
	float roll = h31(c);
	if (roll > density) {
		return vec3(0.0);
	}
	vec3 at = vec3(h31(c + 1.7), h31(c + 3.1), h31(c + 5.3)) * 0.8 + 0.1;
	float dist = length(f - at);
	float core = smoothstep(size, 0.0, dist);
	float halo = smoothstep(size * 4.5, 0.0, dist) * 0.18;
	float heat = h31(c + 9.4);
	vec3 tone = mix(vec3(0.62, 0.78, 1.0), vec3(1.0, 0.82, 0.58), heat);
	tone = mix(tone, vec3(1.0, 0.55, 0.38), smoothstep(0.88, 1.0, heat) * 0.7);
	float mag = 0.35 + 0.65 * h31(c + 2.2);
	float twinkle = 0.85 + 0.15 * sin(TIME * (0.8 + heat * 3.0) + roll * 40.0);
	return tone * (core + halo) * mag * gain * twinkle;
}
void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 pole = normalize(vec3(0.34, 0.82, -0.46));
	float lat = dot(d, pole);
	float band = exp(-lat * lat * 9.0);
	float dust = fbm3(d * 3.4 + vec3(2.0, 7.0, 1.0));
	float lanes = smoothstep(0.42, 0.72, fbm3(d * 7.0 + vec3(11.0, 3.0, 5.0)));
	float cloud = fbm3(d * 1.7 + vec3(5.0, 1.0, 9.0));
	vec3 base = vec3(0.012, 0.014, 0.024);
	vec3 haze = mix(vec3(0.05, 0.07, 0.13), vec3(0.16, 0.1, 0.07), smoothstep(0.35, 0.8, dust));
	vec3 col = base + haze * band * (0.5 + dust) * (1.0 - lanes * 0.7) * 0.8;
	vec3 neb_a = vec3(0.06, 0.1, 0.2);
	vec3 neb_b = vec3(0.16, 0.06, 0.1);
	float far = smoothstep(0.45, 0.85, cloud);
	col += mix(neb_a, neb_b, smoothstep(0.3, 0.9, fbm3(d * 2.3 + vec3(13.0)))) * far * 0.55;
	float lift = 1.0 + band * 1.6;
	col += star_layer(d, 34.0, 0.34, 0.09, 0.9 * lift);
	col += star_layer(d, 62.0, 0.3, 0.1, 0.8 * lift);
	col += star_layer(d, 118.0, 0.22, 0.13, 0.7 * lift);
	col += star_layer(d, 12.0, 0.1, 0.07, 2.4);
	float milk = band * smoothstep(0.35, 0.75, dust) * (1.0 - lanes * 0.8);
	col += vec3(0.9, 0.82, 0.7) * pow(h31(floor(d * 260.0)), 18.0) * milk * 0.9;
	COLOR = col;
}
"

const ICO_FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
	[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
	[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]


static func _icosphere(subdiv: int) -> Dictionary:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces: Array = ICO_FACES.duplicate(true)
	for _round in subdiv:
		var cache := {}
		var next: Array = []
		for face in faces:
			var mids: Array[int] = []
			for e in 3:
				var a: int = face[e]
				var b: int = face[(e + 1) % 3]
				var key := mini(a, b) * 100000 + maxi(a, b)
				if not cache.has(key):
					cache[key] = verts.size()
					verts.append(((verts[a] + verts[b]) * 0.5).normalized())
				mids.append(cache[key])
			next.append([face[0], mids[0], mids[2]])
			next.append([face[1], mids[1], mids[0]])
			next.append([face[2], mids[2], mids[1]])
			next.append([mids[0], mids[1], mids[2]])
		faces = next
	return {"v": verts, "f": faces}


static func _part() -> Dictionary:
	return {"v": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array(), "i": PackedInt32Array(), "flat": false}


static func _commit(parts: Array, flat: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for part in parts:
		var base := verts.size()
		var pv: PackedVector3Array = part.v
		var pc: PackedColorArray = part.c
		var puv: PackedVector2Array = part.uv
		var pi: PackedInt32Array = part.i
		if flat:
			for k in range(0, pi.size(), 3):
				var a := pv[pi[k]]
				var b := pv[pi[k + 1]]
				var c := pv[pi[k + 2]]
				var n := (b - a).cross(c - a)
				if n.length_squared() < 1e-10:
					continue
				n = n.normalized()
				for m in 3:
					verts.append(pv[pi[k + m]])
					cols.append(pc[pi[k + m]])
					uvs.append(puv[pi[k + m]] if puv.size() > pi[k + m] else Vector2.ZERO)
					norms.append(n)
					idx.append(verts.size() - 1)
		else:
			var local := PackedVector3Array()
			local.resize(pv.size())
			for k in range(0, pi.size(), 3):
				var n2 := (pv[pi[k + 1]] - pv[pi[k]]).cross(pv[pi[k + 2]] - pv[pi[k]])
				local[pi[k]] += n2
				local[pi[k + 1]] += n2
				local[pi[k + 2]] += n2
			for k in pv.size():
				verts.append(pv[k])
				cols.append(pc[k])
				uvs.append(puv[k] if puv.size() > k else Vector2.ZERO)
				norms.append(local[k].normalized() if local[k].length_squared() > 1e-12 else Vector3.UP)
			for k in pi.size():
				idx.append(base + pi[k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Godot front faces wind clockwise, so the counter-clockwise ico faces flip.
static func _push_tri(part: Dictionary, a: int, b: int, c: int) -> void:
	var idx: PackedInt32Array = part.i
	idx.append(a)
	idx.append(c)
	idx.append(b)
	part.i = idx


static func _noise(seed: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


static func _craters(rng: RandomNumberGenerator, count: int, wide: float) -> Array:
	var out: Array = []
	for _i in count:
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		out.append({"dir": dir, "r": rng.randf_range(0.2, wide), "d": rng.randf_range(0.07, 0.17)})
	return out


static func _crater_depth(u: Vector3, craters: Array) -> float:
	var depth := 0.0
	for c in craters:
		var ang := acos(clampf(u.dot(c.dir), -1.0, 1.0))
		var t := ang / float(c.r)
		if t < 1.0:
			depth -= float(c.d) * (1.0 - t * t) * (1.0 - t * t * 0.25)
		elif t < 1.7:
			var k := (t - 1.0) / 0.26
			depth += float(c.d) * 0.34 * exp(-k * k)
	return depth


static func _rock_part(seed: int, radius: float, subdiv: int, squash: float = 1.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) * 7919 + 13
	var lump := _noise(absi(seed) + 5, 1.1, 4)
	var grit := _noise(absi(seed) + 77, 4.5, 2)
	var shape := Vector3(rng.randf_range(0.82, 1.18), rng.randf_range(0.6, 0.95) * squash, rng.randf_range(0.8, 1.12))
	var craters := _craters(rng, 5 + rng.randi() % 5, 0.62)
	var ico := _icosphere(subdiv)
	var part := _part()
	var pv := PackedVector3Array()
	var pc := PackedColorArray()
	var spin := Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))
	for u in ico.v:
		var r := 1.0 + lump.get_noise_3dv(u * 1.5 + spin) * 0.24 + grit.get_noise_3dv(u + spin) * 0.045
		var crater := _crater_depth(u, craters)
		r += crater
		pv.append(Vector3(u.x * shape.x, u.y * shape.y, u.z * shape.z) * r * radius)
		pc.append(Color(u.x * 0.5 + 0.5, u.y * 0.5 + 0.5, u.z * 0.5 + 0.5, clampf(0.5 + crater * 3.0, 0.0, 1.0)))
	part.v = pv
	part.c = pc
	for f in ico.f:
		_push_tri(part, f[0], f[1], f[2])
	return part


static func rock(seed: int, radius: float) -> ArrayMesh:
	var subdiv := 4 if radius >= 16.0 else 3
	return _commit([_rock_part(seed, radius, subdiv)], false)


static func rubble(seed: int, radius: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) * 31 + 7
	var parts: Array = []
	var count := 9
	for i in count:
		var ring := float(i) / float(count)
		var ang := ring * TAU + rng.randf_range(-0.3, 0.3)
		var spread := radius * (0.2 + 0.62 * float((i * 5) % count) / float(count))
		var r := radius * rng.randf_range(0.26, 0.48)
		var part := _rock_part(seed * 13 + i, r, 2, 0.9)
		var at := Vector3(cos(ang) * spread, rng.randf_range(0.0, radius * 0.5) * (1.0 if i % 3 != 0 else 0.2), sin(ang) * spread)
		var basis := Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU)
		var pv: PackedVector3Array = part.v
		for k in pv.size():
			pv[k] = basis * pv[k] + at
		part.v = pv
		parts.append(part)
	return _commit(parts, false)


static func _prism(part: Dictionary, base: Vector3, axis: Vector3, width: float, length: float, tip: float, sides: int, shade: float) -> void:
	var up := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var side := axis.cross(up).normalized()
	var top := side.cross(axis).normalized()
	var pv: PackedVector3Array = part.v
	var pc: PackedColorArray = part.c
	var first := pv.size()
	for ring in 2:
		for s in sides:
			var a := TAU * float(s) / float(sides)
			var w := width * (1.0 if ring == 0 else 0.92)
			pv.append(base + axis * (length * float(ring)) + (side * cos(a) + top * sin(a)) * w)
			pc.append(Color(0.5, 0.5, 0.5, shade))
	pv.append(base + axis * (length + tip))
	pc.append(Color(0.5, 0.5, 0.5, 1.0))
	var apex := pv.size() - 1
	part.v = pv
	part.c = pc
	for s in sides:
		var n := (s + 1) % sides
		var a0 := first + s
		var a1 := first + n
		var b0 := first + sides + s
		var b1 := first + sides + n
		_push_tri(part, a0, a1, b1)
		_push_tri(part, a0, b1, b0)
		_push_tri(part, b0, b1, apex)
	# Back faces keep the prism solid from underneath.
	var cap: PackedInt32Array = part.i
	for s in range(1, sides - 1):
		cap.append(first)
		cap.append(first + s)
		cap.append(first + s + 1)
	part.i = cap


static func ice(seed: int, radius: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) * 101 + 3
	var lump := _noise(absi(seed) + 9, 1.3, 3)
	var ico := _icosphere(2)
	var core := _part()
	var pv := PackedVector3Array()
	var pc := PackedColorArray()
	var squash := Vector3(rng.randf_range(0.85, 1.1), rng.randf_range(0.7, 0.95), rng.randf_range(0.85, 1.1))
	for u in ico.v:
		var r := 0.72 + lump.get_noise_3dv(u * 1.7 + Vector3(seed, 0, 0)) * 0.22
		pv.append(Vector3(u.x * squash.x, u.y * squash.y, u.z * squash.z) * r * radius)
		pc.append(Color(0.5, 0.5, 0.5, 0.0))
	core.v = pv
	core.c = pc
	for f in ico.f:
		_push_tri(core, f[0], f[1], f[2])
	var parts: Array = [core]
	var spikes := _part()
	for _i in 9:
		var dir := Vector3(rng.randfn(), rng.randfn() * 0.7, rng.randfn()).normalized()
		var length := rng.randf_range(0.5, 0.95) * radius
		var w := rng.randf_range(0.11, 0.2) * radius
		_prism(spikes, dir * radius * 0.34, dir, w, length, w * rng.randf_range(0.9, 2.0), 6, 0.35)
	parts.append(spikes)
	return _commit(parts, true)


static func crystal(seed: int, radius: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) * 57 + 11
	var base := _rock_part(seed + 3, radius * 0.62, 2, 0.6)
	var pv: PackedVector3Array = base.v
	for k in pv.size():
		pv[k] += Vector3(0.0, -radius * 0.14, 0.0)
	base.v = pv
	var spikes := _part()
	for i in 11:
		var tilt := rng.randf_range(0.0, 0.85)
		var yaw := rng.randf() * TAU
		var dir := Vector3(sin(tilt) * cos(yaw), cos(tilt), sin(tilt) * sin(yaw)).normalized()
		var length := radius * rng.randf_range(0.5, 1.0) * (1.0 - tilt * 0.35)
		var w := radius * rng.randf_range(0.08, 0.16)
		_prism(spikes, Vector3(dir.x, 0.0, dir.z) * radius * 0.22 + Vector3(0.0, -radius * 0.06, 0.0), dir, w, length, w * rng.randf_range(1.2, 2.4), 6, 0.45)
	return _commit([base, spikes], true)


static func wreck(seed: int, radius: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) * 211 + 17
	var rag := _noise(absi(seed) + 31, 2.2, 3)
	var parts: Array = []
	var shell := _part()
	var pv := PackedVector3Array()
	var pc := PackedColorArray()
	var puv := PackedVector2Array()
	var stations := 10
	var sides := 12
	var half := radius * 1.35
	for i in stations:
		var t := float(i) / float(stations - 1)
		var x := lerpf(-half, half, t)
		var taper := 1.0 - pow(absf(t * 2.0 - 1.0), 2.6) * 0.55
		var w := radius * 0.5 * taper
		var h := radius * 0.4 * taper
		for s in sides:
			var a := TAU * float(s) / float(sides)
			var ca := cos(a)
			var sa := sin(a)
			var e := 3.2
			var ex := signf(ca) * pow(absf(ca), 2.0 / e)
			var ey := signf(sa) * pow(absf(sa), 2.0 / e)
			var p := Vector3(x, ey * h, ex * w)
			var edge := 1.0 - minf(t, 1.0 - t) * 6.0
			if edge > 0.0:
				var tear := rag.get_noise_3dv(Vector3(p.x, p.y, p.z) * 0.35 + Vector3(seed, 0, 0))
				p.x += signf(0.5 - t) * -1.0 * absf(tear) * radius * 0.5 * edge
				p.y *= 1.0 - maxf(tear, 0.0) * 0.4 * edge
				p.z *= 1.0 - maxf(-tear, 0.0) * 0.35 * edge
			pv.append(p)
			pc.append(Color(0.5, 0.5, 0.5, 1.0))
			puv.append(Vector2(x / radius * 1.2, float(s) / float(sides) * 2.0))
	shell.v = pv
	shell.c = pc
	shell.uv = puv
	for i in stations - 1:
		for s in sides:
			var n := (s + 1) % sides
			var a0 := i * sides + s
			var a1 := i * sides + n
			var b0 := (i + 1) * sides + s
			var b1 := (i + 1) * sides + n
			var tear_hole := rag.get_noise_3dv(Vector3(float(i), float(s), 0.0) * 0.9 + Vector3(seed, 3.0, 1.0)) > 0.46 and (i < 2 or i > stations - 4)
			if tear_hole:
				continue
			_push_tri(shell, a0, b1, a1)
			_push_tri(shell, a0, b0, b1)
	var inner_idx: PackedInt32Array = shell.i
	var outer_count := inner_idx.size()
	for k in range(0, outer_count, 3):
		inner_idx.append(inner_idx[k])
		inner_idx.append(inner_idx[k + 2])
		inner_idx.append(inner_idx[k + 1])
	shell.i = inner_idx
	parts.append(shell)
	var frames := _part()
	var fv := PackedVector3Array()
	var fc := PackedColorArray()
	var fu := PackedVector2Array()
	for i in range(1, stations - 1, 2):
		var t := float(i) / float(stations - 1)
		var x := lerpf(-half, half, t)
		var taper := 1.0 - pow(absf(t * 2.0 - 1.0), 2.6) * 0.55
		var w := radius * 0.5 * taper
		var h := radius * 0.4 * taper
		var ring_base := fv.size()
		for s in sides:
			var a := TAU * float(s) / float(sides)
			var ca := cos(a)
			var sa := sin(a)
			var ex := signf(ca) * pow(absf(ca), 0.625)
			var ey := signf(sa) * pow(absf(sa), 0.625)
			for layer in 2:
				var inset := 0.9 - 0.08 * float(layer)
				fv.append(Vector3(x + (0.18 if layer == 1 else -0.18) * radius * 0.1, ey * h * inset, ex * w * inset))
				fc.append(Color(0.5, 0.5, 0.5, 0.0))
				fu.append(Vector2(float(s), float(layer)))
		frames.v = fv
		frames.c = fc
		frames.uv = fu
		for s in sides:
			var n := (s + 1) % sides
			var a0 := ring_base + s * 2
			var a1 := ring_base + n * 2
			_push_tri(frames, a0, a1 + 1, a1)
			_push_tri(frames, a0, a0 + 1, a1 + 1)
			_push_tri(frames, a0, a1, a1 + 1)
			_push_tri(frames, a0, a1 + 1, a0 + 1)
	frames.v = fv
	frames.c = fc
	frames.uv = fu
	parts.append(frames)
	var bits := _part()
	var bv := PackedVector3Array()
	var bc := PackedColorArray()
	var bu := PackedVector2Array()
	for k in 4:
		var at := Vector3(rng.randf_range(-half, half) * 0.8, rng.randf_range(0.3, 0.9) * radius * (1.0 if k % 2 == 0 else -1.0), rng.randf_range(-0.9, 0.9) * radius)
		var span := rng.randf_range(0.28, 0.5) * radius
		var thick := radius * 0.04
		var basis := Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU)
		var corners: Array[Vector3] = [
			Vector3(-span, 0.0, -span * 0.7), Vector3(span, 0.0, -span * 0.6),
			Vector3(span * 0.8, 0.0, span * 0.7), Vector3(-span * 0.9, 0.0, span * 0.5),
		]
		var base_i := bv.size()
		for layer in 2:
			for c in corners:
				bv.append(at + basis * (c + Vector3(0.0, thick * float(layer), 0.0)))
				bc.append(Color(0.5, 0.5, 0.5, 1.0))
				bu.append(Vector2(c.x / radius * 2.0, c.z / radius * 2.0))
		bits.v = bv
		bits.c = bc
		bits.uv = bu
		_push_tri(bits, base_i + 4, base_i + 5, base_i + 6)
		_push_tri(bits, base_i + 4, base_i + 6, base_i + 7)
		_push_tri(bits, base_i, base_i + 2, base_i + 1)
		_push_tri(bits, base_i, base_i + 3, base_i + 2)
		for e in 4:
			var n2 := (e + 1) % 4
			_push_tri(bits, base_i + e, base_i + n2, base_i + 4 + n2)
			_push_tri(bits, base_i + e, base_i + 4 + n2, base_i + 4 + e)
	bits.v = bv
	bits.c = bc
	bits.uv = bu
	parts.append(bits)
	return _commit(parts, true)
