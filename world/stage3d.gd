extends Node3D

## Sim-space meshes. X is chart X, Y is up, Z is negative chart Y.

const _NOISE := "float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash31(i + vec3(0.0, 1.0, 0.0)), hash31(i + vec3(1.0, 1.0, 0.0)), f.x), f.y), mix(mix(hash31(i + vec3(0.0, 0.0, 1.0)), hash31(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash31(i + vec3(0.0, 1.0, 1.0)), hash31(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p = p * 2.03 + vec3(1.7, 9.2, 2.4);
		a *= 0.5;
	}
	return v;
}
"

const PLANET_SHADER := "shader_type spatial;
render_mode unshaded;
varying vec3 wnorm;
varying vec3 wpos;
uniform vec4 albedo : source_color = vec4(0.6, 0.65, 0.62, 1.0);
uniform vec4 land : source_color = vec4(0.55, 0.58, 0.52, 1.0);
uniform vec3 to_star = vec3(1.0, 0.05, 0.0);
uniform float city = 0.0;
uniform float seed = 0.0;
uniform float spin = 0.0;
" + _NOISE + "void vertex() {
	vec3 nrm = normalize(NORMAL);
	float lift = fbm(nrm * 4.2 + vec3(seed, 0.4, seed * 0.3));
	float lift_x = fbm((nrm + vec3(0.025, 0.0, 0.0)) * 4.2 + vec3(seed, 0.4, seed * 0.3));
	float lift_y = fbm((nrm + vec3(0.0, 0.025, 0.0)) * 4.2 + vec3(seed, 0.4, seed * 0.3));
	float bump_amt = city > 0.5 ? 1.4 : 6.2;
	vec3 bumped = normalize(nrm + vec3(lift_x - lift, lift_y - lift, (lift_x + lift_y) * 0.5 - lift) * bump_amt);
	float crust = city > 0.5 ? 0.006 : 0.03;
	VERTEX += nrm * (lift - 0.48) * crust * length(VERTEX);
	wnorm = normalize((MODEL_MATRIX * vec4(bumped, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(wnorm);
	vec3 sun = normalize(to_star);
	float ndl = dot(n, sun);
	float day = smoothstep(-0.08, 0.28, ndl);
	float field = fbm(n * 3.1 + vec3(seed, 1.7, seed * 0.4));
	float detail = fbm(n * 8.5 + vec3(seed * 2.0, 0.4, 3.0));
	float ridges = fbm(n * 14.0 + vec3(seed * 1.3, 0.2, 2.2));
	float land_w = smoothstep(0.42, 0.58, field);
	vec3 deep = vec3(0.05, 0.16, 0.28);
	vec3 shoal = vec3(0.16, 0.42, 0.46);
	float depth = smoothstep(0.18, 0.48, field);
	vec3 sea = mix(deep, mix(albedo.rgb, shoal, 0.45), depth);
	vec3 coast = mix(albedo.rgb, vec3(0.72, 0.64, 0.42), 0.4);
	vec3 ground = mix(albedo.rgb, land.rgb, 0.62) * (0.72 + 0.38 * detail);
	ground *= mix(0.62, 1.08, smoothstep(0.35, 0.72, ridges));
	vec3 terrain = mix(sea, mix(coast, ground, smoothstep(0.48, 0.7, field)), land_w);
	float polar = smoothstep(0.55, 0.92, abs(n.y));
	float ice_cap = fbm(n * 6.0 + vec3(seed, 4.0, 0.2));
	terrain = mix(terrain, vec3(0.86, 0.91, 0.94) * (0.85 + 0.2 * ice_cap), polar * 0.88);
	float bowl = noise3(n * 6.5 + vec3(seed * 2.2, 3.1, 0.4));
	float crater = smoothstep(0.68, 0.84, bowl);
	float rim_c = smoothstep(0.58, 0.7, bowl) * (1.0 - crater);
	terrain = mix(terrain, terrain * vec3(0.45, 0.42, 0.4), crater * land_w * 0.85);
	terrain += vec3(0.18, 0.16, 0.13) * rim_c * land_w;
	float mottled = fbm(wpos * 0.0055 + vec3(seed, 2.2, 0.4));
	float fleck = fbm(wpos * 0.016 + n * 3.0);
	terrain *= 0.74 + 0.38 * mottled;
	terrain = mix(terrain, terrain * vec3(0.76, 0.92, 0.7), fleck * land_w * 0.45);
	if (city > 0.5) {
		float districts = fbm(n * 6.5 + vec3(seed, 1.4, 0.2));
		float roofs = fbm(n * 18.0 + vec3(seed * 1.5, 0.4, 2.0));
		float parks = smoothstep(0.6, 0.82, fbm(n * 2.6 + vec3(seed, 2.0, 0.6)));
		vec3 concrete = mix(albedo.rgb * 0.88, land.rgb * 0.92, roofs);
		concrete *= 0.82 + 0.22 * districts;
		vec3 urban = mix(concrete, mix(vec3(0.24, 0.42, 0.32), land.rgb, 0.45), parks * 0.5);
		urban = mix(urban, vec3(0.9, 0.93, 0.95), polar * 0.65);
		terrain = mix(terrain, urban, 0.58);
	}
	float dist = length(CAMERA_POSITION_WORLD - wpos);
	float near = 1.0 - smoothstep(320.0, 1700.0, dist);
	float fine = fbm(wpos * 0.06 + n * 6.0);
	float scrub = fbm(wpos * 0.14 + vec3(seed, 0.4, 1.7));
	terrain *= mix(1.0, 0.58 + 0.85 * fine, near);
	terrain = mix(terrain, terrain * vec3(0.55, 0.5, 0.4), scrub * near * land_w * 0.7);
	vec3 night = terrain * 0.05 + vec3(0.015, 0.03, 0.055);
	vec3 col = mix(night, terrain * (0.32 + 0.58 * day), day);
	float twilight = smoothstep(-0.22, -0.02, ndl) * (1.0 - smoothstep(0.0, 0.18, ndl));
	col += vec3(0.95, 0.38, 0.16) * twilight * 0.55;
	col += vec3(0.25, 0.45, 0.72) * twilight * 0.22;
	vec3 eye = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 halfv = normalize(sun + eye);
	float spec = pow(clamp(dot(n, halfv), 0.0, 1.0), 28.0);
	float broad = pow(clamp(dot(n, halfv), 0.0, 1.0), 6.0);
	float water = (1.0 - land_w) * day;
	col += vec3(0.72, 0.86, 0.95) * spec * water * 0.9;
	col += vec3(0.45, 0.62, 0.7) * broad * water * 0.28;
	float hi = fbm(n * 13.0 + vec3(seed * 2.4, 1.1, 0.6));
	float lo = fbm(n * 13.0 + vec3(seed * 2.4, 1.1, 0.6) + n * 0.07);
	float relief = clamp((hi - lo) * 5.5 + 0.55, 0.2, 1.15);
	float carve = city > 0.5 ? 0.16 : 0.5;
	col *= mix(1.0, relief, carve * day + 0.06);
	float lamps = 0.0;
	float night_side = smoothstep(0.18, -0.42, ndl);
	if (city > 0.5) {
		vec2 block = abs(fract(n.xz * 48.0 + vec2(seed, seed * 1.3)) - 0.5);
		float street = 1.0 - smoothstep(0.015, 0.07, min(block.x, block.y));
		float district = smoothstep(0.34, 0.7, fbm(n * 2.4 + vec3(seed, 1.2, 0.4)));
		float window = step(0.62, fract(sin(dot(floor(n.xz * 160.0), vec2(19.0, 47.0))) * 123.4));
		lamps = max(street, window * 0.65) * district * night_side * mix(0.7, 1.0, land_w);
	}
	float shore = 1.0 - smoothstep(0.0, 0.035, abs(field - 0.5));
	col += vec3(0.9, 0.93, 0.88) * shore * day * 0.55 * (1.0 - city);
	if (city > 0.5) {
		float pane = smoothstep(0.72, 0.9, fbm(n * 40.0 + vec3(seed, 0.2, 1.4)));
		col = mix(col, vec3(0.75, 0.86, 0.9), pane * day * 0.18);
	}
	float cloud_shade = smoothstep(0.46, 0.74, fbm(n * 3.6 + vec3(seed, spin, 0.6)));
	col *= 1.0 - cloud_shade * day * 0.42;
	vec3 glow = vec3(1.0, 0.86, 0.38) * lamps * 8.0;
	float rim = pow(clamp(1.0 - max(dot(n, eye), 0.0), 0.0, 1.0), 2.4);
	col += vec3(0.55, 0.72, 0.88) * rim * 0.22 + glow;
	ALBEDO = col;
	EMISSION = glow + vec3(0.45, 0.62, 0.78) * rim * 0.28 + vec3(0.9, 0.45, 0.18) * twilight * 0.15;
}
"

const CLOUD_SHADER := "shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back;
varying vec3 wnorm;
varying vec3 wpos;
uniform vec3 to_star = vec3(1.0, 0.0, 0.0);
uniform float seed = 0.0;
uniform float spin = 0.0;
" + _NOISE + "void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(wnorm);
	vec3 sun = normalize(to_star);
	float cloud = fbm(n * 3.6 + vec3(seed, spin, 0.6));
	float wisps = fbm(n * 9.0 + wpos * 0.004 + vec3(spin, 1.2, seed));
	float puff = fbm(wpos * 0.012 + vec3(seed, spin * 2.0, 0.4));
	float cover = smoothstep(0.46, 0.72, cloud) * (0.55 + 0.45 * wisps);
	cover *= 0.75 + 0.25 * puff;
	float dist = length(CAMERA_POSITION_WORLD - wpos);
	float near = 1.0 - smoothstep(320.0, 1700.0, dist);
	float mote = fbm(wpos * 0.045 + vec3(seed, spin, 2.0));
	cover *= mix(1.0, 0.25 + 0.95 * mote, near);
	float ndl = dot(n, sun);
	float day = smoothstep(-0.2, 0.45, ndl);
	vec3 shade = vec3(0.28, 0.34, 0.42);
	vec3 lit = vec3(0.98, 0.99, 1.0);
	float silver = pow(clamp(ndl, 0.0, 1.0), 3.0) * cover;
	float belly = smoothstep(0.2, -0.45, ndl);
	ALBEDO = mix(shade, lit, day) + vec3(1.0) * silver * 0.22;
	ALBEDO = mix(ALBEDO, shade * 0.62, belly * cover);
	ALPHA = cover * (0.4 + 0.68 * day);
}
"

const AIR_SHADER := "shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
varying vec3 wnorm;
varying vec3 wpos;
uniform vec3 to_star = vec3(1.0, 0.0, 0.0);
uniform vec4 tint : source_color = vec4(0.5, 0.72, 0.82, 1.0);
void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(wnorm);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 sun_dir = normalize(to_star);
	float fres = pow(clamp(1.0 - abs(dot(n, eye)), 0.0, 1.0), 2.05);
	float sun = pow(clamp(dot(n, sun_dir), 0.0, 1.0), 1.4);
	float grazing = pow(fres, 1.3);
	vec3 scatter = mix(vec3(0.35, 0.55, 0.85), vec3(1.0, 0.62, 0.32), sun);
	vec3 col = mix(tint.rgb, scatter, 0.72);
	ALBEDO = col;
	EMISSION = scatter * (0.15 + sun * 0.45) * grazing;
	ALPHA = fres * (0.28 + 0.78 * sun) * (0.7 + 0.3 * grazing);
}
"

const STAR_SHADER := "shader_type spatial;
render_mode unshaded;
varying vec3 wnorm;
varying vec3 wpos;
uniform vec4 albedo : source_color = vec4(1.0, 0.9, 0.7, 1.0);
" + _NOISE + "void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(wnorm);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - wpos);
	float facing = clamp(dot(n, eye), 0.0, 1.0);
	float limb = pow(facing, 0.55);
	float dark = mix(0.42, 1.0, limb);
	float grain = fbm(n * 14.0 + vec3(TIME * 0.04));
	float cells = fbm(n * 34.0 + vec3(TIME * 0.07, 1.2, 0.3));
	float spot = smoothstep(0.58, 0.82, fbm(n * 4.5 + vec3(TIME * 0.015)));
	float facula = smoothstep(0.72, 0.9, fbm(n * 9.0 + vec3(TIME * 0.02, 2.0, 0.4)));
	vec3 hot = mix(albedo.rgb * 0.55, vec3(1.0, 0.97, 0.88), 0.7);
	vec3 col = hot * dark * (0.62 + 0.5 * grain) * (0.7 + 0.45 * cells);
	col = mix(col, col * vec3(0.45, 0.3, 0.18), spot * 0.55);
	col = mix(col, vec3(1.0, 0.96, 0.86), facula * 0.35);
	ALBEDO = col;
	EMISSION = col * (0.85 + 0.25 * facing);
}
"

const CORONA_SHADER := "shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
varying vec3 wnorm;
varying vec3 wpos;
uniform vec4 albedo : source_color = vec4(1.0, 0.8, 0.5, 1.0);
void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(wnorm);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = pow(clamp(1.0 - abs(dot(n, eye)), 0.0, 1.0), 1.7);
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb * 0.4;
	ALPHA = fres * fres * 0.5;
}
"

const RAY_SHADER := "shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform vec4 albedo : source_color = vec4(1.0, 0.78, 0.42, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 0.995 || r < 0.42) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float a = ang / 6.2831853 + TIME * 0.012;
	float spoke = smoothstep(0.16, 0.025, abs(fract(a * 6.0) - 0.5));
	float thin = smoothstep(0.07, 0.01, abs(fract(a * 6.0 + 0.5) - 0.5));
	float mid = smoothstep(1.0, 0.58, r);
	float reach = smoothstep(1.0, 0.72, r);
	float ray = max(spoke * mid, thin * reach);
	if (ray < 0.12) {
		discard;
	}
	ALBEDO = albedo.rgb * (1.15 + spoke);
	EMISSION = ALBEDO;
	ALPHA = ray;
}
"

const HULL_SHADER := "shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 local_pos;
varying vec3 local_nrm;
varying vec3 wnorm;
varying vec3 wpos;
uniform vec4 albedo : source_color = vec4(0.5, 0.55, 0.58, 1.0);
uniform vec4 accent : source_color = vec4(0.0, 0.0, 0.0, 0.0);
float seam_of(vec3 p) {
	float sx = smoothstep(0.455, 0.5, abs(fract(p.x * 0.2) - 0.5));
	float sz = smoothstep(0.44, 0.5, abs(fract(p.z * 0.36) - 0.5));
	float fx = smoothstep(0.478, 0.5, abs(fract(p.x * 0.82) - 0.5));
	float fz = smoothstep(0.478, 0.5, abs(fract(p.z * 1.2) - 0.5));
	return max(max(sx, sz), max(fx, fz) * 0.55);
}
float plate_h(vec3 p) {
	float seam = seam_of(p);
	vec2 cell = floor(p.xz * vec2(0.2, 0.36));
	float id = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float h = (0.28 + 0.72 * id) * (1.0 - seam);
	float riv = seam * smoothstep(0.08, 0.0, abs(fract(p.x * 1.6) - 0.5)) * smoothstep(0.08, 0.0, abs(fract(p.z * 2.2) - 0.5));
	h += riv * 1.15;
	float scratch = smoothstep(0.9, 0.99, fract(sin(p.x * 6.4 + p.z * 19.0) * 91.3));
	h -= scratch * 0.18;
	return h;
}
void vertex() {
	local_pos = VERTEX;
	local_nrm = NORMAL;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(local_nrm);
	float h = plate_h(local_pos);
	float hx = plate_h(local_pos + vec3(0.22, 0.0, 0.0));
	float hz = plate_h(local_pos + vec3(0.0, 0.0, 0.22));
	vec3 tangent = abs(n.y) > 0.92 ? vec3(1.0, 0.0, 0.0) : normalize(cross(n, vec3(0.0, 1.0, 0.0)));
	vec3 bitangent = normalize(cross(n, tangent));
	vec3 bumped = normalize(n + tangent * (h - hx) * 9.0 + bitangent * (h - hz) * 9.0);
	vec3 world_n = normalize((MODEL_MATRIX * vec4(bumped, 0.0)).xyz);
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);
	float seam = clamp(seam_of(local_pos), 0.0, 1.0);
	vec2 cell = floor(local_pos.xz * vec2(0.2, 0.36));
	float id = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 col = albedo.rgb * (0.96 + 0.14 * id);
	col = mix(col, col * vec3(0.42, 0.46, 0.5), seam * 0.9);
	float edge_wear = smoothstep(0.28, 0.92, 1.0 - abs(n.y));
	col = mix(col, mix(col, vec3(0.78, 0.76, 0.7), 0.45), edge_wear * 0.55);
	float aft = smoothstep(-12.0, -28.0, local_pos.x);
	float temper = smoothstep(-4.0, -16.0, local_pos.x) * (1.0 - aft);
	col = mix(col, col * vec3(1.15, 0.78, 0.55), aft * 0.35);
	col = mix(col, col * vec3(0.62, 0.74, 0.95), temper * 0.22);
	float stripe = smoothstep(1.2, 0.08, abs(local_pos.z));
	col = mix(col, col * vec3(1.06, 1.1, 1.04), stripe * clamp(n.y, 0.0, 1.0) * 0.35);
	float livery = smoothstep(1.7, 0.2, abs(abs(local_pos.z) - 3.4));
	livery *= smoothstep(-0.05, 0.55, n.y);
	col = mix(col, accent.rgb, livery * accent.a * 0.9);
	float belly = smoothstep(7.5, 0.6, local_pos.y);
	col *= mix(1.0, 0.58, belly);
	float brush = 0.92 + 0.08 * sin(local_pos.x * 3.1 + local_pos.z * 13.0);
	float grain = fract(sin(dot(local_pos.xz, vec2(41.3, 17.1))) * 913.7);
	col *= brush * (0.93 + 0.09 * grain);
	float side = smoothstep(0.22, 0.7, 1.0 - abs(n.y));
	float row = smoothstep(0.7, 0.08, abs(local_pos.y - 4.6));
	float slot = smoothstep(0.22, 0.02, abs(fract(local_pos.x * 0.38) - 0.5));
	float port = side * row * slot;
	float lit_port = step(0.74, fract(sin(floor(local_pos.x * 0.38) * 17.13) * 91.7));
	col = mix(col, vec3(0.03, 0.045, 0.06), port * 0.85);
	ALBEDO = col;
	float bare = clamp(edge_wear * (1.0 - seam), 0.0, 1.0);
	METALLIC = mix(0.42, 0.86, bare * (1.0 - port));
	ROUGHNESS = mix(mix(0.36, 0.2, bare), 0.8, max(seam, port));
	AO = mix(1.0, 0.52, seam);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = pow(clamp(1.0 - abs(dot(normalize(wnorm), eye)), 0.0, 1.0), 3.2);
	EMISSION = col * fres * 0.04 + vec3(1.0, 0.42, 0.14) * aft * 0.07 + vec3(1.0, 0.78, 0.42) * port * lit_port * 0.85;
}
"

const GLASS_SHADER := "shader_type spatial;
render_mode blend_mix, depth_draw_never;
varying vec3 wnorm;
varying vec3 wpos;
uniform vec4 albedo : source_color = vec4(0.45, 0.78, 0.82, 0.45);
void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(wnorm);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = pow(clamp(1.0 - abs(dot(n, eye)), 0.0, 1.0), 1.85);
	float room = 0.55 + 0.45 * sin(wpos.x * 0.35 + wpos.z * 0.2);
	vec3 room_col = vec3(0.55, 0.72, 0.62) * room;
	ALBEDO = mix(room_col, vec3(0.82, 0.92, 0.96), fres);
	EMISSION = room_col * 0.22 + vec3(0.7, 0.9, 0.95) * fres * 0.35;
	ROUGHNESS = mix(0.02, 0.16, 1.0 - fres);
	METALLIC = 0.22;
	SPECULAR = 0.7;
	ALPHA = clamp(0.1 + fres * 0.78, 0.0, 0.88);
}
"

const PLUME_SHADER := "shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
uniform vec4 albedo : source_color = vec4(1.0, 0.7, 0.3, 0.8);
uniform float core = 0.0;
void fragment() {
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(1.0 - abs(UV.y * 2.0 - 1.0), 0.0, 1.0);
	float flicker = 0.82 + 0.18 * sin(TIME * 31.0 + along * 18.0);
	float diamonds = 0.72 + 0.28 * sin(along * 34.0 - TIME * 22.0);
	float fade = (1.0 - smoothstep(0.04, 1.0, along)) * (0.22 + 0.78 * across);
	float cool = smoothstep(0.05, 0.45, albedo.b - albedo.r);
	vec3 fire = mix(vec3(0.85, 0.28, 0.05), albedo.rgb, 0.62);
	vec3 sheath = mix(fire, albedo.rgb, cool);
	vec3 white = mix(vec3(1.0, 0.97, 0.9), vec3(0.86, 0.95, 1.0), cool);
	vec3 hot = mix(sheath, white, core * (1.0 - along) * flicker);
	hot *= mix(1.0, diamonds, across * (1.0 - along));
	ALBEDO = hot;
	float blow = mix(1.35, 0.72, cool);
	EMISSION = hot * flicker * (blow + core * 1.5);
	ALPHA = albedo.a * fade * flicker;
}
"

const RING_SHADER := "shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;
varying vec3 wpos;
uniform vec4 albedo : source_color = vec4(0.84, 0.9, 0.94, 0.9);
uniform vec3 planet_pos = vec3(0.0);
uniform vec3 to_star = vec3(1.0, 0.0, 0.0);
uniform float seed = 0.2;
uniform float glitter = 1.0;
void vertex() {
	float ang = atan(VERTEX.z, VERTEX.x);
	float rad = length(VERTEX.xz);
	float warp = sin(ang * 11.0 + seed * 4.0) * 0.55 + sin(ang * 23.0 + seed) * 0.28;
	float lift = sin(ang * 5.0 + seed * 2.0);
	vec3 radial = vec3(VERTEX.x, 0.0, VERTEX.z);
	if (rad > 0.001) {
		radial /= rad;
	}
	VERTEX += radial * rad * 0.018 * warp * glitter;
	VERTEX.y += rad * 0.007 * lift * glitter;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float u = clamp(UV.x, 0.0, 1.0);
	float bands = 0.78 + 0.22 * sin(u * 9.0 + seed * 4.0);
	float gap = smoothstep(0.07, 0.0, abs(u - 0.62));
	float lane = smoothstep(0.045, 0.0, abs(u - 0.3));
	vec3 col = albedo.rgb * bands;
	col *= 1.0 - max(gap, lane * 0.65) * 0.8;
	float grit = fract(sin(dot(UV, vec2(91.7, 47.3)) + seed) * 43758.5);
	float clump = 0.78 + 0.22 * sin(u * 53.0 + UV.y * 21.0 + seed);
	float streak = smoothstep(0.93, 0.995, fract(sin(UV.y * 210.0 + u * 16.0 + seed) * 43758.5));
	float arc = 0.55 + 0.45 * sin(UV.y * 37.6991 + seed * 5.0);
	arc = mix(1.0, arc, glitter);
	col *= (0.84 + 0.16 * grit) * clump * arc;
	col += vec3(0.92, 0.95, 0.98) * streak * 0.22 * glitter;
	float cell = floor(UV.y * 72.0 + TIME * 0.4);
	float spark = step(0.8, fract(sin(cell * 12.9 + floor(u * 18.0) * 3.1 + seed * 9.0) * 43758.5));
	float tw = pow(max(sin(TIME * 4.8 + cell), 0.0), 3.0);
	col += vec3(0.95, 0.98, 1.0) * spark * tw * 1.45 * glitter;
	float lane_glint = pow(max(sin(u * 42.0 - TIME * 1.7 + seed * 3.0), 0.0), 8.0);
	col += vec3(0.8, 0.93, 1.0) * lane_glint * 0.4 * glitter;
	vec3 radial = wpos - planet_pos;
	float lit = 0.7;
	if (dot(radial, radial) > 4.0) {
		lit = smoothstep(-0.25, 0.55, dot(normalize(radial), normalize(to_star)));
	}
	col *= 0.28 + 0.85 * lit;
	ALBEDO = col;
	ALPHA = albedo.a * (0.88 - gap * 0.7) * mix(1.0, 0.45 + 0.55 * arc, glitter);
}
"

const NEBULA_SHADER := "shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
varying vec3 wnorm;
varying vec3 wpos;
uniform vec4 tint : source_color = vec4(0.4, 0.5, 0.7, 0.08);
uniform float seed = 0.0;
" + _NOISE + "void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(wnorm);
	float cloud = fbm(n * 2.8 + vec3(seed, 1.4, seed * 0.5));
	float lane = smoothstep(0.4, 0.72, fbm(n * 1.3 + vec3(seed * 2.1, 0.4, 1.0)));
	float dens = smoothstep(0.3, 0.74, cloud) * mix(0.28, 1.0, lane);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = pow(clamp(1.0 - abs(dot(n, eye)), 0.0, 1.0), 1.4);
	vec3 warm = tint.rgb * vec3(1.25, 0.82, 0.55);
	ALBEDO = mix(tint.rgb, warm, lane * 0.65);
	ALPHA = tint.a * dens * (0.4 + 0.85 * fres);
}
"

const GATE_SHADER := "shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
uniform vec4 albedo : source_color = vec4(0.55, 0.85, 0.7, 1.0);
void fragment() {
	float r = clamp(UV.x, 0.0, 1.0);
	float rim = smoothstep(0.62, 0.96, r);
	float veil = (1.0 - r) * 0.22;
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb * (0.35 + rim * 0.8);
	ALPHA = rim * 0.62 + veil;
}
"

const ROCK_SHADER := "shader_type spatial;
varying vec3 wnorm;
uniform vec4 albedo : source_color = vec4(0.45, 0.42, 0.38, 1.0);
uniform float seed = 0.0;
" + _NOISE + "void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 n = normalize(wnorm);
	vec3 sun = normalize(vec3(0.35, 0.86, 0.22));
	float ndl = clamp(dot(n, sun), 0.0, 1.0);
	float grit = fbm(n * 6.0 + vec3(seed));
	float cavity = smoothstep(0.32, 0.72, fbm(n * 3.2 + vec3(seed * 2.0, 1.0, 0.2)));
	float pits = smoothstep(0.62, 0.82, noise3(n * 18.0 + vec3(seed)));
	vec3 mineral = mix(albedo.rgb, albedo.rgb * vec3(1.15, 0.92, 0.78), grit * 0.45);
	vec3 col = mineral * (0.7 + 0.75 * ndl);
	col = mix(col, col * 0.42, cavity * 0.7);
	col *= 1.0 - pits * 0.22;
	float vein = smoothstep(0.52, 0.74, fbm(n * 11.0 + vec3(seed, 2.2, 0.5)));
	col = mix(col, mineral * vec3(0.62, 0.48, 0.32), vein * 0.42);
	float fleck = smoothstep(0.78, 0.92, noise3(n * 28.0 + vec3(seed * 3.0)));
	col = mix(col, mineral * vec3(1.2, 1.05, 0.82), fleck * 0.55);
	float rim = pow(1.0 - ndl, 2.2);
	col += mineral * rim * 0.12;
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.72, 0.96, cavity), 0.38, fleck);
	METALLIC = mix(0.04, 0.35, fleck);
}
"

const ICE_SHADER := "shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 wnorm;
uniform float seed = 0.0;
void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 n = normalize(wnorm);
	vec3 sun = normalize(vec3(0.35, 0.86, 0.22));
	float ndl = clamp(dot(n, sun), 0.0, 1.0);
	float crack = smoothstep(0.47, 0.5, abs(fract(n.y * 6.5 + n.x * 4.0 + seed) - 0.5));
	float grit = fract(sin(dot(n.xy, vec2(41.3, 17.7)) + seed) * 913.1);
	vec3 deep = vec3(0.55, 0.68, 0.78);
	vec3 face = vec3(0.9, 0.95, 0.98);
	vec3 ice = mix(deep, face, 0.35 + 0.65 * ndl);
	ice = mix(ice, vec3(0.62, 0.78, 0.9), grit * 0.18);
	ice = mix(ice, deep * 0.72, crack * 0.7);
	ALBEDO = ice;
	ROUGHNESS = mix(0.16, 0.48, crack);
	METALLIC = 0.02;
	SPECULAR = 0.85;
	EMISSION = vec3(0.75, 0.9, 1.0) * pow(ndl, 12.0) * 0.35;
}
"

const RUBBLE_SHADER := "shader_type spatial;
render_mode unshaded;
varying vec3 onorm;
uniform vec4 albedo : source_color = vec4(0.62, 0.48, 0.34, 1.0);
uniform float seed = 0.0;
void vertex() {
	onorm = NORMAL;
}
void fragment() {
	vec3 n = normalize(onorm);
	float salt = fract(sin(dot(floor(n * 5.0 + vec3(seed)), vec3(17.0, 43.0, 9.0))) * 12345.6);
	vec3 stone = mix(albedo.rgb * 0.42, albedo.rgb * 1.45, salt);
	float sky = clamp(n.y * 0.55 + 0.62, 0.4, 1.0);
	float crease = smoothstep(0.15, 0.72, abs(n.x) + abs(n.z));
	stone = mix(stone * 0.55, stone, crease);
	float sun = clamp(n.y * 0.72 + n.x * 0.28 + 0.32, 0.22, 1.0);
	float pit = smoothstep(0.72, 0.9, fract(sin(dot(n.xy, vec2(19.0, 47.0)) + seed) * 311.0));
	stone = mix(stone, stone * 0.45, pit * 0.65);
	ALBEDO = stone * sky * sun;
}
"

const GRID_SHADER := "shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 wpos;
float grid_line(vec2 p, float spacing, float width) {
	vec2 cell = abs(fract(p / spacing) - 0.5);
	float d = min(cell.x, cell.y) * spacing;
	return 1.0 - smoothstep(width * 0.35, width, d);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	float minor = grid_line(p, 420.0, 2.4);
	float major = grid_line(p, 2100.0, 4.5);
	float line = max(minor * 0.45, major);
	if (line < 0.04) { discard; }
	float dist = length(p - CAMERA_POSITION_WORLD.xz);
	float fade = 1.0 - smoothstep(280.0, 3600.0, dist);
	ALBEDO = mix(vec3(0.28, 0.34, 0.4), vec3(0.5, 0.58, 0.5), major);
	ALPHA = line * fade * 0.26;
}
"

const GROUND_SHADER := "shader_type spatial;
varying vec3 wpos;
" + _NOISE + "void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float soil = fbm(wpos.xz * 0.035);
	float tuft = fbm(wpos.xz * 0.11);
	vec3 dirt = vec3(0.34, 0.27, 0.16);
	vec3 grass = vec3(0.34, 0.5, 0.26);
	vec3 col = mix(dirt, grass, smoothstep(0.32, 0.68, soil));
	col *= 0.72 + 0.4 * tuft;
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
"

const WAKE_SHADER := "shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 albedo : source_color = vec4(0.62, 0.78, 0.9, 0.42);
void fragment() {
	float along = clamp(UV.x, 0.0, 1.0);
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float fade = (1.0 - along) * across;
	float flow = fract(along * 4.0 - TIME * 1.6);
	float streak = smoothstep(0.0, 0.12, flow) * smoothstep(0.62, 0.22, flow);
	ALBEDO = albedo.rgb * (0.45 + 0.55 * fade) * (0.7 + 0.45 * streak);
	EMISSION = albedo.rgb * fade * (0.45 + 0.7 * streak);
	ALPHA = albedo.a * fade * (0.62 + 0.38 * streak);
}
"

var _bodies: Dictionary = {}
var _ships: Dictionary = {}
var _craft: Dictionary = {}
var _props: Dictionary = {}
var _mesh_cache: Dictionary = {}
var tags: Array = []
var _star_mesh: MeshInstance3D
var _star_glow: MeshInstance3D
var _star_far: MeshInstance3D
var _star_rays: MeshInstance3D
var _sky: MultiMeshInstance3D
var _band: MultiMeshInstance3D
var _grid: MeshInstance3D
var _sun: DirectionalLight3D
var _planet_shader: Shader
var _cloud_shader: Shader
var _air_shader: Shader
var _star_shader: Shader
var _corona_shader: Shader
var _ray_shader: Shader
var _hull_shader: Shader
var _glass_shader: Shader
var _plume_shader: Shader
var _ring_shader: Shader
var _nebula_shader: Shader
var _gate_shader: Shader
var _rock_shader: Shader
var _ice_shader: Shader
var _rubble_shader: Shader
var _wake_shader: Shader
var _ground_shader: Shader
var _fill: DirectionalLight3D
var _beacon_light: OmniLight3D
var _frame_delta := 0.016
var _used: Dictionary = {}
var menu_show := false
var menu_class := "vesper"
var menu_hero := false
var menu_bias := 0.0
var portrait_mode := false
var _yard_t := 0.0
var _yard_ready := false


func _ready() -> void:
	_hull_shader = _compile(HULL_SHADER)
	_glass_shader = _compile(GLASS_SHADER)
	_plume_shader = _compile(PLUME_SHADER)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color("fff0d4")
	_sun.light_energy = 2.8 if portrait_mode else 2.05
	_sun.shadow_enabled = false
	add_child(_sun)
	_fill = DirectionalLight3D.new()
	_fill.name = "Fill"
	_fill.light_color = Color(0.72, 0.8, 0.95)
	_fill.light_energy = 1.05 if portrait_mode else 0.75
	_fill.shadow_enabled = false
	_fill.basis = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0))
	add_child(_fill)
	if portrait_mode:
		# A card only needs the hull. The chart grid and the planet shaders stay out.
		_sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
		return
	_planet_shader = _compile(PLANET_SHADER)
	_cloud_shader = _compile(CLOUD_SHADER)
	_air_shader = _compile(AIR_SHADER)
	_star_shader = _compile(STAR_SHADER)
	_corona_shader = _compile(CORONA_SHADER)
	_ray_shader = _compile(RAY_SHADER)
	_ring_shader = _compile(RING_SHADER)
	_nebula_shader = _compile(NEBULA_SHADER)
	_gate_shader = _compile(GATE_SHADER)
	_rock_shader = _compile(ROCK_SHADER)
	_ice_shader = _compile(ICE_SHADER)
	_rubble_shader = _compile(RUBBLE_SHADER)
	_wake_shader = _compile(WAKE_SHADER)
	_ground_shader = _compile(GROUND_SHADER)
	_build_grid()


func _compile(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


func _process(delta: float) -> void:
	_frame_delta = maxf(delta, 0.001)
	if menu_show:
		if str(Game.mode) == "sector":
			dismiss_yard()
			return
		_step_yard(delta)
		return
	if Game.sim == null or Game.mode != "sector":
		return
	_used.clear()
	tags.clear()
	_sync_star(Game.sim)
	_sync_planets(Game.sim)
	_sync_ships(Game.sim)
	_sync_craft(Game.sim)
	_sync_sky(Game.sim)
	_sync_grid(Game.sim)
	_sync_band()
	_sync_props(Game.sim)
	_aim_sun(Game.sim)
	_hide_stale(_bodies)
	_hide_stale(_ships)
	_hide_stale(_craft)
	_hide_stale(_props)


func _limb_gap() -> float:
	# The overhead camera sits behind and above the keel. The old 420-unit
	# gap put that camera inside the 15000-unit limb. Keep the surface
	# farther than the camera can reach, plus the air shell.
	var zoom := maxf(Game.zoom, 0.12)
	var height := 920.0 / zoom
	var back := height * 0.62
	var reach := Vector2(back, height).length()
	var shell := ScaleFrame.LIMB_RADIUS * 0.02
	return reach + shell + 240.0


func chart(p: Vector2, height: float = 0.0) -> Vector3:
	var shown := p
	if Game.sim != null and int(Game.sim.layer) == ScaleFrame.CHART:
		shown = ScaleFrame.chart_view(Game.sim, p)
	var render: Vector2 = shown
	var gate: Variant = WorldCoord.gate()
	if gate != null:
		render = gate.render_of_world(shown)
	return Vector3(render.x, height, -render.y)


func _sync_props(sim) -> void:
	var on_chart := int(sim.layer) == ScaleFrame.CHART
	var belt: Dictionary = sim.defs.system.get("belt", {})
	var volume := ScaleFrame.belt_is_volume(belt)
	var index := 0
	var shown := 0
	for rock in sim.asteroids:
		if volume and shown >= 6:
			break
		shown += 1
		var row: Dictionary = rock
		var chunk := _prop("rock%d" % index)
		index += 1
		if str(chunk.get_meta("built", "")) != "yes":
			var verts: PackedVector2Array = row.verts
			var center := Vector2.ZERO
			for point in verts:
				center += point
			if verts.size() > 0:
				center /= float(verts.size())
			var span := float(row.get("size", 12.0))
			var radius := maxf(8.0, span * 0.72)
			chunk.mesh = _rock_mesh(index + 3, radius)
			var tumble := float(absi(hash(str(index))) % 628) * 0.01
			var laid := _flat_xform(center, tumble, radius * 0.45)
			laid.basis = laid.basis * Basis(Vector3(1.0, 0.0, 0.0), 0.55)
			chunk.transform = laid
			var stone := ShaderMaterial.new()
			stone.shader = _rock_shader
			stone.set_shader_parameter("albedo", Color(str(row.get("tint", "#6a6258"))))
			stone.set_shader_parameter("seed", float(absi(hash(str(index))) % 97) * 0.1)
			chunk.material_override = stone
			chunk.set_meta("built", "yes")
		chunk.visible = chunk.mesh != null and not on_chart
	if volume:
		_sync_belt_volume(sim, belt)
	index = 0
	for hull in sim.trash:
		var row: Dictionary = hull
		var scrap := _prop("trash%d" % index)
		index += 1
		var scale := float(row.get("scale", 1.0))
		var radius := maxf(18.0, 26.0 * scale)
		if str(scrap.get_meta("built", "")) != "yes":
			scrap.mesh = _rubble_mesh(index + 40, radius)
			var tones: Array = [Color("c49262"), Color("6e5340"), Color("a87448"), Color("d4b48a")]
			scrap.material_override = _rubble_mat(tones[index % tones.size()], float(index) * 0.37)
			scrap.set_meta("built", "yes")
		scrap.visible = not on_chart
		scrap.transform = _flat_xform(row.pos, float(row.rot), radius * 0.72)
	if sim.trash.size() > 0 and not on_chart:
		_tag(str(sim.defs.system.trash.get("name", "Hold")), chart(sim.trash_pos, 160.0), Color("e4c8a4"), 20)
	index = 0
	for gate in sim.gates:
		var row: Dictionary = gate
		var hoop := _prop("gate%d" % index)
		index += 1
		var radius := float(row.get("radius", 80.0))
		var tone := Color("7d9a86")
		if str(row.get("color", "")) == "amber":
			tone = Color("c4a15a")
		elif str(row.get("color", "")) == "red":
			tone = Color("a85a4a")
		if str(hoop.get_meta("built", "")) != "yes":
			var torus := TorusMesh.new()
			torus.inner_radius = maxf(radius - 8.0, 8.0)
			torus.outer_radius = radius + 6.0
			torus.rings = 40
			torus.ring_segments = 12
			hoop.mesh = torus
			var mat := _metal(tone.darkened(0.35))
			mat.emission_enabled = true
			mat.emission = tone
			mat.emission_energy_multiplier = 0.55
			mat.metallic = 0.8
			mat.roughness = 0.28
			hoop.material_override = mat
			hoop.set_meta("built", "yes")
		var ang := float(row.get("angle", 0.0))
		var through := Vector3(cos(ang), 0.0, -sin(ang))
		var side := Vector3.UP.cross(through).normalized()
		var up := through.cross(side).normalized()
		var door := Basis(side, through, up)
		hoop.visible = not on_chart
		hoop.position = chart(row.pos, 0.0)
		hoop.basis = door
		var veil := _prop("gateveil%d" % (index - 1))
		if str(veil.get_meta("built", "")) != "yes":
			veil.mesh = _disc(radius * 0.9, 48)
			var film := ShaderMaterial.new()
			film.shader = _gate_shader
			film.set_shader_parameter("albedo", tone)
			veil.material_override = film
			veil.set_meta("built", "yes")
		veil.visible = not on_chart
		veil.position = hoop.position
		veil.basis = door
		if not on_chart:
			_tag(str(row.get("name", "")), chart(row.pos, radius * 0.15 + 20.0), Color("e6d7a8"), 13)
	var mast := _prop("beacon")
	if str(mast.get_meta("built", "")) != "yes":
		var pole := CylinderMesh.new()
		pole.top_radius = 2.2
		pole.bottom_radius = 3.4
		pole.height = 36.0
		mast.mesh = pole
		mast.material_override = _hull_mat(Color("8a7a62"))
		for i in 3:
			var stay := MeshInstance3D.new()
			stay.name = "Stay%d" % i
			var rod := CylinderMesh.new()
			rod.top_radius = 0.32
			rod.bottom_radius = 0.42
			rod.height = 32.0
			rod.radial_segments = 8
			stay.mesh = rod
			var ang := float(i) * TAU / 3.0
			stay.position = Vector3(cos(ang) * 2.4, 0.0, sin(ang) * 2.4)
			stay.material_override = _hull_mat(Color("6e6254"))
			mast.add_child(stay)
		var head := MeshInstance3D.new()
		head.name = "BeaconDish"
		head.mesh = _dish_mesh(4.8)
		head.position = Vector3(0.0, 16.2, 0.0)
		head.material_override = _hull_mat(Color("9aa896"))
		mast.add_child(head)
		mast.set_meta("built", "yes")
	mast.visible = not on_chart
	mast.position = chart(sim.beacon_pos, 18.0)
	var yard := _prop("beacon_yard")
	if str(yard.get_meta("built", "")) != "yes":
		yard.mesh = _bevel_box(Vector3(18.0, 1.4, 1.6), 0.28)
		yard.material_override = _hull_mat(Color("6e6254"))
		var hook := MeshInstance3D.new()
		hook.name = "YardHook"
		var drop := CylinderMesh.new()
		drop.top_radius = 0.28
		drop.bottom_radius = 0.28
		drop.height = 6.0
		drop.radial_segments = 8
		hook.mesh = drop
		hook.position = Vector3(7.2, -3.4, 0.0)
		hook.material_override = _metal(Color("4a433c"))
		yard.add_child(hook)
		yard.set_meta("built", "yes")
	yard.visible = not on_chart
	yard.position = chart(sim.beacon_pos, 32.0)
	var pad := _prop("beacon_pad")
	if str(pad.get_meta("built", "")) != "yes":
		pad.mesh = _bevel_box(Vector3(70.0, 1.8, 44.0), 0.45)
		pad.material_override = _hull_mat(Color("5c5348"))
		_pad_strip(pad, "PadSpine", Vector3(52.0, 0.12, 0.7), Vector3(0.0, 1.02, 0.0))
		_pad_strip(pad, "PadPort", Vector3(58.0, 0.12, 0.4), Vector3(0.0, 1.02, 16.5))
		_pad_strip(pad, "PadStbd", Vector3(58.0, 0.12, 0.4), Vector3(0.0, 1.02, -16.5))
		_pad_strip(pad, "PadBarF", Vector3(0.45, 0.12, 30.0), Vector3(18.0, 1.02, 0.0))
		_pad_strip(pad, "PadBarA", Vector3(0.45, 0.12, 30.0), Vector3(-18.0, 1.02, 0.0))
		_pad_bollard(pad, "BollardPF", Vector3(28.0, 2.4, 16.0))
		_pad_bollard(pad, "BollardSF", Vector3(28.0, 2.4, -16.0))
		_pad_bollard(pad, "BollardPA", Vector3(-28.0, 2.4, 16.0))
		_pad_bollard(pad, "BollardSA", Vector3(-28.0, 2.4, -16.0))
		for i in 5:
			var seam := MeshInstance3D.new()
			seam.name = "DeckSeam%d" % i
			seam.mesh = _bevel_box(Vector3(62.0, 0.28, 0.7), 0.06)
			seam.position = Vector3(0.0, 1.08, -14.0 + float(i) * 7.0)
			seam.material_override = _hull_mat(Color("2c2824"))
			pad.add_child(seam)
		for i in 4:
			var tile := MeshInstance3D.new()
			tile.name = "DeckPlate%d" % i
			var side := 1.0 if i < 2 else -1.0
			var along := -16.0 if i % 2 == 0 else 16.0
			tile.mesh = _bevel_box(Vector3(18.0, 0.22, 10.0), 0.18)
			tile.position = Vector3(along, 1.02, side * 8.5)
			tile.material_override = _hull_mat(Color("6a6156"))
			pad.add_child(tile)
		_pad_strip(pad, "ChevronP", Vector3(14.0, 0.32, 1.8), Vector3(10.0, 1.12, 4.2))
		_pad_strip(pad, "ChevronS", Vector3(14.0, 0.32, 1.8), Vector3(10.0, 1.12, -4.2))
		_pad_strip(pad, "ChevronPA", Vector3(12.0, 0.32, 1.6), Vector3(-12.0, 1.12, 4.6))
		_pad_strip(pad, "ChevronSA", Vector3(12.0, 0.32, 1.6), Vector3(-12.0, 1.12, -4.6))
		var chev_p := pad.get_node("ChevronP") as MeshInstance3D
		chev_p.rotation.y = 0.55
		var chev_s := pad.get_node("ChevronS") as MeshInstance3D
		chev_s.rotation.y = -0.55
		var chev_pa := pad.get_node("ChevronPA") as MeshInstance3D
		chev_pa.rotation.y = -0.5
		var chev_sa := pad.get_node("ChevronSA") as MeshInstance3D
		chev_sa.rotation.y = 0.5
		pad.set_meta("built", "yes")
	pad.visible = not on_chart
	pad.position = chart(sim.beacon_pos, 1.2)
	var halo := _prop("beacon_halo")
	if str(halo.get_meta("built", "")) != "yes":
		halo.mesh = _annulus(10.0, 18.0, 1.2, 36)
		var ring_mat := ShaderMaterial.new()
		ring_mat.shader = _ring_shader
		ring_mat.set_shader_parameter("albedo", Color(0.72, 0.86, 0.74, 0.55))
		ring_mat.set_shader_parameter("planet_pos", chart(sim.beacon_pos, 0.0))
		ring_mat.set_shader_parameter("to_star", Vector3(0.0, 1.0, 0.0))
		ring_mat.set_shader_parameter("glitter", 0.0)
		halo.material_override = ring_mat
		halo.set_meta("built", "yes")
	halo.visible = not on_chart
	halo.position = chart(sim.beacon_pos, 0.6)
	var lamp := _prop("beacon_lamp")
	if str(lamp.get_meta("built", "")) != "yes":
		var bulb := SphereMesh.new()
		bulb.radius = 5.5
		bulb.height = 11.0
		lamp.mesh = bulb
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("e7f2ea")
		glow.emission_enabled = true
		glow.emission = Color("d7e6c8")
		glow.emission_energy_multiplier = 1.6
		lamp.material_override = glow
		lamp.set_meta("built", "yes")
	lamp.visible = not on_chart
	lamp.position = chart(sim.beacon_pos, 40.0)
	if _beacon_light == null:
		_beacon_light = OmniLight3D.new()
		_beacon_light.name = "BeaconLight"
		_beacon_light.light_color = Color(0.78, 0.92, 0.74)
		_beacon_light.light_energy = 1.15
		_beacon_light.omni_range = 90.0
		_beacon_light.shadow_enabled = false
		add_child(_beacon_light)
	_beacon_light.visible = not on_chart
	_beacon_light.position = chart(sim.beacon_pos, 38.0)
	if not on_chart and str(sim.defs.system.id) == "HC-V1-R1-S1":
		var flash := 0.55 + 0.45 * sin(float(sim.time) * 5.0)
		var dock_ring := _prop("band_dock")
		if str(dock_ring.get_meta("built", "")) != "yes":
			# A berth ring around the keel. The old 150–220 torus put the
			# hull in the hole of a planet-sized disc.
			dock_ring.mesh = _annulus(30.0, 52.0, 1.3, 56)
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glow.albedo_color = Color(0.72, 0.94, 0.98, 0.72)
			glow.emission_enabled = true
			glow.emission = Color("7ee7f2")
			glow.emission_energy_multiplier = 0.85
			dock_ring.material_override = glow
			dock_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dock_ring.set_meta("built", "yes")
		dock_ring.position = chart(sim.beacon_pos, 1.4)
		dock_ring.visible = true
		var paint := dock_ring.material_override as StandardMaterial3D
		if paint != null:
			paint.emission_energy_multiplier = 0.8 + flash * 2.4
		var beam := _prop("band_dock_beam")
		if str(beam.get_meta("built", "")) != "yes":
			var column := CylinderMesh.new()
			column.top_radius = 3.5
			column.bottom_radius = 8.0
			column.height = 280.0
			beam.mesh = column
			var shaft := StandardMaterial3D.new()
			shaft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			shaft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			shaft.albedo_color = Color(0.55, 0.92, 0.96, 0.45)
			shaft.emission_enabled = true
			shaft.emission = Color("9eecf5")
			beam.material_override = shaft
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.set_meta("built", "yes")
		beam.position = chart(sim.beacon_pos, 146.0)
		beam.visible = true
		var beam_paint := beam.material_override as StandardMaterial3D
		if beam_paint != null:
			beam_paint.emission_energy_multiplier = 0.6 + flash * 1.8
		_tag("Helion Dock", chart(sim.beacon_pos + Vector2(36.0, 28.0), 46.0), Color("9eecf5"), 18)
		_sync_haul_ring(sim)
	elif not on_chart:
		_tag("Dock beacon", chart(sim.beacon_pos + Vector2(-70.0, -90.0), 78.0), Color("8aa896"), 13)
	_sync_density(sim)
	_sync_pocket(sim)
	_sync_nebula()
	_sync_shots(sim)
	_sync_beams(sim)
	_sync_impacts(sim)
	_sync_wrecks(sim)
	_sync_meteors(sim)
	_sync_claim(sim)


func _sync_haul_ring(sim) -> void:
	var aim: Vector2 = DockBoard.beam_aim(sim)
	if aim.length() < 8.0:
		return
	var inbound: bool = sim.haul_outbound() == false
	var flash := 0.35 + 0.65 * absf(sin(float(sim.time) * 7.5))
	var at: Vector2 = sim.player.pos + aim
	# The drop is inward, toward Aegis. A shaft that runs the whole gap
	# crosses the berth camera and reads as an outward lane. The visible
	# ribbon is a short keel→target step. The ring mark stays on the drop.
	var step := minf(aim.length(), 96.0)
	var tip: Vector2 = sim.player.pos + aim.normalized() * step
	_lay_haul_beam(sim.player.pos, tip, flash)
	var mark := _prop("haul_ring")
	if str(mark.get_meta("built", "")) != "yes":
		var torus := TorusMesh.new()
		torus.inner_radius = 70.0
		torus.outer_radius = 118.0
		torus.rings = 28
		torus.ring_segments = 8
		mark.mesh = torus
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("fff1c9")
		glow.emission_enabled = true
		glow.emission = Color("ffb04a")
		mark.material_override = glow
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.set_meta("built", "yes")
	mark.position = chart(at, 8.0)
	mark.visible = true
	var paint := mark.material_override as StandardMaterial3D
	if paint != null:
		paint.emission_energy_multiplier = 1.4 + flash * 3.2
	var pin := _prop("haul_ring_pin")
	if str(pin.get_meta("built", "")) != "yes":
		var column := CylinderMesh.new()
		column.top_radius = 1.6
		column.bottom_radius = 3.2
		column.height = 48.0
		pin.mesh = column
		var shaft := StandardMaterial3D.new()
		shaft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shaft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shaft.albedo_color = Color(1.0, 0.72, 0.28, 0.7)
		shaft.emission_enabled = true
		shaft.emission = Color("ffb04a")
		pin.material_override = shaft
		pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pin.set_meta("built", "yes")
	pin.position = chart(at, 28.0)
	pin.visible = true
	var pin_paint := pin.material_override as StandardMaterial3D
	if pin_paint != null:
		pin_paint.emission_energy_multiplier = 0.8 + flash * 2.4
	var label := "Helion Dock" if inbound else "Ice ring"
	_tag(label, chart(at + Vector2(18.0, -24.0), 64.0), Color("ffd27a"), 32)


func _lay_haul_beam(keel: Vector2, drop: Vector2, flash: float) -> void:
	var from := chart(keel, 8.0)
	var to := chart(drop, 8.0)
	var span := to - from
	var length := span.length()
	if length < 8.0:
		return
	var beam := _prop("haul_ring_beam")
	if str(beam.get_meta("built", "")) != "ribbon":
		var slab := BoxMesh.new()
		slab.size = Vector3(1.0, 1.0, 1.0)
		beam.mesh = slab
		var shaft := StandardMaterial3D.new()
		shaft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shaft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shaft.albedo_color = Color(1.0, 0.72, 0.28, 0.72)
		shaft.emission_enabled = true
		shaft.emission = Color("ffb04a")
		beam.material_override = shaft
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.set_meta("built", "ribbon")
	var dir := span / length
	var side := Vector3(-dir.z, 0.0, dir.x)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	beam.transform = Transform3D(Basis(dir * length, up * 3.0, side * 14.0), (from + to) * 0.5)
	beam.visible = true
	var beam_paint := beam.material_override as StandardMaterial3D
	if beam_paint != null:
		beam_paint.emission_energy_multiplier = 0.8 + flash * 2.4


func _sync_pocket(sim) -> void:
	var hoop := _prop("pocket")
	var radius := float(sim.defs.system.pocket.radius)
	if str(hoop.get_meta("built", "")) != str(radius):
		var torus := TorusMesh.new()
		torus.inner_radius = maxf(radius - 4.0, 8.0)
		torus.outer_radius = radius + 4.0
		torus.rings = 36
		torus.ring_segments = 8
		hoop.mesh = torus
		var mat := _metal(Color("9aaf8c"))
		mat.emission_enabled = true
		mat.emission = Color("9aaf8c")
		mat.emission_energy_multiplier = 0.2
		hoop.material_override = mat
		hoop.set_meta("built", str(radius))
	hoop.visible = int(sim.layer) != ScaleFrame.CHART
	hoop.position = chart(sim.pocket_pos, 2.0)
	if hoop.visible:
		_tag(str(sim.defs.system.pocket.name), chart(sim.pocket_pos, 18.0), Color("c5d2b4"), 14)


func _sync_nebula() -> void:
	var banks: Array[Vector3] = [
		Vector3(-4600.0, 360.0, 2400.0),
		Vector3(5600.0, 280.0, -2200.0),
		Vector3(-2200.0, 420.0, -5200.0),
		Vector3(3800.0, 240.0, 4800.0),
	]
	var radii: Array[float] = [520.0, 460.0, 400.0, 340.0]
	var tints: Array[Color] = [Color(0.35, 0.48, 0.62, 0.08), Color(0.55, 0.32, 0.18, 0.07), Color(0.22, 0.4, 0.38, 0.06), Color(0.5, 0.4, 0.22, 0.05)]
	for i in banks.size():
		var cloud := _prop("nebula%d" % i)
		if str(cloud.get_meta("built", "")) != "yes":
			var ball := SphereMesh.new()
			ball.radius = radii[i]
			ball.height = radii[i] * 2.0
			ball.radial_segments = 28
			ball.rings = 16
			cloud.mesh = ball
			var mat := ShaderMaterial.new()
			mat.shader = _nebula_shader
			mat.set_shader_parameter("tint", tints[i])
			mat.set_shader_parameter("seed", float(i) * 1.7)
			cloud.material_override = mat
			cloud.set_meta("built", "yes")
		cloud.position = banks[i]
		var inner := _prop("nebula_in%d" % i)
		if str(inner.get_meta("built", "")) != "yes":
			var core_ball := SphereMesh.new()
			core_ball.radius = radii[i] * 0.62
			core_ball.height = radii[i] * 1.24
			core_ball.radial_segments = 22
			core_ball.rings = 12
			inner.mesh = core_ball
			var core_mat := ShaderMaterial.new()
			core_mat.shader = _nebula_shader
			var tint: Color = tints[i]
			core_mat.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, tint.a * 0.65))
			core_mat.set_shader_parameter("seed", float(i) * 1.7 + 3.1)
			inner.material_override = core_mat
			inner.set_meta("built", "yes")
		inner.position = banks[i] + Vector3(0.0, radii[i] * 0.08, 0.0)


func _sync_shots(sim) -> void:
	var index := 0
	for shot in sim.projectiles:
		var row: Dictionary = shot
		var bolt := _prop("shot%d" % index)
		if str(bolt.get_meta("tracer", "")) != "yes":
			var rod := CylinderMesh.new()
			rod.top_radius = 0.42
			rod.bottom_radius = 1.05
			rod.height = 18.0
			rod.radial_segments = 8
			bolt.mesh = rod
			var head := MeshInstance3D.new()
			head.name = "Head"
			var tip := SphereMesh.new()
			tip.radius = 1.15
			tip.height = 2.3
			tip.radial_segments = 10
			tip.rings = 6
			head.mesh = tip
			head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bolt.add_child(head)
			var tail := MeshInstance3D.new()
			tail.name = "Tail"
			var fade := CylinderMesh.new()
			fade.top_radius = 0.85
			fade.bottom_radius = 0.15
			fade.height = 14.0
			fade.radial_segments = 8
			tail.mesh = fade
			tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bolt.add_child(tail)
			var core := MeshInstance3D.new()
			core.name = "Core"
			var wire := CylinderMesh.new()
			wire.top_radius = 0.16
			wire.bottom_radius = 0.28
			wire.height = 16.0
			wire.radial_segments = 6
			core.mesh = wire
			core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bolt.add_child(core)
			var glow := MeshInstance3D.new()
			glow.name = "Glow"
			var halo := SphereMesh.new()
			halo.radius = 1.8
			halo.height = 3.6
			halo.radial_segments = 10
			halo.rings = 6
			glow.mesh = halo
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bolt.add_child(glow)
			bolt.set_meta("tracer", "yes")
		var shot_vel: Vector2 = row.vel
		var aim := Vector2.RIGHT
		var speed := 0.0
		if shot_vel.length() > 1.0:
			aim = shot_vel.normalized()
			speed = shot_vel.length()
		var read := _fx_read(sim)
		var missile := str(row.get("family", "")) == "missile"
		var length := clampf(speed * 0.07, 18.0, 58.0) * read
		var thick := lerpf(1.15, read, 0.4)
		if missile:
			length = 14.0 * read
			thick = 2.4 * read
		thick *= 0.9 + 0.1 * sin(float(sim.time) * 36.0 + float(index) * 1.7)
		var along := Vector3(aim.x, 0.0, -aim.y)
		var side := Vector3(aim.y, 0.0, aim.x)
		var rod_mesh := bolt.mesh as CylinderMesh
		rod_mesh.height = length
		rod_mesh.top_radius = 0.42 * thick
		rod_mesh.bottom_radius = 1.05 * thick
		bolt.basis = Basis(side, along, Vector3.UP)
		bolt.position = chart(row.pos, 8.0) - along * length * 0.28
		var tint := _shot_tint(str(row.get("team", "")))
		if missile:
			tint = Color("d9d3c6")
		var flicker := 0.85 + 0.15 * sin(float(sim.time) * 48.0 + float(index))
		_paint_bolt(bolt, tint, 1.9 * flicker, 1.0)
		var head_node := bolt.get_node("Head") as MeshInstance3D
		head_node.position = Vector3(0.0, length * 0.5, 0.0)
		_paint_bolt(head_node, tint.lightened(0.42), 2.8 * flicker, 1.0)
		var tail_node := bolt.get_node("Tail") as MeshInstance3D
		var tail_mesh := tail_node.mesh as CylinderMesh
		tail_mesh.height = length * 0.85
		tail_node.position = Vector3(0.0, -length * 0.55, 0.0)
		_paint_bolt(tail_node, tint, 0.7 * flicker, 0.35)
		var core_node := bolt.get_node_or_null("Core") as MeshInstance3D
		if core_node != null:
			var core_mesh := core_node.mesh as CylinderMesh
			core_mesh.height = length * 0.92
			core_mesh.top_radius = 0.16 * thick
			core_mesh.bottom_radius = 0.28 * thick
			core_node.position = Vector3(0.0, length * 0.04, 0.0)
			_paint_bolt(core_node, tint.lightened(0.55), 3.4 * flicker, 0.95)
		var glow_node := bolt.get_node_or_null("Glow") as MeshInstance3D
		if glow_node != null:
			glow_node.position = Vector3(0.0, length * 0.42, 0.0)
			var bulb := 1.6 + thick * 0.85
			glow_node.scale = Vector3(bulb * 0.55, bulb * 1.4, bulb * 0.55)
			_paint_bolt(glow_node, tint.lightened(0.3), 1.6 * flicker, 0.28)
		if missile:
			for puff in 3:
				var crumb := _prop("smoke%d_%d" % [index, puff])
				if str(crumb.get_meta("built", "")) != "yes":
					var puff_mesh := SphereMesh.new()
					puff_mesh.radius = 1.0
					puff_mesh.height = 2.0
					puff_mesh.radial_segments = 8
					puff_mesh.rings = 4
					crumb.mesh = puff_mesh
					crumb.set_meta("built", "yes")
				var back := float(puff + 1) * 9.0 * read
				crumb.position = bolt.position - along * back
				crumb.scale = Vector3.ONE * (1.4 + float(puff) * 0.7) * read
				_paint_bolt(crumb, Color("9a9388"), 0.35, 0.28 - float(puff) * 0.06)
		index += 1


func _sync_beams(sim) -> void:
	var index := 0
	for row in sim.beams:
		var beam: Dictionary = row
		var a2: Vector2 = beam.from
		var b2: Vector2 = beam.to
		var span := b2 - a2
		var length := span.length()
		if length < 2.0:
			continue
		var rod := _prop("lase%d" % index)
		if str(rod.get_meta("built", "")) != "yes":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.55
			cyl.bottom_radius = 0.9
			cyl.height = 1.0
			cyl.radial_segments = 10
			rod.mesh = cyl
			var sheath := MeshInstance3D.new()
			sheath.name = "Sheath"
			var soft := CylinderMesh.new()
			soft.top_radius = 1.8
			soft.bottom_radius = 2.4
			soft.height = 1.0
			soft.radial_segments = 10
			sheath.mesh = soft
			rod.add_child(sheath)
			rod.set_meta("built", "yes")
		var along := Vector3(span.x, 0.0, -span.y).normalized()
		var mid := (a2 + b2) * 0.5
		rod.position = chart(mid, 6.0)
		_aim_rod(rod, along)
		(rod.mesh as CylinderMesh).height = length
		var sheath_node := rod.get_node("Sheath") as MeshInstance3D
		(sheath_node.mesh as CylinderMesh).height = length
		var hot := bool(beam.get("hot", false))
		var core := Color("fff1d2") if hot else Color("ffb15a")
		var edge := Color("ff6a1a")
		var age := float(beam.get("age", 0.0))
		var fade := clampf(1.0 - age / 0.32, 0.0, 1.0)
		_paint_bolt(rod, core, 3.2 * fade, 0.95)
		_paint_bolt(sheath_node, edge, 1.1 * fade, 0.28 * fade)
		index += 1


func _fx_read(sim) -> float:
	# Cruise camera sits much higher than the berth. Keep bursts and tracers
	# a similar size on screen without growing the hull.
	var zoom := maxf(float(Game.zoom), 0.12)
	var height := 920.0 / zoom
	var layer := int(sim.layer)
	if layer == ScaleFrame.BAND:
		var player: Dictionary = sim.player
		var ship := Vector2(player.pos)
		var pad := Vector2(float(player.get("dock_x", ship.x)), float(player.get("dock_y", ship.y)))
		var away: float = ship.distance_to(pad)
		var berth := 220.0 / zoom
		if bool(player.get("moored", false)):
			height = berth
		elif away < 200.0:
			height = lerpf(berth, 920.0 / zoom, clampf(away / 200.0, 0.0, 1.0))
	elif layer == ScaleFrame.CHART:
		height = 7800.0 / zoom
	elif layer == ScaleFrame.APPROACH:
		height = 14000.0 / zoom
	elif layer == ScaleFrame.SITE:
		height = 220.0 / zoom
	return clampf(height / 420.0, 1.0, 5.5)


func _sync_impacts(sim) -> void:
	var index := 0
	for row in sim.impacts:
		var impact: Dictionary = row
		var kind := str(impact.get("kind", "hit"))
		var age := float(impact.get("age", 0.0))
		var life := 0.34
		if kind == "kill":
			life = 0.62
		var t := clampf(age / life, 0.0, 1.0)
		var fade := (1.0 - t) * (1.0 - t)
		var tint := _shot_tint(str(impact.get("team", "")))
		if kind == "kill":
			tint = tint.lerp(Color("fff4e0"), 0.5)
		elif kind == "fade":
			tint = tint.darkened(0.25)
		var at: Vector2 = impact.pos
		var read := _fx_read(sim)
		var reach := lerpf(1.5, 7.0, t)
		if kind == "kill":
			reach = lerpf(1.5, 16.0, t)
		elif kind == "fade":
			reach = lerpf(0.6, 3.0, t)
		reach *= read
		var burst := _prop("burst%d" % index)
		if burst.mesh == null:
			var ball := SphereMesh.new()
			ball.radius = 1.0
			ball.height = 2.0
			ball.radial_segments = 12
			ball.rings = 8
			burst.mesh = ball
		burst.position = chart(at, 8.0)
		burst.scale = Vector3.ONE * reach
		_paint_bolt(burst, tint.lightened(0.2), 2.2 * fade + 0.15, clampf(fade, 0.05, 0.9))
		var incoming := Vector2(impact.get("dir", Vector2.ZERO))
		if kind != "fade":
			var disc := _prop("flash%d" % index)
			if disc.mesh == null or not (disc.mesh is CylinderMesh):
				var coin := CylinderMesh.new()
				coin.radial_segments = 16
				disc.mesh = coin
			var coin_mesh := disc.mesh as CylinderMesh
			var disc_r := lerpf(2.2, 11.0, t) * read
			if kind == "kill":
				disc_r = lerpf(3.0, 22.0, t) * read
			coin_mesh.height = 0.35 * read
			coin_mesh.top_radius = disc_r
			coin_mesh.bottom_radius = disc_r * 0.92
			disc.position = chart(at, 7.4)
			_paint_bolt(disc, tint.lightened(0.55), 3.2 * fade + 0.2, clampf(fade * 0.85, 0.04, 0.8))
			var wave := _prop("wave%d" % index)
			if wave.mesh == null or not (wave.mesh is TorusMesh):
				var torus := TorusMesh.new()
				torus.rings = 24
				torus.ring_segments = 8
				wave.mesh = torus
			var outer := lerpf(4.0, 14.0, t)
			if kind == "kill":
				outer = lerpf(6.0, 28.0, t)
			outer *= read
			var inner := maxf(0.5, outer - 2.2 * read)
			var torus_mesh := wave.mesh as TorusMesh
			torus_mesh.inner_radius = inner
			torus_mesh.outer_radius = outer
			wave.position = chart(at, 7.2)
			wave.scale = Vector3.ONE
			_paint_bolt(wave, tint, 1.4 * fade + 0.1, clampf(fade * 0.75, 0.04, 0.7))
			if kind == "kill" and t > 0.12:
				var echo := _prop("echo%d" % index)
				if echo.mesh == null or not (echo.mesh is TorusMesh):
					var ring2 := TorusMesh.new()
					ring2.rings = 20
					ring2.ring_segments = 6
					echo.mesh = ring2
				var late := clampf((t - 0.12) / 0.88, 0.0, 1.0)
				var echo_mesh := echo.mesh as TorusMesh
				var echo_r := lerpf(4.0, 20.0, late) * read
				echo_mesh.outer_radius = echo_r
				echo_mesh.inner_radius = maxf(0.4, echo_r - 1.6 * read)
				echo.position = chart(at, 7.6)
				_paint_bolt(echo, tint.lightened(0.35), 1.1 * (1.0 - late), clampf((1.0 - late) * 0.6, 0.03, 0.55))
			var sparks := 5
			if kind == "kill":
				sparks = 7
			var flown := lerpf(3.0, 12.0, t)
			if kind == "kill":
				flown = lerpf(4.0, 22.0, t)
			flown *= read
			var spark_len := lerpf(5.5, 1.1, t) * read
			for s in sparks:
				var spark := _prop("spark%d_%d" % [index, s])
				if spark.mesh == null or not (spark.mesh is CylinderMesh):
					var sliver := CylinderMesh.new()
					sliver.radial_segments = 6
					spark.mesh = sliver
				var sliver_mesh := spark.mesh as CylinderMesh
				sliver_mesh.top_radius = 0.12 * read
				sliver_mesh.bottom_radius = 0.42 * read
				sliver_mesh.height = spark_len
				var ang := TAU * float(s) / float(sparks) + float(index) * 0.71
				var lift := 0.22 + 0.1 * float(s % 2)
				var dir := Vector3(cos(ang), lift, -sin(ang)).normalized()
				if incoming.length_squared() > 0.2:
					var back := Vector3(-incoming.x, 0.15, incoming.y).normalized()
					dir = (dir * 0.45 + back * 0.85).normalized()
				spark.position = chart(at, 8.0) + dir * flown
				_aim_rod(spark, dir)
				_paint_bolt(spark, tint.lightened(0.25), 1.8 * fade + 0.1, clampf(fade, 0.05, 0.95))
			var column := _prop("column%d" % index)
			if column.mesh == null or not (column.mesh is CylinderMesh):
				var pillar := CylinderMesh.new()
				pillar.radial_segments = 8
				column.mesh = pillar
			var col_h := lerpf(18.0, 4.0, t) * read
			if kind == "kill":
				col_h = lerpf(32.0, 8.0, t) * read
			var pillar_mesh := column.mesh as CylinderMesh
			pillar_mesh.height = col_h
			pillar_mesh.top_radius = 0.28 * read
			pillar_mesh.bottom_radius = 1.15 * read
			column.position = chart(at, 6.0 + col_h * 0.2)
			_paint_bolt(column, tint.lightened(0.45), 2.8 * fade + 0.2, clampf(fade, 0.05, 0.85))
		index += 1


func _shot_tint(team: String) -> Color:
	if team == "captain":
		return Color("ffd59a")
	if team == "red_keel":
		return Color("ff8a72")
	if team == "helion_compact" or team == "vellum_compact":
		return Color("9eecf5")
	return Color("e7b15a")


func _paint_bolt(node: MeshInstance3D, color: Color, energy: float, alpha: float) -> void:
	var mat := node.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		node.material_override = mat
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission = color
	mat.emission_energy_multiplier = energy
	if alpha < 0.98:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED


func _aim_rod(node: MeshInstance3D, dir: Vector3) -> void:
	var axis := dir.normalized()
	if axis.length_squared() < 0.001:
		axis = Vector3.UP
	var ref := Vector3.UP
	if absf(axis.dot(ref)) > 0.9:
		ref = Vector3.RIGHT
	var side := ref.cross(axis).normalized()
	var up := axis.cross(side).normalized()
	node.basis = Basis(side, axis, up)


func _sync_wrecks(sim) -> void:
	var index := 0
	for wreck in sim.wrecks:
		var row: Dictionary = wreck
		var hulk := _prop("wreck%d" % index)
		var wid := str(row.get("id", ""))
		if str(hulk.get_meta("wid", "")) != wid:
			hulk.set_meta("wid", wid)
			hulk.set_meta("lit", float(sim.time))
		if str(hulk.get_meta("built", "")) != "yes":
			hulk.mesh = _rock_mesh(index + 11, 11.0)
			hulk.material_override = _hull_mat(Color("5a4038"))
			hulk.set_meta("built", "yes")
		var age_spin := float(sim.time) - float(hulk.get_meta("lit", sim.time))
		var tumble := lerpf(2.4, 0.85, clampf(age_spin / 2.2, 0.0, 1.0))
		var spin := float(sim.time) * tumble + float(index)
		var tilt := sin(float(sim.time) * 0.9 + float(index)) * 0.7
		var roll := sin(float(sim.time) * 0.62 + float(index) * 0.4) * 0.45
		var xf := _flat_xform(row.pos, spin, 5.0)
		xf.basis = xf.basis * Basis(Vector3.RIGHT, tilt) * Basis(Vector3.FORWARD, roll)
		hulk.transform = xf
		var shard := _prop("wreckbit%d" % index)
		if str(shard.get_meta("built", "")) != "yes":
			shard.mesh = _rock_mesh(index + 21, 4.6)
			shard.material_override = _rock_shader_mat(Color("3a2a26"), float(index))
			shard.set_meta("built", "yes")
		var pos: Vector2 = row.pos
		var orbit_ang := float(sim.time) * 0.9 + float(index) * 1.7
		var orbit := Vector2(cos(orbit_ang), sin(orbit_ang)) * 10.0
		var bit := _flat_xform(pos + orbit, orbit_ang * 1.3, 3.2 + sin(orbit_ang) * 1.4)
		bit.basis = bit.basis * Basis(Vector3.FORWARD, orbit_ang)
		shard.transform = bit
		var age := float(sim.time) - float(hulk.get_meta("lit", sim.time))
		if age < 1.4:
			var et := clampf(age / 1.4, 0.0, 1.0)
			var read := _fx_read(sim)
			for e in 4:
				var ember := _prop("ember%d_%d" % [index, e])
				if ember.mesh == null:
					var coal := SphereMesh.new()
					coal.radius = 1.15
					coal.height = 2.3
					coal.radial_segments = 8
					coal.rings = 6
					ember.mesh = coal
				var ang := float(e) * TAU / 4.0 + float(index)
				var out := Vector3(cos(ang), 0.55, -sin(ang))
				ember.position = chart(row.pos, 6.0) + out * lerpf(2.0, 16.0, et) * read + Vector3(0.0, et * 8.0 * read, 0.0)
				var shrink := lerpf(1.15, 0.35, et) * lerpf(1.0, read, 0.45)
				ember.scale = Vector3.ONE * shrink
				_paint_bolt(ember, Color("ffb070"), lerpf(2.4, 0.3, et), clampf(1.0 - et, 0.05, 0.95))
		var burn := hulk.get_node_or_null("Burn") as MeshInstance3D
		if burn == null:
			burn = MeshInstance3D.new()
			burn.name = "Burn"
			burn.mesh = _plume_mesh(14.0, 2.2)
			burn.position = Vector3(-6.0, 1.4, 0.4)
			var flame := ShaderMaterial.new()
			flame.shader = _plume_shader
			flame.set_shader_parameter("albedo", Color(1.0, 0.42, 0.12, 0.8))
			flame.set_shader_parameter("core", 0.4)
			burn.material_override = flame
			burn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hulk.add_child(burn)
		burn.visible = age_spin < 2.1
		if burn.visible:
			var flick := 0.7 + 0.3 * absf(sin(float(sim.time) * 28.0 + float(index)))
			var left := clampf(1.0 - age_spin / 2.1, 0.15, 1.0)
			burn.scale = Vector3(left * flick * 1.4, left * 0.8, left * 0.8)
		index += 1
		_tag(str(row.get("name", "wreck")), chart(row.pos, 16.0), Color("a08070"), 12)


func _sync_meteors(sim) -> void:
	var index := 0
	for rock in sim.meteors:
		var row: Dictionary = rock
		var node := _prop("meteor%d" % index)
		index += 1
		var radius := maxf(36.0, float(row.get("size", 4.0)) * 8.0)
		if str(node.get_meta("built", "")) != "yes":
			node.mesh = _rubble_mesh(index + 17, radius)
			node.material_override = _rubble_mat(Color("a85a32"), float(index) * 0.37)
			node.set_meta("built", "yes")
		node.position = chart(row.pos, radius * 0.7)
		node.rotation = Vector3(float(index) * 0.4, float(index) * 0.7, 0.2)


func _sync_claim(sim) -> void:
	var show := bool(sim.claim.get("owned", false)) and str(sim.claim.get("system_id", "")) == str(sim.defs.system.id)
	var dome := _prop("claim")
	if not show:
		dome.visible = false
		_used.erase("prop:claim")
		return
	var origin := Vector2(float(sim.claim.get("x", 0.0)), float(sim.claim.get("y", 0.0)))
	if dome.mesh == null:
		var ball := SphereMesh.new()
		ball.radius = 22.0
		ball.height = 28.0
		dome.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.84, 0.7, 0.72)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.12
		mat.emission_enabled = true
		mat.emission = Color("d7e6c8")
		mat.emission_energy_multiplier = 0.2
		dome.material_override = mat
	dome.position = chart(origin, 10.0)
	dome.visible = true


func _prop(key: String) -> MeshInstance3D:
	_used["prop:" + key] = true
	if _props.has(key):
		var existing: MeshInstance3D = _props[key]
		existing.visible = true
		return existing
	var node := MeshInstance3D.new()
	node.name = key
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_props[key] = node
	return node


func _trash_poly(kind: int, scale: float) -> PackedVector2Array:
	var src := PackedVector2Array([Vector2(18, 0), Vector2(-10, 4), Vector2(-14, 0), Vector2(-10, -4)])
	if kind == 1:
		src = PackedVector2Array([Vector2(12, 0), Vector2(8, 9), Vector2(-12, 8), Vector2(-14, -7), Vector2(6, -9)])
	elif kind >= 2:
		src = PackedVector2Array([Vector2(8, 6), Vector2(-16, 3), Vector2(-6, -2), Vector2(10, -7)])
	var out := PackedVector2Array()
	for point in src:
		out.append(point * scale)
	return out


func _aim_sun(sim) -> void:
	var at: Vector2 = sim.player.pos
	var dir := Vector3(at.x, 40.0, -at.y)
	if dir.length_squared() < 1.0:
		dir = Vector3(1.0, 0.2, 0.0)
	dir = dir.normalized()
	var z_axis := -dir
	var x_axis := Vector3.UP.cross(z_axis)
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3(1.0, 0.0, 0.0)
	x_axis = x_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	_sun.basis = Basis(x_axis, y_axis, z_axis)


func _build_grid() -> void:
	_grid = MeshInstance3D.new()
	_grid.name = "Grid"
	var plane := PlaneMesh.new()
	plane.size = Vector2(48000.0, 48000.0)
	_grid.mesh = plane
	_grid.position = Vector3(0.0, -18.0, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = _compile(GRID_SHADER)
	_grid.material_override = mat
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)


func _sync_grid(sim) -> void:
	if _grid == null:
		return
	var layer := int(sim.layer)
	if layer == ScaleFrame.SITE:
		_grid.visible = false
		return
	_grid.visible = true
	# The plane used to sit at render zero, which is the floating origin,
	# so it slid out from under the keel between rebases.
	_grid.position = chart(sim.player.pos, -18.0)
	var plane := _grid.mesh as PlaneMesh
	if layer == ScaleFrame.CHART:
		plane.size = Vector2(220000.0, 220000.0)
	elif layer == ScaleFrame.APPROACH:
		plane.size = Vector2(160000.0, 160000.0)
	else:
		plane.size = Vector2(48000.0, 48000.0)


func _sync_star(sim) -> void:
	var layer := int(sim.layer)
	var radius := float(sim.star_radius)
	var at := chart(Vector2.ZERO, 0.0)
	if layer == ScaleFrame.CHART:
		radius = 160.0
		var origin: Vector2 = sim.local_origin
		at = chart(Vector2.ZERO - origin, 0.0)
	if _star_mesh == null:
		_star_mesh = MeshInstance3D.new()
		_star_mesh.name = "Star"
		var ball := SphereMesh.new()
		ball.radial_segments = 64
		ball.rings = 32
		_star_mesh.mesh = ball
		var mat := ShaderMaterial.new()
		mat.shader = _star_shader
		_star_mesh.material_override = mat
		_star_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_star_mesh)
		_star_glow = MeshInstance3D.new()
		_star_glow.name = "Corona"
		var haze := SphereMesh.new()
		haze.radial_segments = 40
		haze.rings = 20
		_star_glow.mesh = haze
		var glow := ShaderMaterial.new()
		glow.shader = _corona_shader
		_star_glow.material_override = glow
		_star_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_star_glow)
	var core := Color(str(sim.defs.system.star.color))
	(_star_mesh.mesh as SphereMesh).radius = radius
	(_star_mesh.mesh as SphereMesh).height = radius * 2.0
	(_star_mesh.material_override as ShaderMaterial).set_shader_parameter("albedo", core.lightened(0.12))
	(_star_glow.mesh as SphereMesh).radius = radius * 1.55
	(_star_glow.mesh as SphereMesh).height = radius * 3.1
	(_star_glow.material_override as ShaderMaterial).set_shader_parameter("albedo", core)
	if _star_far != null:
		_star_far.visible = false
	if _star_rays == null:
		_star_rays = MeshInstance3D.new()
		_star_rays.name = "Spokes"
		var card := QuadMesh.new()
		card.orientation = PlaneMesh.FACE_Z
		_star_rays.mesh = card
		var rays := ShaderMaterial.new()
		rays.shader = _ray_shader
		rays.render_priority = 2
		_star_rays.material_override = rays
		_star_rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_star_rays)
	var spoke_card := _star_rays.mesh as QuadMesh
	var reach := radius * 1.85
	if layer == ScaleFrame.BAND:
		var nearest := 1.0e9
		for body in sim.planets:
			var prow: Dictionary = body
			var shown := _present_body(sim, prow)
			var shown_at: Vector2 = shown.center as Vector2
			nearest = minf(nearest, shown_at.length() - float(shown.radius))
		if nearest < 1.0e8:
			reach = minf(reach, maxf(radius * 1.35, nearest - 240.0))
	spoke_card.size = Vector2(reach * 2.0, reach * 2.0)
	(_star_rays.material_override as ShaderMaterial).set_shader_parameter("albedo", core.lightened(0.05))
	# The meshes used to stay at 3D zero. The camera's render origin is the
	# keel, so that put Helion around the dock and buried the hull.
	_star_mesh.position = at
	_star_glow.position = at
	_star_rays.position = at
	var show_star := layer == ScaleFrame.BAND or layer == ScaleFrame.CHART
	_star_mesh.visible = show_star
	_star_glow.visible = show_star
	_star_rays.visible = show_star
	if show_star:
		var eye := get_viewport().get_camera_3d()
		if eye != null:
			var to_eye := eye.global_position - _star_rays.global_position
			if to_eye.length_squared() > 4.0:
				var z_axis := to_eye.normalized()
				var x_axis := Vector3.UP.cross(z_axis)
				if x_axis.length_squared() < 0.0001:
					x_axis = Vector3.RIGHT.cross(z_axis)
				x_axis = x_axis.normalized()
				var y_axis := z_axis.cross(x_axis).normalized()
				_star_rays.basis = Basis(x_axis, y_axis, z_axis)
	if show_star:
		var star_name := str(sim.defs.system.star.name)
		_tag(star_name, at + Vector3(0.0, radius + 40.0, 0.0), Color("f0c27a"), 16)


func _sync_planets(sim) -> void:
	var layer := int(sim.layer)
	if layer == ScaleFrame.CHART:
		_sync_chart_bodies(sim)
		return
	if layer == ScaleFrame.APPROACH:
		_sync_approach_body(sim)
		return
	if layer == ScaleFrame.SITE:
		_sync_site(sim)
		return
	for body in sim.planets:
		var row: Dictionary = body
		var bid := str(row.get("id", "planet"))
		var node := _body_node(bid)
		var body_pos: Vector2 = row.pos
		var clearance: float = sim.player.pos.distance_to(body_pos) - float(row.radius)
		# The giant limb is only for a keel scraping the crust. The dock sits
		# well clear of Aegis, so the login view keeps the real world.
		var limb: bool = bid == str(sim.body_id) and clearance < 80.0
		var radius := float(row.radius)
		var center2 := body_pos
		if limb:
			radius = ScaleFrame.LIMB_RADIUS
			var ship: Vector2 = sim.player.pos
			var away: Vector2 = ship - row.pos
			if away.length() < 1.0:
				away = Vector2.RIGHT
			away = away.normalized()
			center2 = ship - away * (radius + _limb_gap())
			node.position = chart(center2, -140.0)
		else:
			var shown := _present_body(sim, row)
			radius = float(shown.radius)
			center2 = shown.center as Vector2
			node.position = chart(center2, 0.0)
		node.rotation.y = float(row.get("angle", 0.0)) + float(sim.time) * float(row.get("spin", 0.05))
		var ball := node.get_node("Ball") as MeshInstance3D
		(ball.mesh as SphereMesh).radius = radius
		(ball.mesh as SphereMesh).height = radius * 2.0
		var air := node.get_node("Air") as MeshInstance3D
		(air.mesh as SphereMesh).radius = radius * 1.036
		(air.mesh as SphereMesh).height = radius * 2.072
		var colors: Array = row.get("colors", ["#889088"])
		var mat := ball.material_override as ShaderMaterial
		var albedo := Color(str(colors[0]))
		var land := albedo
		if colors.size() > 1:
			land = Color(str(colors[1]))
		var world := chart(row.pos, 0.0)
		var to_star := -world
		if to_star.length_squared() < 1.0:
			to_star = Vector3(1.0, 0.2, 0.0)
		to_star = to_star.normalized()
		var seed := float(absi(hash(bid)) % 1000) * 0.017
		mat.set_shader_parameter("albedo", albedo)
		mat.set_shader_parameter("land", land)
		mat.set_shader_parameter("to_star", to_star)
		mat.set_shader_parameter("seed", seed)
		mat.set_shader_parameter("spin", float(sim.time) * 0.02)
		var legal := str(row.get("legal", ""))
		var city := 1.0 if (legal.contains("capital") or legal.contains("pdo")) else 0.0
		mat.set_shader_parameter("city", city)
		var clouds := node.get_node("Clouds") as MeshInstance3D
		clouds.visible = true
		var well := node.get_node_or_null("Well") as MeshInstance3D
		if well != null:
			well.visible = false
		(clouds.mesh as SphereMesh).radius = radius * 1.018
		(clouds.mesh as SphereMesh).height = radius * 2.036
		var cloud_mat := clouds.material_override as ShaderMaterial
		cloud_mat.set_shader_parameter("to_star", to_star)
		cloud_mat.set_shader_parameter("seed", seed)
		cloud_mat.set_shader_parameter("spin", float(sim.time) * 0.02)
		var air_mat := air.material_override as ShaderMaterial
		air_mat.set_shader_parameter("to_star", to_star)
		air_mat.set_shader_parameter("tint", albedo.lerp(Color(0.55, 0.78, 0.88), 0.55))
		var draw: Dictionary = row
		if limb:
			draw = row.duplicate()
			draw.ring = false
			draw.moon = false
		_sync_ring(node, draw, radius, to_star, _neighbor_clearance(sim, row, center2, radius))
		_sync_moon(node, sim, draw, radius)
		_parallax(node, radius, float(sim.time), limb)
		var label_at := chart(center2, radius + 28.0)
		if limb:
			var outward: Vector2 = sim.player.pos - row.pos
			if outward.length() < 1.0:
				outward = Vector2.RIGHT
			outward = outward.normalized()
			label_at = chart(sim.player.pos - outward * minf(_limb_gap() * 0.45, 900.0), 260.0)
		_tag(str(row.get("name", "")), label_at, Color("e6d7bf"), 16)


func _sync_density(sim) -> void:
	var belt: Dictionary = sim.defs.system.get("belt", {})
	if ScaleFrame.belt_is_volume(belt):
		_sync_belt_volume(sim, belt)
	var spec: Dictionary = sim.defs.system.get("stream", {})
	var ribbon := _prop("stream_volume")
	if spec.is_empty() or str(spec.get("id", "")) == "":
		ribbon.visible = false
		_used.erase("prop:stream_volume")
	else:
		if ribbon.mesh == null:
			var box := BoxMesh.new()
			box.size = Vector3(1.0, 8.0, 36.0)
			ribbon.mesh = box
			var haze := StandardMaterial3D.new()
			haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			haze.albedo_color = Color(0.62, 0.58, 0.48, 0.22)
			haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ribbon.material_override = haze
		var span := float(spec.get("span", 400.0))
		(ribbon.mesh as BoxMesh).size = Vector3(maxf(span, 80.0), 10.0, 48.0)
		ribbon.position = chart(sim.stream_origin, 4.0)
		ribbon.visible = int(sim.layer) == ScaleFrame.BAND
	var shell_i := 0
	for shell in sim.traffic:
		var row: Dictionary = shell
		var craft := _prop("shell%d" % shell_i)
		shell_i += 1
		if craft.mesh == null:
			var hull := BoxMesh.new()
			hull.size = Vector3(18.0, 6.0, 8.0)
			craft.mesh = hull
			craft.material_override = _hull_mat(Color("8a9390"))
			var nose := MeshInstance3D.new()
			nose.name = "Nose"
			var wedge := BoxMesh.new()
			wedge.size = Vector3(8.0, 3.2, 4.2)
			nose.mesh = wedge
			nose.position = Vector3(12.0, 0.3, 0.0)
			nose.material_override = _hull_mat(Color("9aa39a"))
			craft.add_child(nose)
		craft.position = chart(row.pos, 8.0)
		craft.visible = int(sim.layer) == ScaleFrame.BAND
	var pin := _prop("claim_pin")
	var show_pin := bool(sim.claim.get("owned", false)) and str(sim.claim.get("system_id", "")) == str(sim.defs.system.id)
	if not show_pin:
		pin.visible = false
		_used.erase("prop:claim_pin")
		return
	if pin.mesh == null:
		var mast := CylinderMesh.new()
		mast.top_radius = 1.2
		mast.bottom_radius = 2.4
		mast.height = 70.0
		pin.mesh = mast
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("e7f2c8")
		glow.emission_enabled = true
		glow.emission = Color("d7e6a8")
		glow.emission_energy_multiplier = 1.2
		pin.material_override = glow
	var at := Vector2(float(sim.claim.get("x", sim.pocket_pos.x)), float(sim.claim.get("y", sim.pocket_pos.y)))
	pin.position = chart(at, 35.0)
	pin.visible = int(sim.layer) == ScaleFrame.BAND


func _sync_belt_volume(sim, belt: Dictionary) -> void:
	var hoop := _prop("belt_volume")
	if hoop.mesh == null:
		var torus := TorusMesh.new()
		torus.rings = 64
		torus.ring_segments = 10
		hoop.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.45, 0.4, 0.34, 0.28)
		hoop.material_override = mat
		hoop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var radius := float(belt.get("radius", 1000.0))
	var width := maxf(float(belt.get("width", 40.0)), 24.0)
	(hoop.mesh as TorusMesh).inner_radius = maxf(radius - width, 8.0)
	(hoop.mesh as TorusMesh).outer_radius = radius + width
	hoop.position = chart(Vector2.ZERO, 0.0)
	hoop.visible = int(sim.layer) == ScaleFrame.BAND


func _parallax(node: Node3D, radius: float, spin: float, on: bool) -> void:
	for i in 3:
		var band := node.get_node_or_null("Para%d" % i) as MeshInstance3D
		if band == null:
			band = MeshInstance3D.new()
			band.name = "Para%d" % i
			var shell := SphereMesh.new()
			shell.radial_segments = 28
			shell.rings = 16
			band.mesh = shell
			var mat := ShaderMaterial.new()
			mat.shader = _air_shader
			band.material_override = mat
			band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(band)
		band.visible = on
		if not on:
			continue
		var grow := 1.012 + float(i) * 0.02
		(band.mesh as SphereMesh).radius = radius * grow
		(band.mesh as SphereMesh).height = radius * grow * 2.0
		band.rotation = Vector3(0.15 * float(i), spin * (0.05 + float(i) * 0.03), 0.08)
		var tint := Color(0.45, 0.62, 0.78, 0.22 - float(i) * 0.04)
		(band.material_override as ShaderMaterial).set_shader_parameter("tint", tint)


func _sync_chart_bodies(sim) -> void:
	for body in sim.planets:
		var row: Dictionary = body
		var node := _body_node(str(row.id))
		var icon := 900.0
		node.position = chart(row.chart_km - sim.local_origin, 0.0)
		var ball := node.get_node("Ball") as MeshInstance3D
		(ball.mesh as SphereMesh).radius = icon
		(ball.mesh as SphereMesh).height = icon * 2.0
		var air := node.get_node("Air") as MeshInstance3D
		(air.mesh as SphereMesh).radius = icon * 1.08
		(air.mesh as SphereMesh).height = icon * 2.16
		var clouds := node.get_node("Clouds") as MeshInstance3D
		clouds.visible = false
		_parallax(node, icon, 0.0, false)
		var well := node.get_node_or_null("Well") as MeshInstance3D
		if well == null:
			well = MeshInstance3D.new()
			well.name = "Well"
			var hoop := TorusMesh.new()
			hoop.rings = 48
			hoop.ring_segments = 8
			well.mesh = hoop
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.55, 0.7, 0.62, 0.35)
			well.material_override = mat
			well.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(well)
		var soi := ScaleFrame.soi_km(row)
		var visual := ScaleFrame.chart_view(sim, Vector2(soi, 0.0)).x
		(well.mesh as TorusMesh).inner_radius = maxf(visual - 28.0, 20.0)
		(well.mesh as TorusMesh).outer_radius = visual + 28.0
		well.visible = true
		_tag(str(row.name), node.position + Vector3(0.0, icon + 80.0, 0.0), Color("e6d7bf"), 18)
	var lane_i := 0
	for gate in sim.gates:
		var row: Dictionary = gate
		var buoy := _prop("chartlane%d" % lane_i)
		lane_i += 1
		if buoy.mesh == null:
			var ring := TorusMesh.new()
			ring.inner_radius = 36.0
			ring.outer_radius = 52.0
			ring.rings = 28
			ring.ring_segments = 8
			buoy.mesh = ring
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color("9fd0c8")
			glow.emission_enabled = true
			glow.emission = Color("7d9a86")
			glow.emission_energy_multiplier = 0.8
			buoy.material_override = glow
			buoy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var at: Vector2 = sim.chart_lane_pos(row)
		buoy.position = chart(at, 0.0)
		buoy.visible = true
		_tag(str(row.get("name", "Lane")), buoy.position + Vector3(0.0, 70.0, 0.0), Color("e6d7a8"), 18)
	if str(sim.defs.system.id) == "HC-V1-R1-S1":
		var flash := 0.55 + 0.45 * sin(float(sim.time) * 4.2)
		var dock_mark := _prop("chart_dock")
		if str(dock_mark.get_meta("built", "")) != "wide":
			var ring := TorusMesh.new()
			ring.inner_radius = 150.0
			ring.outer_radius = 230.0
			ring.rings = 48
			ring.ring_segments = 10
			dock_mark.mesh = ring
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color("d7fbff")
			glow.emission_enabled = true
			glow.emission = Color("7ee7f2")
			dock_mark.material_override = glow
			dock_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dock_mark.set_meta("built", "wide")
		var dock_at: Vector2 = sim.dock_buoy_km() - sim.local_origin
		dock_mark.position = chart(dock_at, 0.0)
		dock_mark.visible = true
		var dock_glow := dock_mark.material_override as StandardMaterial3D
		if dock_glow != null:
			dock_glow.emission_energy_multiplier = 1.1 + flash * 2.2
		var halo := _prop("chart_dock_halo")
		if str(halo.get_meta("built", "")) != "wide":
			var outer := TorusMesh.new()
			outer.inner_radius = 250.0
			outer.outer_radius = 310.0
			outer.rings = 48
			outer.ring_segments = 8
			halo.mesh = outer
			var wash := StandardMaterial3D.new()
			wash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wash.albedo_color = Color(0.62, 0.93, 0.97, 0.35)
			wash.emission_enabled = true
			wash.emission = Color("9eecf5")
			halo.material_override = wash
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			halo.set_meta("built", "wide")
		halo.position = chart(dock_at, 12.0)
		halo.visible = true
		_tag("Helion Dock", dock_mark.position + Vector3(0.0, 220.0, 0.0), Color("9eecf5"), 28)
	var mark := _prop("chart_ship")
	if mark.mesh == null:
		var dot := SphereMesh.new()
		dot.radius = 42.0
		dot.height = 84.0
		mark.mesh = dot
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("d7e6c8")
		mark.material_override = glow
	mark.position = chart(sim.player.pos, 0.0)
	mark.visible = true


func _sync_approach_body(sim) -> void:
	var focus := str(sim.body_id)
	for body in sim.planets:
		var row: Dictionary = body
		var node := _body_node(str(row.id))
		var mine := str(row.id) == focus
		node.visible = mine
		if not mine:
			_used.erase("body:" + str(row.id))
			continue
		var radius := ScaleFrame.radius_km(row)
		node.position = chart(Vector2.ZERO, 0.0)
		var ball := node.get_node("Ball") as MeshInstance3D
		(ball.mesh as SphereMesh).radius = radius
		(ball.mesh as SphereMesh).height = radius * 2.0
		var air := node.get_node("Air") as MeshInstance3D
		(air.mesh as SphereMesh).radius = radius * 1.01
		(air.mesh as SphereMesh).height = radius * 2.02
		var clouds := node.get_node("Clouds") as MeshInstance3D
		clouds.visible = true
		(clouds.mesh as SphereMesh).radius = radius * 1.004
		(clouds.mesh as SphereMesh).height = radius * 2.008
		_parallax(node, radius, float(sim.time), true)
		var well := node.get_node_or_null("Well") as MeshInstance3D
		if well != null:
			well.visible = false
		_tag(str(row.name), chart(Vector2.ZERO, radius * 0.15), Color("e6d7bf"), 16)


func _sync_site(sim) -> void:
	for body in sim.planets:
		var bid := str(body.id)
		if _bodies.has(bid):
			(_bodies[bid] as Node3D).visible = false
	var ground := _prop("site_ground")
	if ground.mesh == null:
		var slab := BoxMesh.new()
		slab.size = Vector3(520.0, 2.0, 520.0)
		ground.mesh = slab
		var turf := ShaderMaterial.new()
		turf.shader = _ground_shader
		ground.material_override = turf
	ground.position = chart(sim.site_pos, -1.0)
	var dome := _prop("site_dome")
	if dome.mesh == null:
		var ball := SphereMesh.new()
		ball.radius = 46.0
		ball.height = 40.0
		dome.mesh = ball
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.7, 0.86, 0.74, 0.28)
		glass.emission_enabled = true
		glass.emission = Color("d7e6c8")
		glass.emission_energy_multiplier = 0.15
		dome.material_override = glass
	dome.position = chart(sim.site_pos, 16.0)
	var alive := bool(sim.claim.get("pen", {}).get("alive", false))
	for i in 3:
		var beast := _prop("kine%d" % i)
		if beast.mesh == null:
			var box := BoxMesh.new()
			box.size = Vector3(2.4, 1.4, 4.2)
			beast.mesh = box
			beast.material_override = _hull_mat(Color("c4b49a"))
		var spot := Vector2.from_angle(float(i) * 2.1) * (8.0 + float(i) * 3.0)
		beast.position = chart(sim.site_pos + spot, 0.8)
		beast.visible = alive
	var lamp := _prop("grow_light")
	if lamp.mesh == null:
		var bulb := SphereMesh.new()
		bulb.radius = 1.6
		bulb.height = 3.2
		lamp.mesh = bulb
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("e7f2c8")
		glow.emission_enabled = true
		glow.emission = Color("d7e6a8")
		glow.emission_energy_multiplier = 1.4
		lamp.material_override = glow
	lamp.position = chart(sim.site_pos + Vector2(18.0, 6.0), 7.0)
	_tag("Quiet valley", chart(sim.site_pos, 24.0), Color("d7e6c8"), 14)


func _body_node(bid: String) -> Node3D:
	_used["body:" + bid] = true
	if _bodies.has(bid):
		(_bodies[bid] as Node3D).visible = true
		return _bodies[bid]
	var node := Node3D.new()
	node.name = bid
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radial_segments = 120
	sphere.rings = 60
	ball.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = _planet_shader
	ball.material_override = mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(ball)
	var clouds := MeshInstance3D.new()
	clouds.name = "Clouds"
	var puff := SphereMesh.new()
	puff.radial_segments = 64
	puff.rings = 32
	clouds.mesh = puff
	var cloud_mat := ShaderMaterial.new()
	cloud_mat.shader = _cloud_shader
	clouds.material_override = cloud_mat
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(clouds)
	var air := MeshInstance3D.new()
	air.name = "Air"
	var shell := SphereMesh.new()
	shell.radial_segments = 80
	shell.rings = 40
	air.mesh = shell
	var haze := ShaderMaterial.new()
	haze.shader = _air_shader
	air.material_override = haze
	air.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(air)
	add_child(node)
	_bodies[bid] = node
	return node


func _neighbor_clearance(sim, row: Dictionary, center: Vector2, radius: float) -> float:
	var limit := radius * 1.45
	var bid := str(row.get("id", ""))
	var pocket: Dictionary = sim.defs.system.get("pocket", {})
	if str(pocket.get("anchor", "")) == bid and sim.pocket_pos != Vector2.ZERO:
		var pocket_near := center.distance_to(sim.pocket_pos) - float(pocket.get("radius", 0.0))
		limit = minf(limit, pocket_near - 80.0)
	var field: Dictionary = sim.defs.system.get("trash", {})
	if str(field.get("anchor", "")) == bid and sim.trash_pos != Vector2.ZERO:
		var trash_near := center.distance_to(sim.trash_pos) - float(field.get("spread", 120.0))
		limit = minf(limit, trash_near - 40.0)
	if sim.player.is_empty() == false:
		limit = minf(limit, center.distance_to(sim.player.pos) - 160.0)
	return limit


func _present_body(sim, row: Dictionary) -> Dictionary:
	var true_r := float(row.radius)
	var center: Vector2 = row.pos
	if int(sim.layer) != ScaleFrame.BAND:
		return {"center": center, "radius": true_r}
	var ship: Vector2 = sim.player.pos
	var radial: Vector2 = ship - center
	var gap := radial.length()
	# A keel on the crust uses the giant limb instead of this loom.
	if gap < true_r + 48.0:
		return {"center": center, "radius": true_r}
	if str(row.get("id", "")) == str(sim.body_id) and gap - true_r < 80.0:
		return {"center": center, "radius": true_r}
	var away := radial / gap
	# Shift the center away from the keel and grow the shell by the same
	# amount, so the near face stays on the real crust and the limb fills
	# more of the glass. Neighbors and the eye stay outside the shell.
	var grow := minf(true_r * 0.28, _loom_room(sim, center, true_r, away))
	grow = maxf(grow, 0.0)
	return {"center": center - away * grow, "radius": true_r + grow}


func _loom_room(sim, center: Vector2, true_r: float, away: Vector2) -> float:
	var grow := true_r * 0.28
	var pocket: Dictionary = sim.defs.system.get("pocket", {})
	var marks: Array = []
	marks.append({"at": sim.player.pos, "pad": 80.0})
	if sim.beacon_pos != Vector2.ZERO:
		marks.append({"at": sim.beacon_pos, "pad": 90.0})
	if sim.pocket_pos != Vector2.ZERO:
		var pocket_r := float(pocket.get("radius", 0.0))
		var to_pocket: Vector2 = sim.pocket_pos - center
		if to_pocket.length() > pocket_r + 1.0:
			marks.append({"at": center + to_pocket.normalized() * (to_pocket.length() - pocket_r), "pad": 40.0})
	for rock in sim.trash:
		marks.append({"at": rock.pos, "pad": 36.0})
	for actor in sim.actors:
		if bool(actor.get("alive", true)):
			marks.append({"at": actor.pos, "pad": 48.0})
	for mark in marks:
		var spot: Vector2 = mark.at as Vector2
		var pad := float(mark.pad)
		var rel: Vector2 = spot - center
		var rm := true_r + pad
		var numer := rel.length_squared() - rm * rm
		var denom := 2.0 * (rm - rel.dot(away))
		if numer <= 0.0:
			return 0.0
		if denom > 1.0:
			grow = minf(grow, numer / denom)
	var eye := get_viewport().get_camera_3d()
	if eye != null:
		var c3 := chart(center, 0.0)
		var shifted := chart(center - away, 0.0)
		var axis := shifted - c3
		if axis.length_squared() > 0.0001:
			axis = axis.normalized()
			var w := eye.global_position - c3
			var rm := true_r + 200.0
			var numer := w.length_squared() - rm * rm
			var denom := 2.0 * (w.dot(axis) + rm)
			if numer <= 0.0:
				return 0.0
			if denom > 1.0:
				grow = minf(grow, numer / denom)
	return maxf(grow, 0.0)


func _sync_ring(node: Node3D, row: Dictionary, radius: float, to_star: Vector3, max_outer: float = -1.0) -> void:
	var ring := node.get_node_or_null("Ring") as MeshInstance3D
	if not bool(row.get("ring", false)):
		if ring != null:
			ring.visible = false
		var hidden := node.get_node_or_null("RingOuter") as MeshInstance3D
		if hidden != null:
			hidden.visible = false
		return
	if ring == null:
		ring = MeshInstance3D.new()
		ring.name = "Ring"
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = _ring_shader
		ring.material_override = mat
		node.add_child(ring)
	var band := maxf(28.0, radius * 0.085)
	var outer_edge := radius + band * 3.35
	if max_outer > 0.0 and outer_edge > max_outer:
		band = maxf(8.0, (max_outer - radius) / 3.35)
	ring.mesh = _annulus(radius + band * 0.4, radius + band * 2.15, maxf(5.5, radius * 0.02), 112)
	ring.rotation.x = 0.28
	ring.visible = true
	var outer := node.get_node_or_null("RingOuter") as MeshInstance3D
	if outer == null:
		outer = MeshInstance3D.new()
		outer.name = "RingOuter"
		outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var faint := ShaderMaterial.new()
		faint.shader = _ring_shader
		outer.material_override = faint
		node.add_child(outer)
	outer.mesh = _annulus(radius + band * 2.3, radius + band * 3.35, maxf(2.4, radius * 0.01), 96)
	outer.rotation.x = 0.28
	outer.visible = true
	var ice := Color(0.86, 0.92, 0.95, 0.92)
	if str(row.get("ring_kind", "")) != "ice":
		var colors: Array = row.get("colors", ["#889088", "#667066", "#d7e6c8"])
		ice = Color(str(colors[mini(2, colors.size() - 1)]))
		ice.a = 0.8
	var ring_mat := ring.material_override as ShaderMaterial
	ring_mat.set_shader_parameter("albedo", ice)
	ring_mat.set_shader_parameter("planet_pos", node.position)
	ring_mat.set_shader_parameter("to_star", to_star)
	ring_mat.set_shader_parameter("seed", 0.2)
	ring_mat.set_shader_parameter("glitter", 1.0)
	var outer_mat := outer.material_override as ShaderMaterial
	var dust := ice
	dust.a = 0.42
	outer_mat.set_shader_parameter("albedo", dust)
	outer_mat.set_shader_parameter("planet_pos", node.position)
	outer_mat.set_shader_parameter("to_star", to_star)
	outer_mat.set_shader_parameter("seed", 1.4)
	outer_mat.set_shader_parameter("glitter", 0.65)
	if str(row.get("ring_kind", "")) == "ice":
		_ice_sparks(ring, radius + band * 1.25, band)


func _sync_moon(node: Node3D, sim, row: Dictionary, radius: float) -> void:
	var moon := node.get_node_or_null("Moon") as MeshInstance3D
	if not bool(row.get("moon", false)):
		if moon != null:
			moon.visible = false
		return
	if moon == null:
		moon = MeshInstance3D.new()
		moon.name = "Moon"
		var sphere := SphereMesh.new()
		sphere.radial_segments = 40
		sphere.rings = 20
		moon.mesh = sphere
		var mat := ShaderMaterial.new()
		mat.shader = _rock_shader
		moon.material_override = mat
		moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(moon)
	var moon_r := maxf(22.0, radius * 0.1)
	(moon.mesh as SphereMesh).radius = moon_r
	(moon.mesh as SphereMesh).height = moon_r * 2.0
	var orbit := radius + moon_r * 3.1
	var ang := float(sim.time) * 0.35 + 0.6
	moon.position = Vector3(cos(ang) * orbit, moon_r * 0.3, sin(ang) * orbit)
	var colors: Array = row.get("colors", ["#889088", "#9aa090"])
	var moon_mat := moon.material_override as ShaderMaterial
	moon_mat.set_shader_parameter("albedo", Color(str(colors[mini(1, colors.size() - 1)])))
	moon_mat.set_shader_parameter("seed", 2.4)
	moon.visible = true


func _sync_ships(sim) -> void:
	_place_ship(sim, sim.player, "player")
	for actor in sim.actors:
		if bool(actor.get("alive", false)):
			_place_ship(sim, actor, "actor:" + str(actor.get("name", actor.get("agent_id", "a"))))
	for mate in sim.captains:
		if bool(mate.get("alive", false)):
			_place_ship(sim, mate, "mate:" + str(mate.get("name", "mate")))


func _place_ship(sim, ship: Dictionary, key: String) -> void:
	var holder := _ship_holder(key)
	var class_id := str(ship.get("class_id", "vesper"))
	var shapes: Array = Silhouette.shapes_of(sim.defs, ship.modules)
	var layers: Array = Silhouette.layers_of(sim.defs, ship.modules)
	var sockets: Array = _weapon_sockets(ship.get("modules", []))
	var mesh_key := class_id + "|" + str(shapes) + "|" + str(layers.size()) + "|" + "|".join(sockets)
	if str(holder.get_meta("mesh_key", "")) != mesh_key:
		_fill_ship(holder, class_id, shapes, layers, sockets)
		holder.set_meta("mesh_key", mesh_key)
	var hull: Dictionary = sim.defs.ships[class_id]
	var hp := clampf(float(ship.hp) / maxf(float(ship.max_hp), 1.0), 0.0, 1.0)
	var body := Color(str(hull.color)).lerp(Color("3a1818"), (1.0 - hp) * 0.65)
	var hurt := clampf(float(ship.get("hurt_cd", 0.0)) / 0.4, 0.0, 1.0)
	body = body.lerp(Color("ffe6c8"), hurt * 0.62)
	var accent := Color(str(hull.accent))
	for child in holder.get_children():
		var part := str(child.name)
		if _hull_part(part):
			var paint := body
			if part == "Deck":
				paint = body.lightened(0.16)
			elif part.begins_with("Trim"):
				paint = accent
			_paint_hull(child, paint, accent)
	var thrusting := bool(ship.get("thrusting", false))
	holder.set_meta("thrusting", thrusting)
	if int(sim.layer) == ScaleFrame.SITE and key == "player":
		holder.scale = Vector3(0.28, 0.28, 0.28)
		holder.position = chart(sim.site_pos + Vector2(36.0, -20.0), 280.0)
		holder.rotation = Vector3(-0.4, float(ship.rot), 0.15)
	elif int(sim.layer) == ScaleFrame.CHART and key != "player":
		holder.visible = false
		return
	else:
		holder.visible = true
		holder.scale = Vector3(6.0, 6.0, 6.0) if int(sim.layer) == ScaleFrame.CHART else Vector3.ONE
		_banked(holder, ship.pos, float(ship.rot), 2.0, ship)
	_pulse_lamps(holder)
	_place_plumes(holder, ship)
	_place_wake(holder, ship)
	_place_jet_light(holder, ship)
	var on_band := int(sim.layer) == ScaleFrame.BAND
	_combat_fx(holder, sim, ship, on_band and holder.visible)
	var call := str(ship.get("name", hull.get("callsign", class_id)))
	if key == "player":
		call = str(hull.get("callsign", call))
	var tag := str(ship.get("corp_tag", "")).strip_edges()
	if tag != "":
		call = "%s  ·  %s" % [call, tag]
	_tag(call, chart(ship.pos + Vector2(22.0, 18.0), float(holder.get_meta("crown", 16.0))), Color("e6d7bf"), 14)


func _combat_fx(holder: Node3D, sim, ship: Dictionary, band: bool) -> void:
	var flash := holder.get_node_or_null("MuzzleFlash") as MeshInstance3D
	if flash == null:
		flash = MeshInstance3D.new()
		flash.name = "MuzzleFlash"
		var ball := SphereMesh.new()
		ball.radius = 2.2
		ball.height = 4.4
		ball.radial_segments = 12
		ball.rings = 6
		flash.mesh = ball
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(flash)
		var flare := MeshInstance3D.new()
		flare.name = "Flare"
		var rod := CylinderMesh.new()
		rod.top_radius = 0.35
		rod.bottom_radius = 1.35
		rod.height = 7.5
		rod.radial_segments = 8
		flare.mesh = rod
		flare.position = Vector3(3.6, 0.0, 0.0)
		flare.rotation = Vector3(0.0, 0.0, -PI * 0.5)
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.add_child(flare)
	var ring := holder.get_node_or_null("HurtRing") as MeshInstance3D
	if ring == null:
		ring = MeshInstance3D.new()
		ring.name = "HurtRing"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.72
		torus.outer_radius = 1.0
		torus.rings = 22
		torus.ring_segments = 8
		ring.mesh = torus
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(ring)
	var life := 0.0
	if band:
		var stats: Dictionary = Fit.stats(sim.defs, ship)
		var gun: Dictionary = stats.get("gun", {})
		var cooldown := float(gun.get("cooldown", 0.3))
		var fire_cd := float(ship.get("fire_cd", 0.0))
		var since := cooldown - fire_cd
		if fire_cd > 0.0 and since >= 0.0 and since < 0.14:
			life = 1.0 - since / 0.14
	flash.visible = life > 0.02
	if life > 0.02:
		var nose := float(holder.get_meta("nose", 24.0))
		flash.position = Vector3(nose * 0.96, 2.2, 0.0)
		var span := 0.65 + life * 1.35
		var punch := clampf(_fx_read(sim), 1.0, 2.6)
		flash.scale = Vector3(span, span, span) * punch
		var tint := _shot_tint(str(ship.get("team", "")))
		_paint_bolt(flash, tint.lightened(0.35), 2.4 + life * 3.0, 0.92)
		var flare_node := flash.get_node_or_null("Flare") as MeshInstance3D
		if flare_node != null:
			_paint_bolt(flare_node, tint, 1.6 + life * 2.2, 0.55)
		holder.position += holder.basis * Vector3(-life * 2.4 * punch, 0.0, life * 0.35 * sin(float(sim.time) * 70.0))
		var muzzle := holder.get_node_or_null("MuzzleLight") as OmniLight3D
		if muzzle == null:
			muzzle = OmniLight3D.new()
			muzzle.name = "MuzzleLight"
			muzzle.shadow_enabled = false
			holder.add_child(muzzle)
		muzzle.position = flash.position
		muzzle.visible = true
		muzzle.light_color = tint
		muzzle.light_energy = 1.4 + life * 3.2
		muzzle.omni_range = 18.0 + life * 16.0 * punch
	else:
		var muzzle_off := holder.get_node_or_null("MuzzleLight") as OmniLight3D
		if muzzle_off != null:
			muzzle_off.visible = false
	var hurt := clampf(float(ship.get("hurt_cd", 0.0)) / 0.4, 0.0, 1.0)
	ring.visible = band and hurt > 0.05
	if ring.visible:
		var nose_r := float(holder.get_meta("nose", 24.0))
		ring.position = Vector3(0.0, 2.2, 0.0)
		var span_r := nose_r * lerpf(0.55, 1.08, 1.0 - hurt)
		ring.scale = Vector3(span_r, span_r * 0.35, span_r)
		_paint_bolt(ring, Color("ffe6c8"), 1.2 + hurt * 2.4, clampf(hurt * 0.8, 0.08, 0.85))
		var jig := sin(float(sim.time) * 54.0) * hurt * 0.9
		holder.position += holder.basis * Vector3(jig * 0.35, jig, jig * 0.45)
	_turret_fx(holder, sim, ship, band)
	_tank_fx(holder, sim, ship, band)


## A dorsal mount that traverses onto the lock. The holder basis is mirrored
## (local +Z is screen-left), so a turn of rel off the nose is local -rel.
func _turret_fx(holder: Node3D, sim, ship: Dictionary, band: bool) -> void:
	var mount := holder.get_node_or_null("Turret") as Node3D
	if mount == null:
		mount = Node3D.new()
		mount.name = "Turret"
		var crown := float(holder.get_meta("crown", 16.0))
		var nose := float(holder.get_meta("nose", 24.0))
		mount.position = Vector3(nose * 0.18, crown * 1.04, 0.0)
		holder.add_child(mount)
		var ring_base := MeshInstance3D.new()
		ring_base.name = "TurretRing"
		var drum := CylinderMesh.new()
		drum.top_radius = 2.1
		drum.bottom_radius = 2.6
		drum.height = 1.3
		drum.radial_segments = 14
		ring_base.mesh = drum
		ring_base.material_override = _hull_mat(Color("7c7a76"))
		mount.add_child(ring_base)
		var head := MeshInstance3D.new()
		head.name = "TurretHead"
		var cap := BoxMesh.new()
		cap.size = Vector3(3.6, 1.3, 2.8)
		head.mesh = cap
		head.position = Vector3(0.4, 1.0, 0.0)
		head.material_override = _hull_mat(Color("9a958c"))
		mount.add_child(head)
		for side in [-1.0, 1.0]:
			var barrel := _tube(mount, "TurretBarrel%s" % ("P" if side > 0.0 else "S"), 0.32, 6.4, Vector3(4.6, 1.1, side * 0.72), "x", Color("1a1e24"))
			_dress_barrel(barrel, 6.4, 0.18, 0.4)
	var fitted := false
	for socket_name in ["heavy_turret", "gun_sponson", "stake_gun"]:
		if holder.get_node_or_null(socket_name) != null:
			fitted = true
			break
	mount.visible = band and not fitted
	if not band:
		return
	var want := 0.0
	if bool(ship.get("lock_ok", false)) and ship.has("turret_aim"):
		var other = HelmCombat.find_unit(sim, str(ship.get("lock_id", "")))
		if other != null:
			var to: Vector2 = Vector2(other.pos) - Vector2(ship.pos)
			want = -wrapf(to.angle() - float(ship.rot), -PI, PI)
	var gun: Dictionary = Fit.stats(sim.defs, ship).gun
	var arc := float(gun.get("arc", 0.0))
	if arc > 0.0 and arc < PI:
		want = clampf(want, -arc, arc)
	var step := 3.2 * _frame_delta
	var aim_at := mount
	if fitted:
		for socket_name in ["heavy_turret", "gun_sponson", "stake_gun"]:
			var sock := holder.get_node_or_null(socket_name) as Node3D
			if sock != null:
				aim_at = sock
				break
	var now := float(aim_at.rotation.y)
	aim_at.rotation.y = now + clampf(wrapf(want - now, -PI, PI), -step, step)
	_pose_sockets(holder, ship)


## Shield hits light a shell around the hull with a ring running out from the
## impact side. Plate hits throw sparks; hull hits throw hotter, redder ones.
func _tank_fx(holder: Node3D, sim, ship: Dictionary, band: bool) -> void:
	var shell := holder.get_node_or_null("ShieldShell") as MeshInstance3D
	if shell == null:
		shell = MeshInstance3D.new()
		shell.name = "ShieldShell"
		var orb := SphereMesh.new()
		orb.radius = 1.0
		orb.height = 2.0
		orb.radial_segments = 28
		orb.rings = 14
		shell.mesh = orb
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = _shield_shader()
		shell.material_override = mat
		var nose := float(holder.get_meta("nose", 24.0))
		var crown := float(holder.get_meta("crown", 16.0))
		shell.position = Vector3(nose * 0.05, crown * 0.6, 0.0)
		shell.scale = Vector3(nose * 1.25, crown * 0.95, maxf(nose * 0.62, crown * 1.1))
		holder.add_child(shell)
	var sparks := holder.get_node_or_null("Sparks") as Node3D
	if sparks == null:
		sparks = Node3D.new()
		sparks.name = "Sparks"
		holder.add_child(sparks)
		var chip := BoxMesh.new()
		chip.size = Vector3(1.3, 0.5, 0.5)
		for i in 7:
			var bit := MeshInstance3D.new()
			bit.name = "Spark%d" % i
			bit.mesh = chip
			bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sparks.add_child(bit)
	var age := float(sim.time) - float(ship.get("hit_at", -10.0))
	var layer := str(ship.get("hit_layer", ""))
	var side := _hit_side(sim, ship)
	var shield_on := band and layer == "shield" and age >= 0.0 and age < 0.5
	shell.visible = shield_on
	if shield_on:
		var mat := shell.material_override as ShaderMaterial
		mat.set_shader_parameter("flash", 1.0 - age / 0.5)
		mat.set_shader_parameter("hit_dir", side)
	var spark_on := band and (layer == "armor" or layer == "hull") and age >= 0.0 and age < 0.4
	sparks.visible = spark_on
	if spark_on:
		var hot := layer == "hull"
		var nose_r := float(holder.get_meta("nose", 24.0))
		var crown_r := float(holder.get_meta("crown", 16.0))
		var base := Vector3(side.x * nose_r * 0.7, crown_r * 0.6, side.z * nose_r * 0.4)
		var fade := 1.0 - age / 0.4
		var seed_i := int(float(ship.get("hit_at", 0.0)) * 97.0)
		var i := 0
		for bit in sparks.get_children():
			var mesh_bit := bit as MeshInstance3D
			var a := float((seed_i * 37 + i * 61) % 360) * PI / 180.0
			var lift := float((seed_i * 13 + i * 29) % 100) / 100.0
			var fly := Vector3(side.x + cos(a) * 0.8, 0.4 + lift, side.z + sin(a) * 0.8).normalized()
			mesh_bit.position = base + fly * (2.0 + age * (60.0 if hot else 44.0))
			mesh_bit.look_at_from_position(mesh_bit.position, mesh_bit.position + fly + Vector3(0.001, 0.0, 0.0), Vector3.UP)
			var tint := Color("ffcf7a") if not hot else Color("ff7a3c")
			_paint_bolt(mesh_bit, tint, 2.6 * fade + 0.4, clampf(fade, 0.05, 1.0))
			i += 1


func _hit_side(sim, ship: Dictionary) -> Vector3:
	var best := Vector2.ZERO
	var best_d := 1.0e9
	for row in sim.impacts:
		if str(row.get("kind", "")) != "hit":
			continue
		var gap: float = Vector2(row.pos).distance_to(Vector2(ship.pos))
		if gap < best_d and gap < 80.0:
			best_d = gap
			best = -Vector2(row.get("dir", Vector2.ZERO))
	if best.length() < 0.01:
		return Vector3(1.0, 0.1, 0.0)
	var rel := wrapf(best.angle() - float(ship.rot), -PI, PI)
	return Vector3(cos(rel), 0.12, sin(rel)).normalized()


func _shield_shader() -> Shader:
	if _mesh_cache.has("shield_shader"):
		return _mesh_cache["shield_shader"]
	var shader := _compile("""
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.44, 0.8, 1.0, 1.0);
uniform float flash = 0.0;
uniform vec3 hit_dir = vec3(1.0, 0.0, 0.0);
varying vec3 obj_n;
void vertex() {
	obj_n = NORMAL;
}
void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.4);
	float d = acos(clamp(dot(normalize(obj_n), normalize(hit_dir)), -1.0, 1.0));
	float wave = (1.0 - flash) * 2.2;
	float ring = smoothstep(0.32, 0.0, abs(d - wave));
	float spot = smoothstep(1.1, 0.0, d) * flash;
	float cells = 0.6 + 0.4 * sin(obj_n.x * 40.0) * sin(obj_n.y * 40.0) * sin(obj_n.z * 40.0);
	float glow = flash * (0.18 * rim + ring * 0.8 * cells) + spot * 0.7;
	ALBEDO = tint.rgb * glow * 1.6;
	ALPHA = clamp(glow, 0.0, 1.0);
}
""")
	_mesh_cache["shield_shader"] = shader
	return shader


func _add_bridge(holder: Node3D, class_id: String, height: float, tail: float) -> void:
	var deck := Vector3(18.0, height, 0.0)
	var deck_size := Vector3(14.0, 5.5, 6.0)
	if class_id == "anvil":
		deck = Vector3(10.0, height, 0.0)
		deck_size = Vector3(12.0, 7.0, 14.0)
	elif class_id == "kestrel":
		deck = Vector3(12.0, height, 0.0)
		deck_size = Vector3(12.0, 5.0, 8.0)
	elif class_id == "cutter" or class_id == "skiff":
		deck = Vector3(6.0, height, 0.0)
		deck_size = Vector3(8.0, 4.0, 5.0)
	var bridge := MeshInstance3D.new()
	bridge.name = "Bridge"
	bridge.mesh = _bevel_box(deck_size, 0.42)
	bridge.position = deck + Vector3(0.0, deck_size.y * 0.5, 0.0)
	bridge.material_override = _hull_mat(Color("1c2428"))
	holder.add_child(bridge)
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var canopy_len := deck_size.x * 0.62
	var canopy_w := deck_size.z * 0.52
	var canopy_h := 2.7
	glass.mesh = _canopy_mesh(canopy_len, canopy_w, canopy_h)
	glass.position = bridge.position + Vector3(deck_size.x * 0.06, deck_size.y * 0.5, 0.0)
	var pane := ShaderMaterial.new()
	pane.shader = _glass_shader
	pane.set_shader_parameter("albedo", Color(0.45, 0.78, 0.82, 0.4))
	glass.material_override = pane
	holder.add_child(glass)
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var brow := BoxMesh.new()
	brow.size = Vector3(canopy_len * 0.42, 0.28, canopy_w * 1.08)
	frame.mesh = brow
	frame.position = glass.position + Vector3(-canopy_len * 0.22, canopy_h * 0.78, 0.0)
	frame.material_override = _hull_mat(Color("1a2024"))
	holder.add_child(frame)
	var mast := MeshInstance3D.new()
	mast.name = "Mast"
	var rod := BoxMesh.new()
	rod.size = Vector3(0.4, maxf(height * 0.42, 6.0), 0.4)
	mast.mesh = rod
	mast.position = bridge.position + Vector3(-deck_size.x * 0.2, deck_size.y * 0.5 + rod.size.y * 0.5, 0.0)
	mast.material_override = _hull_mat(Color("242a30"))
	holder.add_child(mast)
	var bell := MeshInstance3D.new()
	bell.name = "Bell"
	bell.mesh = _bell_mesh(6.2, 0.9, 2.05)
	bell.position = Vector3(tail + 0.4, height * 0.42, 0.0)
	var hot := _metal(Color("2a2420"))
	hot.emission_enabled = true
	hot.emission = Color("e7b15a")
	hot.emission_energy_multiplier = 0.08
	bell.material_override = hot
	holder.add_child(bell)
	var nose := float(holder.get_meta("nose", 20.0))
	var span := maxf(nose - tail, 12.0)
	var spine := MeshInstance3D.new()
	spine.name = "Spine"
	spine.mesh = _bevel_box(Vector3(span * 0.72, 1.3, 1.5), 0.16)
	spine.position = Vector3((nose + tail) * 0.5, height * 1.08, 0.0)
	spine.material_override = _hull_mat(Color("14181c"))
	holder.add_child(spine)
	var fin_mesh := _bevel_box(Vector3(span * 0.22, 0.45, 2.6), 0.08)
	var fin_port := MeshInstance3D.new()
	fin_port.name = "FinPort"
	fin_port.mesh = fin_mesh
	fin_port.position = Vector3(tail * 0.35, height * 0.22, 3.4)
	fin_port.material_override = _hull_mat(Color("12161a"))
	holder.add_child(fin_port)
	var fin_stbd := MeshInstance3D.new()
	fin_stbd.name = "FinStbd"
	fin_stbd.mesh = fin_mesh
	fin_stbd.position = Vector3(tail * 0.35, height * 0.22, -3.4)
	fin_stbd.material_override = _hull_mat(Color("12161a"))
	holder.add_child(fin_stbd)
	var throat := MeshInstance3D.new()
	throat.name = "Throat"
	throat.mesh = _bell_mesh(4.8, 0.45, 1.35)
	throat.position = Vector3(tail - 0.2, height * 0.42, 0.0)
	var coke := _metal(Color("1a120e"))
	coke.emission_enabled = true
	coke.emission = Color("ffb15a")
	coke.emission_energy_multiplier = 0.35
	throat.material_override = coke
	holder.add_child(throat)
	var flank := maxf(height * 0.16, 2.4)
	for side in [1.0, -1.0]:
		var nozzle := MeshInstance3D.new()
		nozzle.name = "NozzleP" if side > 0.0 else "NozzleS"
		nozzle.mesh = _bell_mesh(5.0, 0.62, 1.45)
		nozzle.position = Vector3(tail + 0.6, height * 0.3, flank * side)
		var iron := _metal(Color("241c18"))
		iron.emission_enabled = true
		iron.emission = Color("c47a3a")
		iron.emission_energy_multiplier = 0.14
		nozzle.material_override = iron
		holder.add_child(nozzle)
	_nav_lamp(holder, "LampNose", Vector3(nose * 0.86, height * 0.62, 0.0), Color("d8fff6"), 1.05)
	_nav_lamp(holder, "LampPort", Vector3(tail * 0.55, height * 0.28, 2.1), Color("d4553a"), 0.75)
	_nav_lamp(holder, "LampStbd", Vector3(tail * 0.55, height * 0.28, -2.1), Color("7dcea0"), 0.75)
	var flame := MeshInstance3D.new()
	flame.name = "Exhaust"
	var reach := maxf(26.0, height * 1.7)
	flame.mesh = _plume_mesh(reach, 2.4)
	flame.position = Vector3(tail - 1.2, height * 0.42, 0.0)
	var burn := ShaderMaterial.new()
	burn.shader = _plume_shader
	burn.set_shader_parameter("albedo", Color(1.0, 0.62, 0.22, 0.8))
	burn.set_shader_parameter("core", 0.0)
	flame.material_override = burn
	flame.visible = false
	holder.add_child(flame)
	var core := MeshInstance3D.new()
	core.name = "ExhaustCore"
	var jet_len := reach * 0.55
	core.mesh = _plume_mesh(jet_len, 1.05)
	core.position = Vector3(tail - 1.2, height * 0.42, 0.0)
	var white := ShaderMaterial.new()
	white.shader = _plume_shader
	white.set_shader_parameter("albedo", Color(1.0, 0.94, 0.82, 0.9))
	white.set_shader_parameter("core", 1.0)
	core.material_override = white
	core.visible = false
	holder.add_child(core)


func _ship_holder(key: String) -> Node3D:
	_used["ship:" + key] = true
	if _ships.has(key):
		(_ships[key] as Node3D).visible = true
		return _ships[key]
	var node := Node3D.new()
	node.name = key
	add_child(node)
	_ships[key] = node
	return node


func _fill_ship(holder: Node3D, class_id: String, shapes: Array, layers: Array, sockets: Array = []) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.free()
	var geom := Silhouette.parts(class_id, shapes, layers)
	var ext: Vector2 = Silhouette.extent(geom)
	var height := clampf(maxf(ext.x, ext.y * 2.0) * 0.48, 14.0, 40.0)
	holder.set_meta("crown", height)
	holder.set_meta("tail", float(geom.tail))
	var nose := 0.0
	for point in geom.hull:
		nose = maxf(nose, point.x)
	holder.set_meta("nose", nose)
	var lower := height * 0.62
	var hull_mesh := _prism(geom.hull, lower)
	if hull_mesh != null:
		var plate := MeshInstance3D.new()
		plate.name = "Plate"
		plate.mesh = hull_mesh
		plate.material_override = _hull_mat(Color("888888"))
		holder.add_child(plate)
	var deck_poly := _inset_poly(geom.hull, 0.78)
	var deck_mesh := _prism(deck_poly, height * 0.48)
	if deck_mesh != null:
		var deck := MeshInstance3D.new()
		deck.name = "Deck"
		deck.mesh = deck_mesh
		deck.position.y = lower * 0.92
		deck.material_override = _hull_mat(Color("9a9a9a"))
		holder.add_child(deck)
	var extra_i := 0
	for extra in geom.extras:
		var extra_mesh := _prism(extra, height * 0.72)
		if extra_mesh == null:
			continue
		var trim := MeshInstance3D.new()
		trim.name = "Trim%d" % extra_i
		trim.mesh = extra_mesh
		trim.position.y = height * 0.2
		trim.material_override = _hull_mat(Color("cccccc"))
		holder.add_child(trim)
		extra_i += 1
	var circle_i := 0
	for circle in geom.circles:
		var ball := MeshInstance3D.new()
		ball.name = "TrimC%d" % circle_i
		var sphere := SphereMesh.new()
		var rad := float(circle.r)
		sphere.radius = rad
		sphere.height = rad * 2.0
		ball.mesh = sphere
		ball.position = Vector3(float(circle.x), height * 0.55, float(circle.y))
		ball.material_override = _hull_mat(Color("cccccc"))
		holder.add_child(ball)
		var band := MeshInstance3D.new()
		band.name = "TankBand%d" % circle_i
		var belt := TorusMesh.new()
		belt.inner_radius = rad * 0.9
		belt.outer_radius = rad * 1.08
		belt.rings = 16
		belt.ring_segments = 8
		band.mesh = belt
		band.position = ball.position
		band.material_override = _hull_mat(Color("5c564e"))
		holder.add_child(band)
		circle_i += 1
	_add_bridge(holder, class_id, height, float(geom.tail))
	_mount_roles(holder, class_id, shapes, height)
	_mount_sockets(holder, class_id, sockets)
	_dress_volume(holder, class_id, height)


func _weapon_sockets(module_ids: Array) -> Array:
	var known := ["gun_sponson", "heavy_turret", "laser_bank", "missile_rack", "point_defense", "stake_gun"]
	var out: Array = []
	for module_id in module_ids:
		var name := str(module_id)
		if known.has(name):
			out.append(name)
	return out


func _socket_at(holder: Node3D, class_id: String, socket_name: String) -> Vector3:
	var nose := float(holder.get_meta("nose", 40.0))
	var crown := float(holder.get_meta("crown", 16.0))
	if class_id == "anvil":
		match socket_name:
			"heavy_turret":
				return Vector3(2.0, crown * 1.08, 0.0)
			"missile_rack":
				return Vector3(-6.0, crown * 0.28, 24.0)
			"gun_sponson":
				return Vector3(8.0, crown * 0.42, 20.0)
			"laser_bank":
				return Vector3(nose * 0.35, crown * 0.22, 0.0)
			"point_defense":
				return Vector3(-nose * 0.2, crown * 0.7, -16.0)
			_:
				return Vector3(0.0, crown * 0.4, 12.0)
	if class_id == "kestrel":
		match socket_name:
			"gun_sponson":
				return Vector3(6.0, crown * 0.48, 13.0)
			"laser_bank":
				return Vector3(nose * 0.78, crown * 0.08, 0.0)
			"missile_rack":
				return Vector3(-4.0, crown * 0.32, 0.0)
			"heavy_turret":
				return Vector3(0.0, crown * 1.02, 0.0)
			"point_defense":
				return Vector3(-14.0, crown * 0.4, 8.0)
			_:
				return Vector3(nose * 0.2, crown * 0.3, 8.0)
	match socket_name:
		"gun_sponson":
			return Vector3(nose * 0.22, crown * 0.62, 7.4)
		"laser_bank":
			return Vector3(nose * 0.86, crown * 0.28, 0.0)
		"missile_rack":
			return Vector3(nose * 0.02, crown * 0.78, 0.0)
		"heavy_turret":
			return Vector3(-4.0, crown * 1.05, 0.0)
		"point_defense":
			return Vector3(-nose * 0.32, crown * 0.36, 5.5)
		_:
			return Vector3(nose * 0.12, crown * 0.3, -8.0)


func _mount_sockets(holder: Node3D, class_id: String, sockets: Array) -> void:
	for socket_name in sockets:
		var name := str(socket_name)
		var node := Node3D.new()
		node.name = name
		node.position = _socket_at(holder, class_id, name)
		holder.add_child(node)
		if name == "laser_bank":
			_build_laser(node, class_id)
		elif name == "missile_rack":
			_build_rack(node, class_id)
		elif name == "point_defense":
			_build_turret(node, 0.55, false)
		elif name == "heavy_turret":
			_build_turret(node, 1.35, true)
		else:
			_build_turret(node, 0.85, false)


func _build_turret(node: Node3D, scale: float, heavy: bool) -> void:
	var metal := Color("6a6560")
	var bore := Color("1a1e24")
	var drum := MeshInstance3D.new()
	drum.name = "Ring"
	var base := CylinderMesh.new()
	base.top_radius = 2.2 * scale
	base.bottom_radius = 2.8 * scale
	base.height = 1.4 * scale
	base.radial_segments = 14
	drum.mesh = base
	drum.material_override = _hull_mat(metal)
	node.add_child(drum)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var cap := BoxMesh.new()
	cap.size = Vector3(3.8, 1.5, 3.2) * scale
	head.mesh = cap
	head.position = Vector3(0.6 * scale, 1.15 * scale, 0.0)
	head.material_override = _hull_mat(metal.lightened(0.12))
	node.add_child(head)
	var length := 8.4 * scale if heavy else 6.2 * scale
	for side in [-1.0, 1.0]:
		var barrel := _tube(node, "Barrel%s" % ("P" if side > 0.0 else "S"), 0.38 * scale, length, Vector3(length * 0.55, 1.2 * scale, side * 0.85 * scale), "x", bore)
		_dress_barrel(barrel, length, 0.16 * scale, 0.28 * scale)
		var tip := MeshInstance3D.new()
		tip.name = "Heat%s" % ("P" if side > 0.0 else "S")
		var band := CylinderMesh.new()
		band.top_radius = 0.5 * scale
		band.bottom_radius = 0.5 * scale
		band.height = 0.7 * scale
		band.radial_segments = 10
		tip.mesh = band
		tip.position = Vector3(length * 0.42, 0.0, 0.0)
		tip.material_override = _hull_mat(Color("7a3e2c"))
		barrel.add_child(tip)
	if heavy:
		var feed := MeshInstance3D.new()
		feed.name = "Belt"
		var chute := BoxMesh.new()
		chute.size = Vector3(1.2, 2.4, 0.6) * scale
		feed.mesh = chute
		feed.position = Vector3(-0.4 * scale, 0.4 * scale, 1.6 * scale)
		feed.material_override = _hull_mat(Color("b08a3e"))
		node.add_child(feed)
	_nav_lamp(node, "Run", Vector3(-1.2 * scale, 1.6 * scale, 0.0), Color("9fd0c8"), 0.35 * scale)


func _build_laser(node: Node3D, class_id: String) -> void:
	var scale := 1.15 if class_id == "vesper" else 1.0
	var housing := MeshInstance3D.new()
	housing.name = "Housing"
	var box := BoxMesh.new()
	box.size = Vector3(9.0, 3.2, 4.6) * scale
	housing.mesh = box
	housing.material_override = _hull_mat(Color("2a2e33"))
	node.add_child(housing)
	_tube(node, "Coolant", 0.28 * scale, 8.0 * scale, Vector3(0.2 * scale, 1.8 * scale, 1.5 * scale), "x", Color("3d6f86"))
	_tube(node, "CoolantS", 0.28 * scale, 8.0 * scale, Vector3(0.2 * scale, 1.8 * scale, -1.5 * scale), "x", Color("3d6f86"))
	for side in [-1.0, 1.0]:
		var lens := MeshInstance3D.new()
		lens.name = "Lens%s" % ("P" if side > 0.0 else "S")
		var pane := BoxMesh.new()
		pane.size = Vector3(1.4, 2.4, 2.4) * scale
		lens.mesh = pane
		lens.position = Vector3(4.6 * scale, 0.2 * scale, side * 1.35 * scale)
		node.add_child(lens)
		_paint_bolt(lens, Color("ff7a1a"), 2.4, 0.92)
	var iris := MeshInstance3D.new()
	iris.name = "Iris"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.7 * scale
	ring.outer_radius = 1.15 * scale
	ring.rings = 12
	ring.ring_segments = 8
	iris.mesh = ring
	iris.position = Vector3(5.3 * scale, 0.2 * scale, 0.0)
	iris.rotation.z = PI * 0.5
	node.add_child(iris)
	_paint_bolt(iris, Color("ffd2a1"), 1.6, 0.85)


func _build_rack(node: Node3D, class_id: String) -> void:
	var scale := 1.45 if class_id == "anvil" else 1.0
	var bed := MeshInstance3D.new()
	bed.name = "Bed"
	var slab := BoxMesh.new()
	slab.size = Vector3(11.0, 1.6, 6.4) * scale
	bed.mesh = slab
	bed.material_override = _hull_mat(Color("5c584f"))
	node.add_child(bed)
	var door := MeshInstance3D.new()
	door.name = "Door"
	var lid := BoxMesh.new()
	lid.size = Vector3(0.45, 2.2, 5.6) * scale
	door.mesh = lid
	door.position = Vector3(5.4 * scale, 1.3 * scale, 0.0)
	door.material_override = _hull_mat(Color("3a3834"))
	node.add_child(door)
	var i := 0
	for row in [-1.0, 1.0]:
		for col in [-1.0, 1.0]:
			var tube := _tube(node, "Tube%d" % i, 0.72 * scale, 10.5 * scale, Vector3(0.4 * scale, 1.5 * scale + row * 0.95 * scale, col * 1.35 * scale), "x", Color("d5d0c6"))
			var mouth := MeshInstance3D.new()
			mouth.name = "Mouth"
			var ring := TorusMesh.new()
			ring.inner_radius = 0.42 * scale
			ring.outer_radius = 0.78 * scale
			ring.rings = 10
			ring.ring_segments = 6
			mouth.mesh = ring
			mouth.position = Vector3(5.1 * scale, 0.0, 0.0)
			mouth.rotation.z = PI * 0.5
			mouth.material_override = _hull_mat(Color("2a2420"))
			tube.add_child(mouth)
			i += 1
	var hose := _tube(node, "Hose", 0.22 * scale, 6.0 * scale, Vector3(-2.0 * scale, 0.2 * scale, 2.4 * scale), "x", Color("1c2024"))
	hose.rotation.y = 0.4
	_nav_lamp(node, "Seeker", Vector3(4.8 * scale, 2.4 * scale, 0.0), Color("9ecfff"), 0.28 * scale)


func _pose_sockets(holder: Node3D, ship: Dictionary) -> void:
	var bank := holder.get_node_or_null("laser_bank") as Node3D
	if bank != null:
		var iris := bank.get_node_or_null("Iris") as MeshInstance3D
		if iris != null:
			var open := bool(ship.get("lock_ok", false)) and float(ship.get("cap", 0.0)) > 8.0
			var gap := 1.0 if open else 0.42
			iris.scale = Vector3(gap, gap, 1.0)
	var rack := holder.get_node_or_null("missile_rack") as Node3D
	if rack != null:
		var door := rack.get_node_or_null("Door") as MeshInstance3D
		if door != null:
			var cd := float(ship.get("mount_cd", {}).get("missile_rack", 0.0))
			var shut := 0.0 if cd > 1.15 else 1.0
			door.position.y = door.position.y * 0.0 + (1.3 if shut > 0.5 else 2.6)
	var heavy := holder.get_node_or_null("heavy_turret") as Node3D
	if heavy != null:
		var belt := heavy.get_node_or_null("Belt") as MeshInstance3D
		if belt != null:
			var cd := float(ship.get("mount_cd", {}).get("heavy_turret", 0.0))
			belt.visible = cd > 0.45


func _signature_mount(class_id: String) -> Array:
	match class_id:
		"vesper":
			return ["sensor_mast"]
		"anvil":
			return ["cargo_blister"]
		"kestrel":
			return ["gun_sponson"]
		_:
			return []


func _mount_roles(holder: Node3D, class_id: String, shapes: Array, height: float) -> void:
	var nose := float(holder.get_meta("nose", 40.0))
	var y := height * 0.48
	if shapes.has("mast"):
		_mount_mast(holder, class_id, nose, y, height)
	if shapes.has("sponson"):
		_mount_guns(holder, class_id, y, height)
	if shapes.has("blister"):
		_mount_bay(holder, class_id, y, height)
	if shapes.has("probes"):
		_mount_probe(holder, class_id, nose, y, height)


func _mount_mast(holder: Node3D, class_id: String, nose: float, y: float, height: float) -> void:
	var metal := Color("c4b49a")
	var dish := Color("9fd0c8")
	if class_id == "anvil":
		_hardware(holder, "MountMastCollar", Vector3(10.0, 2.4, 10.0), Vector3(2.0, height * 0.86, 0.0), metal)
		var boom := _tube(holder, "MountMast", 1.5, 12.0, Vector3(2.0, height + 5.0, 0.0), "y", metal)
		_rib_along(boom, 3, 1.5, 12.0)
		_hardware(holder, "MastBox", Vector3(3.2, 1.1, 3.2), Vector3(2.0, height * 0.95, 0.0), metal.darkened(0.22))
		_lens(holder, "MountMastDish", 5.2, Vector3(2.0, height + 12.0, 0.0), dish)
	elif class_id == "kestrel":
		_hardware(holder, "MountMastCollar", Vector3(4.0, 1.6, 6.0), Vector3(2.0, y, 12.0), metal)
		var boom := _tube(holder, "MountMast", 0.55, 16.0, Vector3(10.0, y + 3.0, 18.0), "x", metal)
		boom.rotation = Vector3(0.4, 0.85, 0.1)
		_rib_along(boom, 4, 0.55, 16.0)
		_lens(holder, "MountMastDish", 2.6, Vector3(18.0, y + 6.0, 24.0), dish)
	else:
		_hardware(holder, "MountMastCollar", Vector3(7.0, 1.3, 2.2), Vector3(nose - 4.0, y, 0.0), metal)
		var boom := _tube(holder, "MountMast", 0.48, 16.0, Vector3(nose + 6.0, y + 0.4, 0.0), "x", metal)
		_rib_along(boom, 4, 0.48, 16.0)
		_tube(holder, "MastStay", 0.28, 15.0, Vector3(nose + 6.0, y - 0.85, 0.55), "x", metal.darkened(0.18))
		_hardware(holder, "MastBox", Vector3(2.6, 1.15, 1.8), Vector3(nose - 1.4, y + 0.15, 0.7), metal.darkened(0.28))
		_tube(holder, "MastLoom", 0.32, 12.0, Vector3(nose + 4.0, y - 0.35, 0.35), "x", Color("1c2024"))
		_lens(holder, "MountMastDish", 2.4, Vector3(nose + 15.0, y + 0.4, 0.0), dish)


func _mount_guns(holder: Node3D, class_id: String, y: float, _height: float) -> void:
	var metal := Color("8e8680")
	var bore := Color("1a1e24")
	if class_id == "anvil":
		_hardware(holder, "MountGunP", Vector3(11.0, 6.0, 8.0), Vector3(-4.0, y, 22.0), metal)
		_hardware(holder, "MountGunS", Vector3(11.0, 6.0, 8.0), Vector3(-4.0, y, -22.0), metal)
		_dress_barrel(_tube(holder, "MountBarrelP", 1.2, 7.0, Vector3(4.0, y, 22.0), "x", bore), 7.0, 0.72, 1.2)
		_dress_barrel(_tube(holder, "MountBarrelS", 1.2, 7.0, Vector3(4.0, y, -22.0), "x", bore), 7.0, 0.72, 1.2)
	elif class_id == "kestrel":
		var port := _tube(holder, "MountGunP", 0.62, 14.0, Vector3(4.0, y, 15.0), "x", bore)
		port.rotation.y = -0.7
		_dress_barrel(port, 14.0, 0.34, 0.72)
		var starboard := _tube(holder, "MountGunS", 0.62, 14.0, Vector3(4.0, y, -15.0), "x", bore)
		starboard.rotation.y = 0.7
		_dress_barrel(starboard, 14.0, 0.34, 0.72)
		_hardware(holder, "MountGunBracket", Vector3(3.2, 1.2, 8.0), Vector3(1.0, y, 0.0), metal)
		_hardware(holder, "GunFeedP", Vector3(3.4, 1.3, 1.6), Vector3(6.0, y + 0.4, 10.0), metal.darkened(0.15))
		_hardware(holder, "GunFeedS", Vector3(3.4, 1.3, 1.6), Vector3(6.0, y + 0.4, -10.0), metal.darkened(0.15))
	else:
		_hardware(holder, "MountGunP", Vector3(2.6, 1.3, 1.8), Vector3(10.0, y * 0.7, 6.2), metal)
		_hardware(holder, "MountGunS", Vector3(2.6, 1.3, 1.8), Vector3(10.0, y * 0.7, -6.2), metal)
		_dress_barrel(_tube(holder, "MountBarrelP", 0.36, 14.0, Vector3(18.0, y * 0.7, 6.2), "x", bore), 14.0, 0.2, 0.42)
		_dress_barrel(_tube(holder, "MountBarrelS", 0.36, 14.0, Vector3(18.0, y * 0.7, -6.2), "x", bore), 14.0, 0.2, 0.42)
		_hardware(holder, "GunFeedP", Vector3(2.4, 1.15, 1.3), Vector3(12.0, y * 0.7, 6.2), metal)
		_hardware(holder, "GunFeedS", Vector3(2.4, 1.15, 1.3), Vector3(12.0, y * 0.7, -6.2), metal)


func _mount_bay(holder: Node3D, class_id: String, y: float, height: float) -> void:
	var metal := Color("a89880")
	var door := Color("5c5348")
	if class_id == "anvil":
		var bay_at := Vector3(-6.0, height * 0.18, 0.0)
		var bay := _hardware(holder, "MountBay", Vector3(24.0, 8.0, 30.0), bay_at, metal)
		bay.mesh = _bevel_box(Vector3(24.0, 8.0, 30.0), 2.2)
		for i in 4:
			_hardware(holder, "BayRib%d" % i, Vector3(20.4, 0.36, 0.48), bay_at + Vector3(0.0, 4.12, -9.0 + float(i) * 6.0), door)
		_hardware(holder, "MountBayDoor", Vector3(1.6, 5.5, 18.0), Vector3(5.0, height * 0.22, 0.0), door)
		_hardware(holder, "BayHingeP", Vector3(0.45, 0.45, 16.5), Vector3(5.7, height * 0.22 + 2.5, 0.0), metal.darkened(0.2))
		_hardware(holder, "BayHingeS", Vector3(0.45, 0.45, 16.5), Vector3(5.7, height * 0.22 - 2.5, 0.0), metal.darkened(0.2))
		_nav_lamp(holder, "MountBayLamp", Vector3(4.2, height * 0.42, 0.0), Color("ffd27a"), 0.7)
	elif class_id == "kestrel":
		var port := _hardware(holder, "MountBay", Vector3(14.0, 2.8, 4.5), Vector3(-4.0, y * 0.65, 13.0), metal)
		port.rotation.y = 0.45
		var starboard := _hardware(holder, "MountBayS", Vector3(14.0, 2.8, 4.5), Vector3(-4.0, y * 0.65, -13.0), metal)
		starboard.rotation.y = -0.45
	else:
		_tube(holder, "MountBay", 2.4, 12.0, Vector3(-8.0, y * 0.5, 7.5), "x", metal)
		_tube(holder, "MountBayS", 2.4, 12.0, Vector3(-8.0, y * 0.5, -7.5), "x", metal)
		_hardware(holder, "MountBayStrap", Vector3(1.0, 0.8, 16.0), Vector3(-8.0, y * 0.5 + 2.0, 0.0), door)
		_hardware(holder, "BayLatchP", Vector3(0.9, 0.85, 3.6), Vector3(-2.2, y * 0.5 + 2.15, 7.5), door)
		_hardware(holder, "BayLatchS", Vector3(0.9, 0.85, 3.6), Vector3(-2.2, y * 0.5 + 2.15, -7.5), door)


func _mount_probe(holder: Node3D, class_id: String, nose: float, y: float, height: float) -> void:
	var metal := Color("b7c4c0")
	var dart := Color("d7e6c8")
	if class_id == "anvil":
		_tube(holder, "MountProbe", 1.5, 10.0, Vector3(-10.0, height * 0.78, 7.0), "y", metal)
		_tube(holder, "MountProbeS", 1.5, 10.0, Vector3(-10.0, height * 0.78, -7.0), "y", metal)
		_hardware(holder, "MountProbeBed", Vector3(7.0, 1.2, 16.0), Vector3(-10.0, height * 0.66, 0.0), dart)
	elif class_id == "kestrel":
		_hardware(holder, "MountProbeBed", Vector3(5.0, 1.3, 3.2), Vector3(nose * 0.42, height * 0.14, 0.0), metal)
		_tube(holder, "MountProbe", 0.85, 11.0, Vector3(nose * 0.55, height * 0.14, 0.0), "x", dart)
	else:
		_hardware(holder, "MountProbeBed", Vector3(16.0, 0.9, 1.8), Vector3(nose * 0.35, height * 0.78, 0.0), metal)
		_tube(holder, "MountProbe", 0.55, 8.0, Vector3(nose * 0.55, height * 0.9, 0.0), "x", dart)


func _hardware(holder: Node3D, part_name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = _bevel_box(size, 0.22)
	node.position = at
	node.material_override = _hull_mat(color)
	holder.add_child(node)
	return node


func _tube(holder: Node3D, part_name: String, radius: float, length: float, at: Vector3, axis: String, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 20
	cyl.rings = 1
	node.mesh = cyl
	node.position = at
	if axis == "x":
		node.rotation.z = PI * 0.5
	elif axis == "z":
		node.rotation.x = PI * 0.5
	node.material_override = _hull_mat(color)
	holder.add_child(node)
	return node


func _lens(holder: Node3D, part_name: String, radius: float, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = _dish_mesh(radius)
	node.position = at
	node.material_override = _hull_mat(Color(color.r, color.g, color.b).darkened(0.35))
	holder.add_child(node)
	var feed := MeshInstance3D.new()
	feed.name = "Feed"
	var horn := SphereMesh.new()
	horn.radius = radius * 0.16
	horn.height = radius * 0.32
	horn.radial_segments = 12
	horn.rings = 6
	feed.mesh = horn
	feed.position = Vector3(0.0, radius * 0.05, 0.0)
	feed.material_override = _hull_mat(Color("e7fff8"))
	node.add_child(feed)
	var lip := MeshInstance3D.new()
	lip.name = "Lip"
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.84
	torus.outer_radius = radius * 1.04
	torus.rings = 18
	torus.ring_segments = 8
	lip.mesh = torus
	lip.material_override = _hull_mat(Color("9a8e7c"))
	node.add_child(lip)


func _rib_along(barrel: MeshInstance3D, count: int, radius: float, length: float) -> void:
	if count < 2:
		return
	for i in count:
		var rib := MeshInstance3D.new()
		rib.name = "Rib%d" % i
		var ring := CylinderMesh.new()
		ring.top_radius = radius * 1.75
		ring.bottom_radius = radius * 1.75
		ring.height = maxf(length * 0.04, 0.18)
		ring.radial_segments = 14
		rib.mesh = ring
		var t := -0.36 + float(i) * (0.72 / float(count - 1))
		rib.position = Vector3(0.0, length * t, 0.0)
		rib.material_override = _hull_mat(Color("8a7e70"))
		barrel.add_child(rib)


func _dress_barrel(barrel: MeshInstance3D, length: float, bore: float, breech: float) -> void:
	var cyl := barrel.mesh as CylinderMesh
	if cyl != null:
		cyl.bottom_radius = breech
		cyl.top_radius = bore
	var muzzle := MeshInstance3D.new()
	muzzle.name = "Muzzle"
	var ring := CylinderMesh.new()
	ring.top_radius = bore * 1.45
	ring.bottom_radius = bore * 1.45
	ring.height = maxf(length * 0.07, 0.28)
	ring.radial_segments = 16
	muzzle.mesh = ring
	muzzle.position = Vector3(0.0, length * 0.46, 0.0)
	muzzle.material_override = _hull_mat(Color("241c18"))
	barrel.add_child(muzzle)
	var house := MeshInstance3D.new()
	house.name = "Breech"
	var block := CylinderMesh.new()
	block.top_radius = breech * 1.65
	block.bottom_radius = breech * 1.45
	block.height = maxf(length * 0.2, 0.7)
	block.radial_segments = 12
	house.mesh = block
	house.position = Vector3(0.0, -length * 0.36, 0.0)
	house.material_override = _hull_mat(Color("6a625c"))
	barrel.add_child(house)


func _dish_mesh(radius: float) -> ArrayMesh:
	var key := "dish|%0.2f" % radius
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rings := 8
	var segs := 18
	var depth := radius * 0.42
	var shell := 0.1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, -depth, 0.0)
	var center_back := Vector3(0.0, -depth - shell, 0.0)
	for s in segs:
		var a0 := TAU * float(s) / float(segs)
		var a1 := TAU * float(s + 1) / float(segs)
		var r1 := radius / float(rings)
		var y1 := -depth * (1.0 - 1.0 / float(rings * rings))
		var p0 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var p1 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		_out_tri(st, center, p0, p1, Vector3.UP)
		_out_tri(st, center_back, p1 + Vector3(0.0, -shell, 0.0), p0 + Vector3(0.0, -shell, 0.0), Vector3.DOWN)
	for i in range(1, rings):
		var u0 := float(i) / float(rings)
		var u1 := float(i + 1) / float(rings)
		var r0 := radius * u0
		var r1 := radius * u1
		var y0 := -depth * (1.0 - u0 * u0)
		var y1 := -depth * (1.0 - u1 * u1)
		for s in segs:
			var a0 := TAU * float(s) / float(segs)
			var a1 := TAU * float(s + 1) / float(segs)
			var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			_out_quad(st, p00, p01, p11, p10, Vector3.UP)
			_out_quad(st, p10 + Vector3(0.0, -shell, 0.0), p11 + Vector3(0.0, -shell, 0.0), p01 + Vector3(0.0, -shell, 0.0), p00 + Vector3(0.0, -shell, 0.0), Vector3.DOWN)
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


func _sync_craft(sim) -> void:
	var parked := 0
	var index := 0
	for item in sim.craft:
		var row: Dictionary = item
		var pos: Vector2 = row.pos
		var rot := float(row.rot)
		if int(sim.layer) == ScaleFrame.CHART and str(row.get("state", "")) != "docked":
			continue
		if str(row.get("state", "")) == "docked" and bool(sim.player.get("alive", false)):
			var side := Vector2.from_angle(float(sim.player.rot) + PI * 0.5)
			var back := Vector2.from_angle(float(sim.player.rot) + PI)
			pos = sim.player.pos + back * (34.0 + float(parked) * 16.0) + side * (18.0 if parked % 2 == 0 else -18.0)
			rot = float(sim.player.rot)
			parked += 1
		var key := "c%d" % index
		index += 1
		var kind := str(row.get("def_id", "fighter"))
		var holder := _craft_holder(key, kind)
		_banked(holder, pos, rot, 1.5)
		if Game.zoom > 0.9 and str(row.get("state", "")) != "docked":
			_tag(str(row.get("name", kind)), chart(pos + Vector2(14.0, 10.0), 8.0), Color("d7e6c8"), 12)


func _craft_holder(key: String, kind: String) -> Node3D:
	_used["craft:" + key] = true
	if _craft.has(key) and str((_craft[key] as Node).get_meta("kind", "")) == kind:
		(_craft[key] as Node3D).visible = true
		return _craft[key]
	if _craft.has(key):
		(_craft[key] as Node).queue_free()
	var node := Node3D.new()
	node.name = key
	node.set_meta("kind", kind)
	var poly := _craft_poly(kind)
	var mesh := _prism(poly, 4.6, 0.82)
	if mesh != null:
		var body := MeshInstance3D.new()
		body.name = "Plate"
		body.mesh = mesh
		body.material_override = _hull_mat(_craft_color(kind))
		node.add_child(body)
		var cap_mesh := _prism(_inset_poly(poly, 0.72), 2.2, 0.8)
		if cap_mesh != null:
			var cap := MeshInstance3D.new()
			cap.name = "Deck"
			cap.mesh = cap_mesh
			cap.position.y = 3.8
			cap.material_override = _hull_mat(_craft_color(kind).lightened(0.12))
			node.add_child(cap)
		var lamp := MeshInstance3D.new()
		lamp.name = "LampNose"
		var bulb := SphereMesh.new()
		bulb.radius = 0.55
		bulb.height = 1.1
		lamp.mesh = bulb
		lamp.position = Vector3(8.0, 4.2, 0.0)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("f2e2c4")
		glow.emission_enabled = true
		glow.emission = Color("f2e2c4")
		glow.emission_energy_multiplier = 1.4
		lamp.material_override = glow
		node.add_child(lamp)
		var canopy := MeshInstance3D.new()
		canopy.name = "Glass"
		var pane_mesh := BoxMesh.new()
		pane_mesh.size = Vector3(2.8, 0.9, 1.4)
		canopy.mesh = pane_mesh
		canopy.position = Vector3(2.4, 5.2, 0.0)
		var pane := ShaderMaterial.new()
		pane.shader = _glass_shader
		pane.set_shader_parameter("albedo", Color(0.55, 0.82, 0.86, 0.35))
		canopy.material_override = pane
		node.add_child(canopy)
		var nozzle := MeshInstance3D.new()
		nozzle.name = "Exhaust"
		nozzle.mesh = _plume_mesh(6.5, 0.7)
		nozzle.position = Vector3(-7.2, 2.2, 0.0)
		var burn := ShaderMaterial.new()
		burn.shader = _plume_shader
		burn.set_shader_parameter("albedo", Color(0.95, 0.62, 0.28, 0.45))
		burn.set_shader_parameter("core", 0.35)
		nozzle.material_override = burn
		node.add_child(nozzle)
	add_child(node)
	_craft[key] = node
	return node


func _craft_poly(kind: String) -> PackedVector2Array:
	match kind:
		"survey_probe":
			return PackedVector2Array([Vector2(12, 0), Vector2(2, 1.7), Vector2(-8, 1.2), Vector2(-8, -1.2), Vector2(2, -1.7)])
		"harvest_drone":
			return PackedVector2Array([Vector2(5.5, 4.6), Vector2(5.5, -4.6), Vector2(-5, -4), Vector2(-5, 4)])
		"salvage_tender":
			return PackedVector2Array([Vector2(8, 3), Vector2(3, 5.2), Vector2(-7.5, 4.4), Vector2(-7.5, -4.4), Vector2(3, -5.2), Vector2(8, -3)])
		"away_shuttle":
			return PackedVector2Array([Vector2(9, 0), Vector2(1.5, 4), Vector2(-6.5, 3.2), Vector2(-6.5, -3.2), Vector2(1.5, -4)])
		_:
			return PackedVector2Array([Vector2(11, 0), Vector2(1, 2), Vector2(-3.5, 6), Vector2(-1.2, 0), Vector2(-3.5, -6), Vector2(1, -2)])


func _craft_color(kind: String) -> Color:
	match kind:
		"survey_probe":
			return Color("9fd0c8")
		"harvest_drone":
			return Color("d2a15a")
		"salvage_tender":
			return Color("c47a4a")
		"away_shuttle":
			return Color("d7d2c4")
		_:
			return Color("c4512c")


func _sync_sky(sim) -> void:
	if _sky == null:
		_sky = MultiMeshInstance3D.new()
		_sky.name = "Sky"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var dot := SphereMesh.new()
		dot.radius = 1.0
		dot.height = 2.0
		dot.radial_segments = 6
		dot.rings = 4
		mm.mesh = dot
		_sky.multimesh = mm
		var sky_mat := ShaderMaterial.new()
		var twinkle := Shader.new()
		twinkle.code = "shader_type spatial; render_mode unshaded, cull_disabled; void fragment() { float tw = 0.42 + 0.58 * sin(TIME * (1.1 + COLOR.r * 2.8) + COLOR.g * 17.0); ALBEDO = COLOR.rgb * tw; EMISSION = COLOR.rgb * tw * 0.85; }"
		sky_mat.shader = twinkle
		_sky.material_override = sky_mat
		_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_sky)
	var mm := _sky.multimesh
	var count: int = sim.stars.size()
	if mm.instance_count != count:
		mm.instance_count = count
	var layer := int(sim.layer)
	var shell := 6400.0
	var star_scale := 0.012
	if layer == ScaleFrame.CHART:
		shell = 9000.0
		star_scale = 0.0014
	elif layer == ScaleFrame.APPROACH:
		shell = 36000.0
	elif layer == ScaleFrame.SITE:
		shell = 2200.0
	# Backdrop rides with the keel. A shell glued to world zero vanishes
	# once the band exit jumps into chart kilometers.
	var anchor := chart(sim.player.pos, 0.0)
	for i in count:
		var star: Dictionary = sim.stars[i]
		var p: Vector2 = star.pos
		var ang := p.angle()
		var u := clampf((p.length() - 200.0) / 9000.0, 0.0, 1.0)
		var elev := lerpf(-0.35, 1.15, float(star.a))
		var dir := Vector3(cos(ang) * cos(elev), sin(elev), -sin(ang) * cos(elev))
		if dir.length_squared() < 0.001:
			dir = Vector3.UP
		dir = dir.normalized()
		var radius := lerpf(shell * 0.55, shell, u)
		var scale := radius * star_scale * (0.55 + float(star.a))
		var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		mm.set_instance_transform(i, Transform3D(basis, anchor + dir * radius))
		var temp := float(star.a)
		var tint := Color(0.72, 0.8, 0.95) if temp < 0.4 else Color(0.95, 0.9, 0.78)
		if temp > 0.7:
			tint = Color(1.0, 0.82, 0.62)
		mm.set_instance_color(i, tint)


func _tag(text: String, at: Vector3, color: Color, size: int) -> void:
	tags.append({"t": text, "p": at, "c": color, "s": size})


func _hide_stale(pool: Dictionary) -> void:
	for key in pool.keys():
		var kind := "body"
		if pool == _ships:
			kind = "ship"
		elif pool == _craft:
			kind = "craft"
		elif pool == _props:
			kind = "prop"
		if _used.has(kind + ":" + str(key)) == false:
			(pool[key] as Node3D).visible = false


func _banked(holder: Node3D, pos: Vector2, rot: float, height: float, ship: Dictionary = {}) -> void:
	var prev := float(holder.get_meta("prev_rot", rot))
	var dyaw := wrapf(rot - prev, -PI, PI)
	holder.set_meta("prev_rot", rot)
	var rate := dyaw / _frame_delta
	# Positive sim yaw is a screen-left turn under the mirrored overhead
	# camera, and it drops local +Z. That side is the screen-left wing
	# when the nose points up the frame, so the visible right side rises
	# into a left turn and drops into a right turn.
	var want := clampf(rate * 0.22, -0.55, 0.55)
	var forward := Vector2.from_angle(rot)
	var right := Vector2(-forward.y, forward.x)
	var vel := Vector2(ship.get("vel", Vector2.ZERO))
	var slip := vel.dot(right)
	var strafe := float(ship.get("strafe_hold", 0.0))
	# Starboard slip and starboard strafe drop the screen-right wing.
	want -= clampf(slip / 240.0, -0.34, 0.34)
	want -= clampf(strafe, -1.0, 1.0) * 0.26
	want = clampf(want, -0.72, 0.72)
	var shown := float(holder.get_meta("bank", 0.0))
	shown = lerpf(shown, want, 1.0 - exp(-7.5 * _frame_delta))
	holder.set_meta("bank", shown)
	var boosting := bool(ship.get("boosting", false))
	var thrusting := bool(ship.get("thrusting", false)) or bool(holder.get_meta("thrusting", false))
	var retro := bool(ship.get("retro_hold", false))
	var want_pitch := 0.0
	if boosting:
		want_pitch = 0.42
	elif thrusting:
		want_pitch = 0.22
	if retro:
		want_pitch = -0.2
	var pitch := float(holder.get_meta("pitch", 0.0))
	pitch = lerpf(pitch, want_pitch, 1.0 - exp(-4.2 * _frame_delta))
	holder.set_meta("pitch", pitch)
	var bob := 0.0
	if boosting:
		bob = sin(Time.get_ticks_msec() * 0.022) * 0.55
	elif thrusting:
		bob = sin(Time.get_ticks_msec() * 0.014) * 0.16
	var xf := _flat_xform(pos, rot, height + bob)
	xf.basis = xf.basis * Basis(Vector3.RIGHT, shown) * Basis(Vector3(0.0, 0.0, 1.0), pitch)
	holder.transform = xf


func _place_wake(holder: Node3D, ship: Dictionary) -> void:
	var wake := holder.get_node_or_null("Wake") as MeshInstance3D
	if wake == null:
		wake = MeshInstance3D.new()
		wake.name = "Wake"
		wake.mesh = _wake_mesh()
		var mat := ShaderMaterial.new()
		mat.shader = _wake_shader
		mat.set_shader_parameter("albedo", Color(0.62, 0.78, 0.9, 0.4))
		wake.material_override = mat
		wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(wake)
	var vel: Vector2 = ship.get("vel", Vector2.ZERO)
	var speed := vel.length()
	if speed < 18.0:
		wake.visible = false
		return
	var forward := Vector2.from_angle(float(ship.rot))
	var right := Vector2(-forward.y, forward.x)
	var local := Vector2(vel.dot(forward), vel.dot(right))
	if local.length() < 1.0:
		wake.visible = false
		return
	var trail := -local.normalized()
	var boosting := bool(ship.get("boosting", false))
	var thrusting := bool(ship.get("thrusting", false))
	var reach := clampf(speed * 0.24, 18.0, 96.0)
	if boosting:
		reach *= 1.35
	var width := clampf(10.0 + speed * 0.018, 10.0, 22.0)
	wake.visible = true
	wake.position = Vector3(trail.x * 8.0, 0.7, trail.y * 8.0)
	wake.basis = Basis(Vector3.UP, atan2(trail.y, -trail.x)).scaled(Vector3(reach, 1.0, width))
	var mat := wake.material_override as ShaderMaterial
	if mat != null:
		var tint := Color(0.62, 0.78, 0.9, 0.34)
		if boosting:
			tint = Color(0.5, 0.8, 1.0, 0.48)
		elif thrusting:
			tint = Color(1.0, 0.58, 0.22, 0.4)
		mat.set_shader_parameter("albedo", tint)


func _place_plumes(holder: Node3D, ship: Dictionary) -> void:
	var thrusting := bool(ship.get("thrusting", false))
	var boosting := bool(ship.get("boosting", false))
	var strafe := float(ship.get("strafe_hold", 0.0))
	var retro := bool(ship.get("retro_hold", false))
	var t := Time.get_ticks_msec() * 0.001
	var burn := float(holder.get_meta("burn", 0.0))
	var burn_goal := 0.0
	if boosting:
		burn_goal = 1.0
	elif thrusting:
		burn_goal = 0.46
	var catch_up := 3.6 if burn_goal > burn else 2.1
	burn = move_toward(burn, burn_goal, catch_up * _frame_delta)
	holder.set_meta("burn", burn)
	var lit := burn > 0.04
	var flick := 0.72 + 0.28 * absf(sin(t * (42.0 if boosting else 24.0)))
	var forward := Vector2.from_angle(float(ship.get("rot", 0.0)))
	var vel := Vector2(ship.get("vel", Vector2.ZERO))
	var stretch := clampf(vel.dot(forward) / 340.0, 0.0, 1.35)
	var length := flick * lerpf(0.22, 3.15, burn) * lerpf(0.82, 1.18, clampf(stretch, 0.0, 1.0))
	var girth := lerpf(0.72, 2.15, burn) * (0.84 + 0.16 * flick)
	var tail := float(holder.get_meta("tail", -20.0))
	var crown := float(holder.get_meta("crown", 16.0))
	var sheath := Color(1.0, 0.48, 0.12, 0.88).lerp(Color(0.45, 0.78, 1.0, 0.92), smoothstep(0.5, 0.92, burn))
	var heart := Color(1.0, 0.9, 0.62, 0.92).lerp(Color(0.78, 0.92, 1.0, 0.96), smoothstep(0.5, 0.92, burn))
	var gimbal := -float(holder.get_meta("bank", 0.0)) * 5.5
	var exhaust := holder.get_node_or_null("Exhaust") as MeshInstance3D
	if exhaust != null:
		exhaust.visible = lit
		exhaust.position.z = gimbal
		exhaust.scale = Vector3(length, girth, girth)
		var sheath_mat := exhaust.material_override as ShaderMaterial
		if sheath_mat != null:
			sheath_mat.set_shader_parameter("albedo", sheath)
	var core := holder.get_node_or_null("ExhaustCore") as MeshInstance3D
	if core != null:
		core.visible = lit
		core.position.z = gimbal
		core.scale = Vector3(length * 0.92, girth * 0.72, girth * 0.72)
		var white := core.material_override as ShaderMaterial
		if white != null:
			white.set_shader_parameter("albedo", heart)
	var bloom := holder.get_node_or_null("ExhaustBloom") as MeshInstance3D
	if bloom == null and exhaust != null:
		bloom = MeshInstance3D.new()
		bloom.name = "ExhaustBloom"
		bloom.mesh = _plume_mesh(36.0, 7.4)
		bloom.position = exhaust.position
		var haze := ShaderMaterial.new()
		haze.shader = _plume_shader
		haze.set_shader_parameter("albedo", Color(0.4, 0.72, 1.0, 0.42))
		haze.set_shader_parameter("core", 0.0)
		bloom.material_override = haze
		bloom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(bloom)
	if bloom != null:
		bloom.visible = burn > 0.62
		bloom.position.z = gimbal
		if bloom.visible:
			bloom.scale = Vector3(length * 1.08, girth * 1.65, girth * 1.65)
			var haze := bloom.material_override as ShaderMaterial
			if haze != null:
				haze.set_shader_parameter("albedo", Color(0.35, 0.7, 1.0, 0.28 + 0.22 * burn))
	var flank := maxf(crown * 0.16, 2.4)
	_side_plume(holder, "JetPort", Vector3(tail + 0.4, crown * 0.3, flank), lit, strafe > 0.15, boosting, t)
	_side_plume(holder, "JetStbd", Vector3(tail + 0.4, crown * 0.3, -flank), lit, strafe < -0.15, boosting, t + 0.4)
	var nose := float(holder.get_meta("nose", 24.0))
	var brake := _side_plume(holder, "RetroJet", Vector3(nose * 0.9, crown * 0.34, 0.0), retro, retro, false, t + 0.8)
	if brake != null:
		brake.rotation = Vector3(0.0, PI, 0.0)
		if retro:
			brake.scale = Vector3(0.62 * flick, 0.55, 0.55)
	for nozzle_name in ["NozzleP", "NozzleS", "Throat"]:
		var nozzle := holder.get_node_or_null(nozzle_name) as MeshInstance3D
		if nozzle == null:
			continue
		var iron := nozzle.material_override as StandardMaterial3D
		if iron == null:
			continue
		var hot := 0.12
		if lit:
			hot = 0.85 + 0.35 * flick
		if boosting:
			hot = 1.5 + 0.4 * flick
		if nozzle_name == "NozzleP" and strafe > 0.15:
			hot = maxf(hot, 1.15)
		elif nozzle_name == "NozzleS" and strafe < -0.15:
			hot = maxf(hot, 1.15)
		iron.emission_energy_multiplier = hot


func _side_plume(holder: Node3D, plume_name: String, at: Vector3, idle: bool, hard: bool, boosting: bool, t: float) -> MeshInstance3D:
	var jet := holder.get_node_or_null(plume_name) as MeshInstance3D
	if jet == null:
		jet = MeshInstance3D.new()
		jet.name = plume_name
		jet.mesh = _plume_mesh(9.0, 0.85)
		var mat := ShaderMaterial.new()
		mat.shader = _plume_shader
		mat.set_shader_parameter("albedo", Color(1.0, 0.62, 0.22, 0.75))
		mat.set_shader_parameter("core", 0.35)
		jet.material_override = mat
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(jet)
	jet.position = at
	var show := idle or hard
	jet.visible = show
	if show == false:
		return jet
	var flick := 0.7 + 0.3 * absf(sin(t * 28.0))
	var length := 0.42 * flick
	if hard:
		length = 1.05 * flick
	if boosting and hard:
		length = 1.85 * flick
	var fat := 0.85 + 0.25 * flick
	if boosting and hard:
		fat = 1.15 + 0.3 * flick
	jet.scale = Vector3(length, fat, fat)
	if plume_name == "JetPort" and hard:
		jet.rotation = Vector3(0.0, PI * 0.5, 0.0)
	elif plume_name == "JetStbd" and hard:
		jet.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	elif plume_name != "RetroJet":
		jet.rotation = Vector3.ZERO
	var mat := jet.material_override as ShaderMaterial
	if mat != null:
		var tint := Color(0.7, 0.88, 1.0, 0.8) if boosting else Color(1.0, 0.58, 0.2, 0.75)
		mat.set_shader_parameter("albedo", tint)
	return jet


func _place_jet_light(holder: Node3D, ship: Dictionary) -> void:
	var thrusting := bool(ship.get("thrusting", false))
	var boosting := bool(ship.get("boosting", false))
	var lamp := holder.get_node_or_null("JetLight") as OmniLight3D
	if lamp == null:
		lamp = OmniLight3D.new()
		lamp.name = "JetLight"
		lamp.light_color = Color(1.0, 0.58, 0.24)
		lamp.light_energy = 0.85
		lamp.omni_range = 38.0
		lamp.shadow_enabled = false
		var tail := float(holder.get_meta("tail", -20.0))
		var crown := float(holder.get_meta("crown", 16.0))
		lamp.position = Vector3(tail, crown * 0.42, 0.0)
		holder.add_child(lamp)
	var burn := float(holder.get_meta("burn", 0.0))
	lamp.visible = burn > 0.04 or thrusting or boosting
	var cool := smoothstep(0.5, 0.92, burn)
	lamp.light_color = Color(1.0, 0.58, 0.24).lerp(Color(0.72, 0.88, 1.0), cool)
	var lit_floor := 0.35 if thrusting else 0.0
	lamp.light_energy = lerpf(0.85, 1.7, maxf(cool, lit_floor))
	lamp.omni_range = lerpf(38.0, 62.0, cool)


func _wake_mesh() -> ArrayMesh:
	if _mesh_cache.has("wake"):
		return _mesh_cache["wake"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := 0.5
	var tip := 0.06
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(0.0, 0.0, root))
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(Vector3(0.0, 0.0, -root))
	st.set_uv(Vector2(1.0, 0.85))
	st.add_vertex(Vector3(-1.0, 0.0, -tip))
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(0.0, 0.0, root))
	st.set_uv(Vector2(1.0, 0.85))
	st.add_vertex(Vector3(-1.0, 0.0, -tip))
	st.set_uv(Vector2(1.0, 0.15))
	st.add_vertex(Vector3(-1.0, 0.0, tip))
	var mesh := st.commit()
	_mesh_cache["wake"] = mesh
	return mesh


func _flat_xform(pos: Vector2, rot: float, height: float) -> Transform3D:
	var fwd := Vector2.from_angle(rot)
	var x_axis := Vector3(fwd.x, 0.0, -fwd.y)
	var z_axis := Vector3(-fwd.y, 0.0, -fwd.x)
	return Transform3D(Basis(x_axis, Vector3.UP, z_axis), chart(pos, height))


func _hull_part(part: String) -> bool:
	if part == "Plate" or part == "Deck" or part == "Keel" or part.begins_with("TrimC"):
		return true
	if part.begins_with("Panel") or part.begins_with("Vane") or part.begins_with("Rib") or part.begins_with("Cheek"):
		return true
	if part == "Collar" or part == "Frame" or part.begins_with("Skid") or part.begins_with("Chine"):
		return true
	if part.begins_with("Trim") and part.trim_prefix("Trim").is_valid_int():
		return true
	return false


func _paint_hull(node: Node, color: Color, accent: Color = Color(0, 0, 0, 0)) -> void:
	if node is MeshInstance3D == false:
		return
	var mat: Material = (node as MeshInstance3D).material_override
	if mat is ShaderMaterial:
		var shader_mat := mat as ShaderMaterial
		shader_mat.set_shader_parameter("albedo", color)
		if accent.a > 0.01:
			shader_mat.set_shader_parameter("accent", Color(accent.r, accent.g, accent.b, 1.0))


func _pad_strip(parent: Node3D, part_name: String, size: Vector3, at: Vector3) -> void:
	var bar := MeshInstance3D.new()
	bar.name = part_name
	var box := BoxMesh.new()
	box.size = size
	bar.mesh = box
	bar.position = at
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color("c9d7c4")
	paint.emission_enabled = true
	paint.emission = Color("9ee7c8")
	paint.emission_energy_multiplier = 0.4
	bar.material_override = paint
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bar)


func _pad_bollard(parent: Node3D, part_name: String, at: Vector3) -> void:
	var post := MeshInstance3D.new()
	post.name = part_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.8
	cyl.height = 4.2
	cyl.radial_segments = 10
	post.mesh = cyl
	post.position = at
	post.material_override = _hull_mat(Color("3e4448"))
	var cap := MeshInstance3D.new()
	cap.name = "Cap"
	var knob := SphereMesh.new()
	knob.radius = 0.72
	knob.height = 1.2
	knob.radial_segments = 12
	knob.rings = 6
	cap.mesh = knob
	cap.position = Vector3(0.0, 2.3, 0.0)
	cap.material_override = _hull_mat(Color("c9d7c4"))
	post.add_child(cap)
	parent.add_child(post)


func _canopy_mesh(length: float, width: float, height: float) -> ArrayMesh:
	var key := "canopy|%0.2f|%0.2f|%0.2f" % [length, width, height]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var x0 := -length * 0.5
	var x1 := length * 0.5
	var z0 := -width * 0.5
	var z1 := width * 0.5
	var y_back := height
	var y_front := height * 0.28
	var back_l := Vector3(x0, 0.0, z1)
	var back_r := Vector3(x0, 0.0, z0)
	var back_tl := Vector3(x0, y_back, z1)
	var back_tr := Vector3(x0, y_back, z0)
	var nose_l := Vector3(x1, 0.0, z1 * 0.72)
	var nose_r := Vector3(x1, 0.0, z0 * 0.72)
	var nose_tl := Vector3(x1, y_front, z1 * 0.72)
	var nose_tr := Vector3(x1, y_front, z0 * 0.72)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_canopy_quad(st, back_l, back_r, nose_r, nose_l)
	_canopy_quad(st, back_tl, nose_tl, nose_tr, back_tr)
	_canopy_quad(st, back_r, back_tr, nose_tr, nose_r)
	_canopy_quad(st, back_tl, back_l, nose_l, nose_tl)
	_canopy_quad(st, back_tr, back_r, back_l, back_tl)
	_canopy_quad(st, nose_l, nose_r, nose_tr, nose_tl)
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


func _canopy_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (b - a).cross(d - a)
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	normal = normal.normalized()
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(c)
	st.set_normal(normal)
	st.add_vertex(d)


func _hull_mat(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _hull_shader
	mat.set_shader_parameter("albedo", color)
	return mat


func _pulse_lamps(holder: Node3D) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_pulse_lamp(holder, "LampPort", 0.45 + 0.55 * maxf(sin(t * 3.2), 0.0))
	_pulse_lamp(holder, "LampStbd", 0.45 + 0.55 * maxf(sin(t * 3.2 + 2.2), 0.0))
	_pulse_lamp(holder, "LampNose", 0.7 + 0.3 * sin(t * 1.6))


func _pulse_lamp(holder: Node3D, lamp_name: String, energy: float) -> void:
	var lamp := holder.get_node_or_null(lamp_name) as MeshInstance3D
	if lamp == null:
		return
	var glow := lamp.material_override as StandardMaterial3D
	if glow == null:
		return
	glow.emission_energy_multiplier = energy * 2.4


func _nav_lamp(holder: Node3D, lamp_name: String, at: Vector3, color: Color, radius: float) -> void:
	var lamp := MeshInstance3D.new()
	lamp.name = lamp_name
	var bulb := SphereMesh.new()
	bulb.radius = radius
	bulb.height = radius * 2.0
	bulb.radial_segments = 10
	bulb.rings = 6
	lamp.mesh = bulb
	lamp.position = at
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 1.8
	lamp.material_override = glow
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(lamp)


func _port_slit(holder: Node3D, part_name: String, size: Vector3, at: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = part_name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.16, 0.24, 0.28)
	glow.emission_enabled = true
	glow.emission = Color(0.55, 0.82, 0.76)
	glow.emission_energy_multiplier = 0.7
	node.material_override = glow
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(node)


func _disc(radius: float, segs: int) -> ArrayMesh:
	var cached := "disc|%0.1f|%d" % [radius, segs]
	if _mesh_cache.has(cached):
		return _mesh_cache[cached]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := float(i) * TAU / float(segs)
		var a1 := float(i + 1) * TAU / float(segs)
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1.0, a0 / TAU))
		st.add_vertex(p0)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1.0, a1 / TAU))
		st.add_vertex(p1)
	var mesh := st.commit()
	_mesh_cache[cached] = mesh
	return mesh


func _inset_poly(poly: PackedVector2Array, scale: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	if poly.is_empty():
		return poly
	for point in poly:
		center += point
	center /= float(poly.size())
	var out := PackedVector2Array()
	for point in poly:
		out.append(center + (point - center) * scale)
	return out


func _bell_mesh(length: float, r_hull: float, r_mouth: float) -> ArrayMesh:
	var cached := "bell|%0.1f|%0.2f|%0.2f" % [length, r_hull, r_mouth]
	if _mesh_cache.has(cached):
		return _mesh_cache[cached]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 24
	for i in segs:
		var a0 := float(i) * TAU / float(segs)
		var a1 := float(i + 1) * TAU / float(segs)
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)
		var p0 := Vector3(0.0, c0 * r_hull, s0 * r_hull)
		var p1 := Vector3(0.0, c1 * r_hull, s1 * r_hull)
		var q0 := Vector3(-length, c0 * r_mouth, s0 * r_mouth)
		var q1 := Vector3(-length, c1 * r_mouth, s1 * r_mouth)
		var n0 := Vector3(-0.35, c0, s0).normalized()
		var n1 := Vector3(-0.35, c1, s1).normalized()
		st.set_normal(n0)
		st.add_vertex(p0)
		st.set_normal(n0)
		st.add_vertex(q0)
		st.set_normal(n1)
		st.add_vertex(q1)
		st.set_normal(n0)
		st.add_vertex(p0)
		st.set_normal(n1)
		st.add_vertex(q1)
		st.set_normal(n1)
		st.add_vertex(p1)
		var lip0 := Vector3(-length, c0 * r_mouth * 0.62, s0 * r_mouth * 0.62)
		var lip1 := Vector3(-length, c1 * r_mouth * 0.62, s1 * r_mouth * 0.62)
		st.set_normal(Vector3(-1.0, 0.0, 0.0))
		st.add_vertex(q0)
		st.set_normal(Vector3(-1.0, 0.0, 0.0))
		st.add_vertex(lip0)
		st.set_normal(Vector3(-1.0, 0.0, 0.0))
		st.add_vertex(lip1)
		st.set_normal(Vector3(-1.0, 0.0, 0.0))
		st.add_vertex(q0)
		st.set_normal(Vector3(-1.0, 0.0, 0.0))
		st.add_vertex(lip1)
		st.set_normal(Vector3(-1.0, 0.0, 0.0))
		st.add_vertex(q1)
	var mesh := st.commit()
	_mesh_cache[cached] = mesh
	return mesh


func _plume_mesh(length: float, radius: float) -> ArrayMesh:
	var cached := "plume|%0.1f|%0.2f" % [length, radius]
	if _mesh_cache.has(cached):
		return _mesh_cache[cached]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 12
	for i in segs:
		var a0 := float(i) * TAU / float(segs)
		var a1 := float(i + 1) * TAU / float(segs)
		var tip := radius * 0.15
		var p0 := Vector3(0.0, cos(a0) * radius, sin(a0) * radius)
		var p1 := Vector3(0.0, cos(a1) * radius, sin(a1) * radius)
		var q0 := Vector3(-length, cos(a0) * tip, sin(a0) * tip)
		var q1 := Vector3(-length, cos(a1) * tip, sin(a1) * tip)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p0)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(q0)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(q1)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p0)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(q1)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(p1)
	var mesh := st.commit()
	_mesh_cache[cached] = mesh
	return mesh


func _sync_band() -> void:
	if _band == null:
		_band = MultiMeshInstance3D.new()
		_band.name = "Band"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var dot := SphereMesh.new()
		dot.radius = 1.0
		dot.height = 2.0
		dot.radial_segments = 6
		dot.rings = 3
		mm.mesh = dot
		mm.instance_count = 180
		_band.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		_band.material_override = mat
		_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_band)
		for i in 180:
			var ang := float(i) / 180.0 * TAU
			var radius := 9800.0 + float(i % 5) * 420.0
			var lift := sin(ang * 3.0) * 480.0
			var scale := 1.6 + float(i % 4) * 0.45
			var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(cos(ang) * radius, lift, sin(ang) * radius)))
			var tint := Color(0.62, 0.7, 0.86) if i % 3 == 0 else Color(0.9, 0.84, 0.7)
			mm.set_instance_color(i, tint)


func _metal(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.62
	mat.roughness = 0.38
	return mat


func _rubble_mat(color: Color, seed: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _rubble_shader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("seed", seed)
	return mat


func _smooth_copy(mesh: Mesh) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.index()
	st.generate_normals()
	return st.commit()


func _rock_shader_mat(color: Color, seed: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _rock_shader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("seed", seed)
	return mat


func _rubble_mesh(seed: int, radius: float) -> ArrayMesh:
	var bucket := int(round(radius))
	var key := "rubble|%d|%d" % [posmod(seed, 13), bucket]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) + 91
	_add_crumple(st, rng, radius, Vector3.ZERO)
	_add_crumple(st, rng, radius * 0.7, Vector3(radius * 0.98, radius * 0.12, radius * 0.18))
	_add_crumple(st, rng, radius * 0.62, Vector3(-radius * 0.72, radius * 0.38, radius * 0.58))
	_add_crumple(st, rng, radius * 0.48, Vector3(radius * 0.12, radius * 0.78, -radius * 0.66))
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


func _add_crumple(st: SurfaceTool, rng: RandomNumberGenerator, radius: float, center: Vector3) -> void:
	var lat := 5
	var lon := 8
	var rads := PackedFloat32Array()
	rads.resize((lat + 1) * lon)
	var wobble := 0.0
	for yi in lat + 1:
		for xi in lon:
			wobble = 0.32 + rng.randf() * 1.05
			if (yi + xi) % 2 == 0:
				wobble *= 0.55
			rads[yi * lon + xi] = wobble
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var c := Vector3.ZERO
	var d := Vector3.ZERO
	var nrm := Vector3.UP
	for y0 in lat:
		for x0 in lon:
			a = center + _rock_vert(y0, x0, lat, lon, rads, radius)
			b = center + _rock_vert(y0, x0 + 1, lat, lon, rads, radius)
			c = center + _rock_vert(y0 + 1, x0 + 1, lat, lon, rads, radius)
			d = center + _rock_vert(y0 + 1, x0, lat, lon, rads, radius)
			nrm = (b - a).cross(d - a)
			if nrm.length_squared() < 0.0001:
				nrm = (a - center).normalized()
			_rock_tri(st, a, b, d, nrm.normalized())
			nrm = (c - b).cross(d - b)
			if nrm.length_squared() < 0.0001:
				nrm = (d - center).normalized()
			_rock_tri(st, b, c, d, nrm.normalized())


func _rock_mesh(seed: int, radius: float) -> ArrayMesh:
	var bucket := int(round(radius))
	var key := "rockvol|%d|%d" % [posmod(seed, 11), bucket]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lat := 9
	var lon := 14
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed) + 17
	var rads := PackedFloat32Array()
	rads.resize((lat + 1) * lon)
	var wobble := 0.0
	for yi in lat + 1:
		for xi in lon:
			wobble = 0.36 + rng.randf() * 1.05
			if (yi + xi) % 3 == 0:
				wobble *= 0.55
			if yi == 0 or yi == lat:
				wobble = 0.72 + rng.randf() * 0.2
			rads[yi * lon + xi] = wobble
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var c := Vector3.ZERO
	var d := Vector3.ZERO
	var nrm := Vector3.UP
	for y0 in lat:
		for x0 in lon:
			a = _rock_vert(y0, x0, lat, lon, rads, radius)
			b = _rock_vert(y0, x0 + 1, lat, lon, rads, radius)
			c = _rock_vert(y0 + 1, x0 + 1, lat, lon, rads, radius)
			d = _rock_vert(y0 + 1, x0, lat, lon, rads, radius)
			nrm = (b - a).cross(d - a)
			if nrm.length_squared() < 0.0001:
				nrm = a.normalized()
			_rock_tri(st, a, b, d, nrm.normalized())
			nrm = (c - b).cross(d - b)
			if nrm.length_squared() < 0.0001:
				nrm = d.normalized()
			_rock_tri(st, b, c, d, nrm.normalized())
	_add_rock_lobe(st, rng, radius * 0.62, Vector3(radius * 0.58, radius * 0.1, radius * 0.16))
	_add_rock_lobe(st, rng, radius * 0.5, Vector3(-radius * 0.34, radius * 0.2, radius * 0.52))
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


func _add_rock_lobe(st: SurfaceTool, rng: RandomNumberGenerator, radius: float, center: Vector3) -> void:
	var lat := 5
	var lon := 7
	var rads := PackedFloat32Array()
	rads.resize((lat + 1) * lon)
	var wobble := 0.0
	for yi in lat + 1:
		for xi in lon:
			wobble = 0.4 + rng.randf() * 0.95
			rads[yi * lon + xi] = wobble
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var c := Vector3.ZERO
	var d := Vector3.ZERO
	var nrm := Vector3.UP
	for y0 in lat:
		for x0 in lon:
			a = center + _rock_vert(y0, x0, lat, lon, rads, radius)
			b = center + _rock_vert(y0, x0 + 1, lat, lon, rads, radius)
			c = center + _rock_vert(y0 + 1, x0 + 1, lat, lon, rads, radius)
			d = center + _rock_vert(y0 + 1, x0, lat, lon, rads, radius)
			nrm = (b - a).cross(d - a)
			if nrm.length_squared() < 0.0001:
				nrm = (a - center).normalized()
			_rock_tri(st, a, b, d, nrm.normalized())
			nrm = (c - b).cross(d - b)
			if nrm.length_squared() < 0.0001:
				nrm = (d - center).normalized()
			_rock_tri(st, b, c, d, nrm.normalized())


func _rock_vert(y: int, x: int, lat: int, lon: int, rads: PackedFloat32Array, radius: float) -> Vector3:
	var yy := clampi(y, 0, lat)
	var xx := posmod(x, lon)
	var theta := float(yy) / float(lat) * PI
	var phi := float(xx) / float(lon) * TAU
	var wobble := rads[yy * lon + xx]
	var r := radius * wobble
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi)) * r


func _rock_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3) -> void:
	st.set_normal(nrm)
	st.add_vertex(a)
	st.set_normal(nrm)
	st.add_vertex(b)
	st.set_normal(nrm)
	st.add_vertex(c)


func _ice_sparks(ring: MeshInstance3D, mid: float, band: float) -> void:
	if ring.get_node_or_null("Floe") != null:
		return
	var old := ring.get_node_or_null("Sparks")
	if old != null:
		old.queue_free()
	var floe := Node3D.new()
	floe.name = "Floe"
	ring.add_child(floe)
	for chip_i in 18:
		var chip := MeshInstance3D.new()
		chip.name = "Ice%d" % chip_i
		var scale := band * (0.22 + float(chip_i % 6) * 0.06)
		chip.mesh = _smooth_copy(_rock_mesh(chip_i + 40, scale))
		var ang := float(chip_i) * TAU / 18.0 + float(chip_i * chip_i) * 0.017
		var rad := mid + sin(float(chip_i) * 2.3) * band * 0.32
		var lift := sin(float(chip_i) * 1.9) * band * 0.16
		chip.position = Vector3(cos(ang) * rad, lift, sin(ang) * rad)
		chip.rotation = Vector3(float(chip_i) * 0.47, ang, float(chip_i) * 0.23)
		var mat := ShaderMaterial.new()
		mat.shader = _ice_shader
		mat.set_shader_parameter("seed", float(chip_i) * 0.41 + 0.2)
		chip.material_override = mat
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		floe.add_child(chip)


func _dress_volume(holder: Node3D, class_id: String, height: float) -> void:
	var nose := float(holder.get_meta("nose", 40.0))
	var tail := float(holder.get_meta("tail", -16.0))
	var span := maxf(nose - tail, 12.0)
	var belly := MeshInstance3D.new()
	belly.name = "Keel"
	var ball := SphereMesh.new()
	ball.radius = height * 0.22
	ball.height = height * 0.36
	ball.radial_segments = 14
	ball.rings = 8
	belly.mesh = ball
	belly.position = Vector3(tail + span * 0.42, height * 0.16, 0.0)
	belly.scale = Vector3(span / maxf(ball.radius, 1.0) * 0.15, 0.48, 0.58)
	belly.material_override = _hull_mat(Color("7a8084"))
	holder.add_child(belly)
	var x := 0.0
	var z := 0.0
	for i in 5:
		var plate := MeshInstance3D.new()
		plate.name = "Panel%d" % i
		plate.mesh = _bevel_box(Vector3(span * 0.13, 0.85, maxf(height * 0.22, 3.2)), 0.12)
		x = tail + span * (0.16 + float(i) * 0.15)
		z = height * 0.2 if i % 2 == 0 else -height * 0.2
		plate.position = Vector3(x, height * 0.72, z)
		plate.material_override = _hull_mat(Color("8e9498"))
		holder.add_child(plate)
	if class_id == "anvil":
		_fairing(holder, "RibP", Vector3(span * 0.16, 1.1, 3.2), Vector3(tail + span * 0.4, height * 0.55, 8.0))
		_fairing(holder, "RibS", Vector3(span * 0.16, 1.1, 3.2), Vector3(tail + span * 0.4, height * 0.55, -8.0))
	elif class_id == "kestrel":
		var port := _fairing(holder, "CheekP", Vector3(span * 0.2, 0.7, 2.4), Vector3(tail + span * 0.55, height * 0.34, 6.5))
		port.rotation.y = -0.45
		var starboard := _fairing(holder, "CheekS", Vector3(span * 0.2, 0.7, 2.4), Vector3(tail + span * 0.55, height * 0.34, -6.5))
		starboard.rotation.y = 0.45
	else:
		_fairing(holder, "VaneP", Vector3(span * 0.22, 0.35, 0.7), Vector3(tail + span * 0.72, height * 0.78, 1.4))
		_fairing(holder, "VaneS", Vector3(span * 0.22, 0.35, 0.7), Vector3(tail + span * 0.72, height * 0.78, -1.4))
	_tube(holder, "Collar", maxf(height * 0.11, 1.5), 2.1, Vector3(tail + 1.6, height * 0.4, 0.0), "x", Color("5c6468"))
	var mid := (nose + tail) * 0.42
	var chine_z := maxf(height * 0.2, 2.8)
	_hardware(holder, "ChineP", Vector3(span * 0.62, 0.7, 1.15), Vector3(mid, height * 0.22, chine_z), Color("6a7278"))
	_hardware(holder, "ChineS", Vector3(span * 0.62, 0.7, 1.15), Vector3(mid, height * 0.22, -chine_z), Color("6a7278"))
	_hardware(holder, "SkidP", Vector3(span * 0.42, 0.55, 0.9), Vector3(mid, -0.35, maxf(height * 0.16, 2.2)), Color("4a5256"))
	_hardware(holder, "SkidS", Vector3(span * 0.42, 0.55, 0.9), Vector3(mid, -0.35, -maxf(height * 0.16, 2.2)), Color("4a5256"))
	for i in 3:
		var fin := _hardware(holder, "Rad%d" % i, Vector3(span * 0.07, 0.22, maxf(height * 0.28, 3.2)), Vector3(tail + span * (0.22 + float(i) * 0.16), height * 0.95, 0.0), Color("3a3330"))
		fin.rotation.x = 0.15 if i == 1 else -0.08
	var hatch_z := maxf(height * 0.22, 3.8)
	for i in 4:
		var at_x := tail + span * (0.24 + float(i) * 0.15)
		var side := 1.0 if i % 2 == 0 else -1.0
		_hardware(holder, "Hatch%d" % i, Vector3(span * 0.1, 0.7, hatch_z), Vector3(at_x, height * 0.96, side * hatch_z * 0.85), Color("24282c"))
		_hardware(holder, "HatchLip%d" % i, Vector3(span * 0.12, 0.28, hatch_z + 0.8), Vector3(at_x, height * 0.72, side * hatch_z * 0.85), Color("c4bfb4"))
		_port_slit(holder, "Slit%d" % i, Vector3(span * 0.045, 0.35, 1.5), Vector3(at_x, height * 1.02, side * hatch_z * 0.35))
	_hardware(holder, "ScoopP", Vector3(span * 0.14, maxf(height * 0.16, 2.4), 2.2), Vector3(mid, height * 0.34, chine_z + 1.8), Color("2a3034"))
	_hardware(holder, "ScoopS", Vector3(span * 0.14, maxf(height * 0.16, 2.4), 2.2), Vector3(mid, height * 0.34, -chine_z - 1.8), Color("2a3034"))
	_tube(holder, "Loom", 0.28, span * 0.55, Vector3(tail + span * 0.42, height * 0.55, chine_z * 0.55), "x", Color("17191c"))
	_tube(holder, "LoomS", 0.28, span * 0.55, Vector3(tail + span * 0.42, height * 0.55, -chine_z * 0.55), "x", Color("17191c"))
	for i in 3:
		var ax := tail + span * (0.36 + float(i) * 0.12)
		_tube(holder, "Antenna%d" % i, 0.16, 3.6 + float(i) * 1.6, Vector3(ax, height * 1.2 + 1.8, 0.0), "y", Color("1a1e22"))
	_nav_lamp(holder, "RunP", Vector3(mid + span * 0.12, height * 0.42, chine_z + 1.1), Color("d4553a"), 0.72)
	_nav_lamp(holder, "RunS", Vector3(mid + span * 0.12, height * 0.42, -chine_z - 1.1), Color("7dcea0"), 0.72)


func _fairing(holder: Node3D, part_name: String, size: Vector3, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = _bevel_box(size, 0.16)
	node.position = at
	node.material_override = _hull_mat(Color("9aa0a6"))
	holder.add_child(node)
	return node


func _bevel_box(size: Vector3, cut: float) -> ArrayMesh:
	var key := "bevel|%0.2f|%0.2f|%0.2f|%0.2f" % [size.x, size.y, size.z, cut]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var c := minf(maxf(cut, 0.02), minf(hx, minf(hy, hz)) * 0.55)
	var ix := hx - c
	var iy := hy - c
	var iz := hz - c
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_out_quad(st, Vector3(-ix, hy, -iz), Vector3(ix, hy, -iz), Vector3(ix, hy, iz), Vector3(-ix, hy, iz), Vector3.UP)
	_out_quad(st, Vector3(-ix, -hy, iz), Vector3(ix, -hy, iz), Vector3(ix, -hy, -iz), Vector3(-ix, -hy, -iz), Vector3.DOWN)
	_out_quad(st, Vector3(hx, -iy, -iz), Vector3(hx, iy, -iz), Vector3(hx, iy, iz), Vector3(hx, -iy, iz), Vector3.RIGHT)
	_out_quad(st, Vector3(-hx, -iy, iz), Vector3(-hx, iy, iz), Vector3(-hx, iy, -iz), Vector3(-hx, -iy, -iz), Vector3.LEFT)
	_out_quad(st, Vector3(-ix, -iy, hz), Vector3(ix, -iy, hz), Vector3(ix, iy, hz), Vector3(-ix, iy, hz), Vector3(0, 0, 1))
	_out_quad(st, Vector3(ix, -iy, -hz), Vector3(-ix, -iy, -hz), Vector3(-ix, iy, -hz), Vector3(ix, iy, -hz), Vector3(0, 0, -1))
	_out_quad(st, Vector3(ix, hy, -iz), Vector3(hx, iy, -iz), Vector3(hx, iy, iz), Vector3(ix, hy, iz), Vector3(1, 1, 0))
	_out_quad(st, Vector3(-hx, iy, -iz), Vector3(-ix, hy, -iz), Vector3(-ix, hy, iz), Vector3(-hx, iy, iz), Vector3(-1, 1, 0))
	_out_quad(st, Vector3(-ix, hy, iz), Vector3(ix, hy, iz), Vector3(ix, iy, hz), Vector3(-ix, iy, hz), Vector3(0, 1, 1))
	_out_quad(st, Vector3(ix, hy, -iz), Vector3(-ix, hy, -iz), Vector3(-ix, iy, -hz), Vector3(ix, iy, -hz), Vector3(0, 1, -1))
	_out_quad(st, Vector3(hx, -iy, -iz), Vector3(ix, -hy, -iz), Vector3(ix, -hy, iz), Vector3(hx, -iy, iz), Vector3(1, -1, 0))
	_out_quad(st, Vector3(-ix, -hy, -iz), Vector3(-hx, -iy, -iz), Vector3(-hx, -iy, iz), Vector3(-ix, -hy, iz), Vector3(-1, -1, 0))
	_out_quad(st, Vector3(-ix, -iy, hz), Vector3(ix, -iy, hz), Vector3(ix, -hy, iz), Vector3(-ix, -hy, iz), Vector3(0, -1, 1))
	_out_quad(st, Vector3(ix, -iy, -hz), Vector3(-ix, -iy, -hz), Vector3(-ix, -hy, -iz), Vector3(ix, -hy, -iz), Vector3(0, -1, -1))
	_out_quad(st, Vector3(hx, -iy, iz), Vector3(hx, iy, iz), Vector3(ix, iy, hz), Vector3(ix, -iy, hz), Vector3(1, 0, 1))
	_out_quad(st, Vector3(ix, -iy, -hz), Vector3(ix, iy, -hz), Vector3(hx, iy, -iz), Vector3(hx, -iy, -iz), Vector3(1, 0, -1))
	_out_quad(st, Vector3(-hx, -iy, -iz), Vector3(-hx, iy, -iz), Vector3(-ix, iy, -hz), Vector3(-ix, -iy, -hz), Vector3(-1, 0, -1))
	_out_quad(st, Vector3(-ix, -iy, hz), Vector3(-ix, iy, hz), Vector3(-hx, iy, iz), Vector3(-hx, -iy, iz), Vector3(-1, 0, 1))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_out_tri(st, Vector3(sx * ix, sy * hy, sz * iz), Vector3(sx * hx, sy * iy, sz * iz), Vector3(sx * ix, sy * iy, sz * hz), Vector3(sx, sy, sz))
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


func _out_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var n := (b - a).cross(d - a)
	if n.dot(outward) < 0.0:
		var swap := b
		b = d
		d = swap
		n = -n
	if n.length_squared() < 0.000001:
		return
	n = n.normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(c)
	st.set_normal(n)
	st.add_vertex(d)


func _out_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(outward) < 0.0:
		var swap := b
		b = c
		c = swap
		n = -n
	if n.length_squared() < 0.000001:
		return
	n = n.normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


func _chamfer_poly(poly: PackedVector2Array, cut: float) -> PackedVector2Array:
	var count := poly.size()
	if count < 3 or cut <= 0.05:
		return poly
	var out := PackedVector2Array()
	for i in count:
		var prev: Vector2 = poly[(i + count - 1) % count]
		var cur: Vector2 = poly[i]
		var nxt: Vector2 = poly[(i + 1) % count]
		var to_prev := prev - cur
		var to_next := nxt - cur
		var prev_len := to_prev.length()
		var next_len := to_next.length()
		if prev_len < 0.05 or next_len < 0.05:
			out.append(cur)
			continue
		var bite := minf(cut, minf(prev_len, next_len) * 0.32)
		out.append(cur + to_prev * (bite / prev_len))
		out.append(cur + to_next * (bite / next_len))
	return out


func _round_poly(poly: PackedVector2Array) -> PackedVector2Array:
	var count := poly.size()
	if count < 4:
		return poly
	var out := PackedVector2Array()
	for i in count:
		var cur: Vector2 = poly[i]
		var nxt: Vector2 = poly[(i + 1) % count]
		out.append(cur * 0.75 + nxt * 0.25)
		out.append(cur * 0.25 + nxt * 0.75)
	return out


func _prism(poly: PackedVector2Array, height: float, top_scale: float = 0.86) -> ArrayMesh:
	if poly.size() < 3:
		return null
	poly = _round_poly(poly)
	if poly.size() <= 20:
		poly = _round_poly(poly)
	var edge := 0.0
	for i in poly.size():
		edge += poly[i].distance_to(poly[(i + 1) % poly.size()])
	edge /= float(poly.size())
	var raw := poly
	poly = _chamfer_poly(poly, clampf(edge * 0.22, 0.35, 7.0))
	var indices := Geometry2D.triangulate_polygon(poly)
	if indices.size() < 3:
		poly = raw
		indices = Geometry2D.triangulate_polygon(poly)
	if indices.size() < 3:
		return null
	var bilge := _inset_poly(poly, 0.58)
	var lower := _inset_poly(poly, 0.86)
	var shoulder := _inset_poly(poly, 0.93)
	var crown := _inset_poly(poly, top_scale)
	var y_low := height * 0.16
	var y_chine := height * 0.4
	var y_shoulder := height * 0.7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, indices.size(), 3):
		_tri(st, crown[indices[t]], crown[indices[t + 1]], crown[indices[t + 2]], height, Vector3.UP)
		_tri(st, bilge[indices[t]], bilge[indices[t + 2]], bilge[indices[t + 1]], 0.0, Vector3.DOWN)
	_girdle(st, bilge, lower, 0.0, y_low, height)
	_girdle(st, lower, poly, y_low, y_chine, height)
	_girdle(st, poly, shoulder, y_chine, y_shoulder, height)
	_girdle(st, shoulder, crown, y_shoulder, height, height)
	return st.commit()


func _girdle(st: SurfaceTool, lower: PackedVector2Array, upper: PackedVector2Array, y0: float, y1: float, span: float) -> void:
	var count := lower.size()
	if upper.size() != count or count < 2:
		return
	var centroid := Vector2.ZERO
	for point in lower:
		centroid += point
	centroid /= float(count)
	for i in count:
		var a: Vector2 = lower[i]
		var b: Vector2 = lower[(i + 1) % count]
		var edge := b - a
		var outward := Vector2(edge.y, -edge.x)
		if outward.dot(a - centroid) < 0.0:
			outward = -outward
		if outward.length_squared() < 0.0001:
			continue
		_slope(st, a, b, upper[i], upper[(i + 1) % count], y0, y1, centroid, span)


func _skin_normal(point: Vector2, y: float, span: float, centroid: Vector2) -> Vector3:
	var flat := point - centroid
	if flat.length_squared() < 0.04:
		flat = Vector2(1.0, 0.0)
	else:
		flat = flat.normalized()
	var lift := (y / maxf(span, 0.1) - 0.32) * 1.85
	var n := Vector3(flat.x, lift, flat.y)
	var deck := clampf((y - span * 0.72) / maxf(span * 0.28, 0.1), 0.0, 1.0)
	n = n.lerp(Vector3.UP, deck * 0.65)
	var belly := clampf((span * 0.18 - y) / maxf(span * 0.18, 0.1), 0.0, 1.0)
	n = n.lerp(Vector3.DOWN, belly * 0.45)
	return n.normalized()


func _slope(st: SurfaceTool, a: Vector2, b: Vector2, ta: Vector2, tb: Vector2, y0: float, y1: float, centroid: Vector2, span: float) -> void:
	st.set_normal(_skin_normal(a, y0, span, centroid))
	st.add_vertex(Vector3(a.x, y0, a.y))
	st.set_normal(_skin_normal(b, y0, span, centroid))
	st.add_vertex(Vector3(b.x, y0, b.y))
	st.set_normal(_skin_normal(tb, y1, span, centroid))
	st.add_vertex(Vector3(tb.x, y1, tb.y))
	st.set_normal(_skin_normal(a, y0, span, centroid))
	st.add_vertex(Vector3(a.x, y0, a.y))
	st.set_normal(_skin_normal(tb, y1, span, centroid))
	st.add_vertex(Vector3(tb.x, y1, tb.y))
	st.set_normal(_skin_normal(ta, y1, span, centroid))
	st.add_vertex(Vector3(ta.x, y1, ta.y))


func _tri(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, y: float, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, y, a.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(b.x, y, b.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(c.x, y, c.y))


func _wall(st: SurfaceTool, a: Vector2, b: Vector2, height: float, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, 0.0, a.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(b.x, 0.0, b.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(b.x, height, b.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, 0.0, a.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(b.x, height, b.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, height, a.y))


func _annulus(inner_r: float, outer_r: float, height: float, segs: int) -> ArrayMesh:
	var cached := "%0.1f|%0.1f|%0.2f" % [inner_r, outer_r, height]
	if _mesh_cache.has(cached):
		return _mesh_cache[cached]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := height * 0.5
	for i in segs:
		var a0 := float(i) * TAU / float(segs)
		var a1 := float(i + 1) * TAU / float(segs)
		var i0 := Vector3(cos(a0) * inner_r, 0.0, sin(a0) * inner_r)
		var o0 := Vector3(cos(a0) * outer_r, 0.0, sin(a0) * outer_r)
		var i1 := Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		var o1 := Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		var uv_i0 := Vector2(0.0, a0 / TAU)
		var uv_o0 := Vector2(1.0, a0 / TAU)
		var uv_i1 := Vector2(0.0, a1 / TAU)
		var uv_o1 := Vector2(1.0, a1 / TAU)
		_quad(st, i0 + Vector3.UP * half, o0 + Vector3.UP * half, o1 + Vector3.UP * half, i1 + Vector3.UP * half, Vector3.UP, uv_i0, uv_o0, uv_o1, uv_i1)
		_quad(st, i1 - Vector3.UP * half, o1 - Vector3.UP * half, o0 - Vector3.UP * half, i0 - Vector3.UP * half, Vector3.DOWN, uv_i1, uv_o1, uv_o0, uv_i0)
	var mesh := st.commit()
	_mesh_cache[cached] = mesh
	return mesh


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2) -> void:
	st.set_normal(normal)
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_normal(normal)
	st.set_uv(uv_c)
	st.add_vertex(c)
	st.set_normal(normal)
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_uv(uv_c)
	st.add_vertex(c)
	st.set_normal(normal)
	st.set_uv(uv_d)
	st.add_vertex(d)


func pose_portrait(class_id: String, module_ids: Array) -> Node3D:
	var shapes: Array = Silhouette.shapes_of(Game.defs, module_ids)
	var layers: Array = Silhouette.layers_of(Game.defs, module_ids)
	var holder := _ship_holder("portrait")
	var mesh_key := class_id + "|" + str(shapes) + "|" + str(layers.size())
	if str(holder.get_meta("mesh_key", "")) != mesh_key:
		_fill_ship(holder, class_id, shapes, layers)
		holder.set_meta("mesh_key", mesh_key)
	holder.set_meta("portrait_modules", module_ids.duplicate())
	if Game.defs.ships.has(class_id):
		var hull: Dictionary = Game.defs.ships[class_id]
		var body := Color(str(hull.color))
		var accent := Color(str(hull.accent))
		for child in holder.get_children():
			var part := str(child.name)
			if _hull_part(part):
				var tone := body
				if part == "Deck":
					tone = body.lightened(0.16)
				elif part.begins_with("Trim"):
					tone = accent
				_paint_hull(child, tone, accent)
	holder.position = Vector3.ZERO
	holder.rotation = Vector3(0.42, -0.62, 0.08)
	holder.scale = Vector3.ONE
	holder.visible = true
	return holder


func show_yard(class_id: String, hero: bool) -> void:
	menu_show = true
	visible = true
	scale = Vector3.ONE
	position = Vector3.ZERO
	if class_id != "":
		menu_class = class_id
	menu_hero = hero


func dismiss_yard() -> void:
	menu_show = false
	menu_hero = false
	visible = false
	# Collapsing the rig hides it even when a shared world ignores the
	# viewport split and the flight eye is the one drawing the pad.
	scale = Vector3.ZERO
	position = Vector3(0.0, -100000.0, 0.0)
	var holder := _ships.get("yard") as Node3D
	if holder != null:
		holder.visible = false
	var planet := _bodies.get("yard_aegis") as Node3D
	if planet != null:
		planet.visible = false
	for key in ["yard_dock", "yard_pylon0", "yard_pylon1", "yard_pylon2", "yard_pylon3", "yard_pylon4"]:
		var prop := _props.get(key) as Node3D
		if prop != null:
			prop.visible = false
	for node_name in ["YardSpokes", "Star", "Corona", "YardStars", "YardKey", "YardRim", "YardFill"]:
		var rig := get_node_or_null(node_name) as Node3D
		if rig != null:
			rig.visible = false


func _step_yard(delta: float) -> void:
	_yard_t += delta
	if _grid != null:
		_grid.visible = false
	if _yard_ready == false:
		_build_yard()
		_yard_ready = true
	_dress_yard()


func _build_yard() -> void:
	var planet := _body_node("yard_aegis")
	planet.position = Vector3(980.0, -120.0, -70.0)
	var radius := 680.0
	var ball := planet.get_node("Ball") as MeshInstance3D
	(ball.mesh as SphereMesh).radius = radius
	(ball.mesh as SphereMesh).height = radius * 2.0
	var air := planet.get_node("Air") as MeshInstance3D
	(air.mesh as SphereMesh).radius = radius * 1.012
	(air.mesh as SphereMesh).height = radius * 2.024
	var clouds := planet.get_node("Clouds") as MeshInstance3D
	clouds.visible = true
	(clouds.mesh as SphereMesh).radius = radius * 1.018
	(clouds.mesh as SphereMesh).height = radius * 2.036
	var to_star := Vector3(-0.86, 0.46, -0.2).normalized()
	var mat := ball.material_override as ShaderMaterial
	var albedo := Color("6e8f86")
	var land := Color("8d9a78")
	mat.set_shader_parameter("albedo", albedo)
	mat.set_shader_parameter("land", land)
	mat.set_shader_parameter("to_star", to_star)
	mat.set_shader_parameter("seed", 1.7)
	mat.set_shader_parameter("city", 1.0)
	var cloud_mat := clouds.material_override as ShaderMaterial
	cloud_mat.set_shader_parameter("to_star", to_star)
	cloud_mat.set_shader_parameter("seed", 1.7)
	var air_mat := air.material_override as ShaderMaterial
	air_mat.set_shader_parameter("to_star", to_star)
	air_mat.set_shader_parameter("tint", albedo.lerp(Color(0.55, 0.78, 0.88), 0.55))
	_sync_ring(planet, {"ring": true, "ring_kind": "ice"}, radius, to_star)
	_parallax(planet, radius, 0.0, true)
	if _star_mesh == null:
		_star_mesh = MeshInstance3D.new()
		_star_mesh.name = "Star"
		var core_mesh := SphereMesh.new()
		core_mesh.radial_segments = 48
		core_mesh.rings = 24
		core_mesh.radius = 78.0
		core_mesh.height = 156.0
		_star_mesh.mesh = core_mesh
		var star_mat := ShaderMaterial.new()
		star_mat.shader = _star_shader
		star_mat.set_shader_parameter("albedo", Color("ffd7a2"))
		_star_mesh.material_override = star_mat
		_star_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_star_mesh)
		_star_glow = MeshInstance3D.new()
		_star_glow.name = "Corona"
		var haze := SphereMesh.new()
		haze.radial_segments = 32
		haze.rings = 16
		haze.radius = 130.0
		haze.height = 260.0
		_star_glow.mesh = haze
		var glow := ShaderMaterial.new()
		glow.shader = _corona_shader
		glow.set_shader_parameter("albedo", Color("f0b56a"))
		_star_glow.material_override = glow
		_star_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_star_glow)
	_star_mesh.position = Vector3(60.0, 460.0, -280.0)
	_star_glow.position = _star_mesh.position
	(_star_mesh.mesh as SphereMesh).radius = 110.0
	(_star_mesh.mesh as SphereMesh).height = 220.0
	(_star_glow.mesh as SphereMesh).radius = 190.0
	(_star_glow.mesh as SphereMesh).height = 380.0
	_star_mesh.visible = true
	_star_glow.visible = true
	if _star_far != null:
		_star_far.visible = false
	if _star_rays != null:
		_star_rays.visible = false
	var spokes := get_node_or_null("YardSpokes") as MeshInstance3D
	if spokes == null:
		spokes = MeshInstance3D.new()
		spokes.name = "YardSpokes"
		var card := QuadMesh.new()
		card.orientation = PlaneMesh.FACE_Z
		card.size = Vector2(110.0 * 5.2, 110.0 * 5.2)
		spokes.mesh = card
		var rays := ShaderMaterial.new()
		rays.shader = _ray_shader
		rays.render_priority = 2
		rays.set_shader_parameter("albedo", Color("ffd7a2"))
		spokes.material_override = rays
		spokes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spokes)
	spokes.position = _star_mesh.position
	spokes.visible = true
	var ring := _prop("yard_dock")
	if str(ring.get_meta("built", "")) != "yes":
		var torus := TorusMesh.new()
		torus.inner_radius = 22.0
		torus.outer_radius = 38.0
		torus.rings = 48
		torus.ring_segments = 12
		ring.mesh = torus
		var wash := StandardMaterial3D.new()
		wash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wash.albedo_color = Color("d7fbff")
		wash.emission_enabled = true
		wash.emission = Color("7ee7f2")
		ring.material_override = wash
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.set_meta("built", "yes")
	ring.position = Vector3(299.0, 40.0, 227.0)
	ring.rotation = Vector3(1.2, 0.35, 0.15)
	for i in 5:
		var pylon := _prop("yard_pylon%d" % i)
		if pylon.mesh == null:
			var box := BoxMesh.new()
			box.size = Vector3(3.2, 16.0 + float(i) * 2.0, 3.2)
			pylon.mesh = box
			var metal := StandardMaterial3D.new()
			metal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			metal.albedo_color = Color("9eecf5")
			metal.emission_enabled = true
			metal.emission = Color("7ee7f2")
			metal.emission_energy_multiplier = 0.8
			pylon.material_override = metal
			pylon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := float(i) * TAU / 5.0
		pylon.position = ring.position + Vector3(cos(ang) * 34.0, 8.0, sin(ang) * 14.0)
	if _sky == null:
		_sky = MultiMeshInstance3D.new()
		_sky.name = "YardStars"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var dot := SphereMesh.new()
		dot.radius = 1.0
		dot.height = 2.0
		dot.radial_segments = 6
		dot.rings = 3
		mm.mesh = dot
		mm.instance_count = 420
		_sky.multimesh = mm
		var sky_mat := ShaderMaterial.new()
		var twinkle := Shader.new()
		twinkle.code = "shader_type spatial; render_mode unshaded, cull_disabled; void fragment() { float tw = 0.45 + 0.55 * sin(TIME * (1.2 + COLOR.r * 3.0) + COLOR.g * 18.0); ALBEDO = COLOR.rgb * tw; EMISSION = COLOR.rgb * tw * 0.8; }"
		sky_mat.shader = twinkle
		_sky.material_override = sky_mat
		_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_sky)
		var rng := RandomNumberGenerator.new()
		rng.seed = 48291
		for i in mm.instance_count:
			var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.15, 1.0), rng.randf_range(-1.0, 1.0))
			if dir.length_squared() < 0.01:
				dir = Vector3.UP
			dir = dir.normalized()
			var belt := absf(dir.y) < 0.18
			var dist := rng.randf_range(1600.0, 4600.0)
			var scale := rng.randf_range(1.6, 5.4)
			if belt:
				scale *= 1.35
			var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
			mm.set_instance_transform(i, Transform3D(basis, dir * dist))
			var tint := Color(0.72, 0.84, 1.0) if rng.randf() < 0.45 else Color(1.0, 0.9, 0.7)
			if belt:
				tint = tint.lerp(Color(0.85, 0.78, 0.95), 0.35)
			mm.set_instance_color(i, tint)
		var key := OmniLight3D.new()
		key.name = "YardKey"
		key.light_color = Color("fff3d8")
		key.light_energy = 2.4
		key.omni_range = 420.0
		key.shadow_enabled = false
		key.position = Vector3(-36.0, 78.0, 150.0)
		add_child(key)
		var rim := OmniLight3D.new()
		rim.name = "YardRim"
		rim.light_color = Color("ffb56a")
		rim.light_energy = 1.6
		rim.omni_range = 260.0
		rim.shadow_enabled = false
		rim.position = Vector3(80.0, 40.0, -40.0)
		add_child(rim)
		var fill := OmniLight3D.new()
		fill.name = "YardFill"
		fill.light_color = Color(0.62, 0.74, 0.92)
		fill.light_energy = 0.55
		fill.omni_range = 200.0
		fill.shadow_enabled = false
		fill.position = Vector3(-20.0, 12.0, -30.0)
		add_child(fill)
	_sky.visible = true
	if _sun != null:
		_sun.look_at(_sun.global_position - to_star, Vector3.UP)


func _dress_yard() -> void:
	visible = true
	scale = Vector3.ONE
	position = Vector3.ZERO
	for node_name in ["YardSpokes", "Star", "Corona", "YardStars", "YardKey", "YardRim", "YardFill"]:
		var rig := get_node_or_null(node_name) as Node3D
		if rig != null:
			rig.visible = true
	var planet := _body_node("yard_aegis")
	planet.rotation.y = _yard_t * 0.05
	var ball := planet.get_node("Ball") as MeshInstance3D
	var mat := ball.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("spin", _yard_t * 0.02)
	var clouds := planet.get_node("Clouds") as MeshInstance3D
	var cloud_mat := clouds.material_override as ShaderMaterial
	if cloud_mat != null:
		cloud_mat.set_shader_parameter("spin", _yard_t * 0.03)
	var ring := _prop("yard_dock")
	ring.rotation = Vector3(1.2, 0.35 + _yard_t * 0.12, 0.15)
	var paint := ring.material_override as StandardMaterial3D
	if paint != null:
		paint.emission_energy_multiplier = 0.7 + 0.55 * sin(_yard_t * 3.2)
	for i in 5:
		var pylon := _prop("yard_pylon%d" % i)
		var ang := float(i) * TAU / 5.0 + _yard_t * 0.12
		pylon.position = ring.position + Vector3(cos(ang) * 34.0, 8.0, sin(ang) * 14.0)
		var lamp := pylon.material_override as StandardMaterial3D
		if lamp != null:
			lamp.emission_energy_multiplier = 0.45 + 0.55 * maxf(sin(_yard_t * 2.4 + float(i)), 0.0)
	var spokes := get_node_or_null("YardSpokes") as MeshInstance3D
	if spokes != null and spokes.visible:
		var eye := get_viewport().get_camera_3d()
		if eye != null:
			var to_eye := eye.global_position - spokes.global_position
			if to_eye.length_squared() > 4.0:
				var z_axis := to_eye.normalized()
				var x_axis := Vector3.UP.cross(z_axis)
				if x_axis.length_squared() < 0.0001:
					x_axis = Vector3.RIGHT.cross(z_axis)
				x_axis = x_axis.normalized()
				var y_axis := z_axis.cross(x_axis).normalized()
				spokes.basis = Basis(x_axis, y_axis, z_axis)
	if Game.defs.is_empty() or Game.defs.has("ships") == false:
		return
	if Game.defs.ships.has(menu_class) == false:
		return
	var holder := _ship_holder("yard")
	var worn: Array = _signature_mount(menu_class)
	var shapes: Array = Silhouette.shapes_of(Game.defs, worn)
	var layers: Array = Silhouette.layers_of(Game.defs, worn)
	var mesh_key := menu_class + "|" + str(shapes)
	if str(holder.get_meta("mesh_key", "")) != mesh_key:
		_fill_ship(holder, menu_class, shapes, layers)
		holder.set_meta("mesh_key", mesh_key)
	var hull: Dictionary = Game.defs.ships[menu_class]
	var body := Color(str(hull.color))
	var accent := Color(str(hull.accent))
	for child in holder.get_children():
		var part := str(child.name)
		if _hull_part(part):
			var tone := body
			if part == "Deck":
				tone = body.lightened(0.16)
			elif part.begins_with("Trim"):
				tone = accent
			_paint_hull(child, tone, accent)
	var yaw := -0.95 + sin(_yard_t * 0.22) * 0.08
	if menu_hero:
		yaw = _yard_t * 0.42
	holder.rotation = Vector3(0.14 if menu_hero else 0.18, yaw, sin(_yard_t * 0.35) * 0.04)
	if menu_hero:
		holder.position = Vector3(6.0 + menu_bias, 28.0, 0.0)
		holder.scale = Vector3(1.85, 1.85, 1.85)
	else:
		holder.position = Vector3(168.0, 36.0, 24.0)
		holder.scale = Vector3(1.55, 1.55, 1.55)
	holder.visible = true
	if menu_hero:
		planet.visible = false
		var yard_ring := _prop("yard_dock")
		yard_ring.visible = false
		for i in 5:
			var pylon := _prop("yard_pylon%d" % i)
			pylon.visible = false
		for node_name in ["YardSpokes", "Star", "Corona"]:
			var rig := get_node_or_null(node_name) as Node3D
			if rig != null:
				rig.visible = false
	var key := get_node_or_null("YardKey") as OmniLight3D
	var rim := get_node_or_null("YardRim") as OmniLight3D
	var cool := get_node_or_null("YardFill") as OmniLight3D
	if menu_hero:
		if key != null:
			key.position = holder.position + Vector3(-34.0, 52.0, 78.0)
			key.light_energy = 3.6
			key.omni_range = 240.0
		if rim != null:
			rim.position = holder.position + Vector3(56.0, 18.0, -42.0)
			rim.light_energy = 2.8
			rim.omni_range = 200.0
		if cool != null:
			cool.position = holder.position + Vector3(-16.0, 10.0, -24.0)
			cool.light_energy = 0.7
			cool.omni_range = 160.0
	else:
		if key != null:
			var eye := get_viewport().get_camera_3d()
			var key_at := Vector3(40.0, 140.0, 210.0)
			if eye != null:
				key_at = holder.position.lerp(eye.global_position, 0.42) + Vector3(0.0, 36.0, 0.0)
			key.position = key_at
			key.light_energy = 2.6
			key.omni_range = 720.0
		if rim != null:
			rim.position = Vector3(220.0, 80.0, -80.0)
			rim.light_energy = 1.4
			rim.omni_range = 520.0
		if cool != null:
			cool.position = Vector3(-40.0, 30.0, 80.0)
			cool.light_energy = 0.45
			cool.omni_range = 360.0
	_pulse_lamps(holder)
	var flame := holder.get_node_or_null("Exhaust") as MeshInstance3D
	if flame != null:
		flame.visible = true
		var burn := flame.material_override as ShaderMaterial
		if burn != null:
			var glow := 0.45 + 0.25 * sin(_yard_t * 7.0)
			burn.set_shader_parameter("albedo", Color(1.0, 0.62, 0.22, glow))
	var core := holder.get_node_or_null("ExhaustCore") as MeshInstance3D
	if core != null:
		core.visible = true
