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
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
	float mottled = fbm(wpos * 0.0055 + vec3(seed, 2.2, 0.4));
	float fleck = fbm(wpos * 0.016 + n * 3.0);
	terrain *= 0.74 + 0.38 * mottled;
	terrain = mix(terrain, terrain * vec3(0.76, 0.92, 0.7), fleck * land_w * 0.45);
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
	col *= mix(1.0, relief, 0.5 * day + 0.06);
	float lamps = 0.0;
	if (city > 0.5) {
		float cluster = smoothstep(0.52, 0.8, fbm(n * 4.4 + vec3(2.0, seed, 4.0)));
		vec3 cell = fract(n * 22.0 + vec3(seed));
		float window = step(0.72, cell.x) * step(0.72, cell.y);
		float block = step(0.18, cell.z);
		lamps = window * block * cluster * clamp(-ndl + 0.12, 0.0, 1.0) * land_w;
	}
	float shore = 1.0 - smoothstep(0.0, 0.035, abs(field - 0.5));
	col += vec3(0.9, 0.93, 0.88) * shore * day * 0.55;
	float cloud_shade = smoothstep(0.46, 0.74, fbm(n * 3.6 + vec3(seed, spin, 0.6)));
	col *= 1.0 - cloud_shade * day * 0.42;
	vec3 glow = vec3(1.0, 0.78, 0.42) * lamps * 3.1;
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
	vec3 shade = vec3(0.45, 0.5, 0.58);
	vec3 lit = vec3(0.96, 0.97, 0.98);
	float silver = pow(clamp(ndl, 0.0, 1.0), 3.0) * cover;
	ALBEDO = mix(shade, lit, day) + vec3(1.0) * silver * 0.18;
	ALPHA = cover * (0.08 + 0.55 * day);
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
	ALPHA = fres * (0.16 + 0.62 * sun) * (0.55 + 0.45 * grazing);
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
	float grain = fbm(n * 9.0);
	float cells = fbm(n * 22.0);
	vec3 hot = mix(albedo.rgb * 0.72, vec3(1.0, 0.96, 0.88), 0.55);
	vec3 col = hot * dark * (0.78 + 0.28 * grain) * (0.9 + 0.16 * cells);
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
	float fres = pow(clamp(1.0 - abs(dot(n, eye)), 0.0, 1.0), 1.25);
	float ray = 0.72 + 0.28 * sin(atan(n.y, n.x) * 8.0);
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb * 0.6;
	ALPHA = fres * fres * 0.7 * ray;
}
"

const HULL_SHADER := "shader_type spatial;
varying vec3 local_pos;
varying vec3 local_nrm;
varying vec3 wnorm;
varying vec3 wpos;
uniform vec4 albedo : source_color = vec4(0.5, 0.55, 0.58, 1.0);
void vertex() {
	local_pos = VERTEX;
	local_nrm = NORMAL;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(local_nrm);
	vec3 wn = normalize(wnorm);
	vec2 cell = floor(local_pos.xz * vec2(0.07, 0.15));
	float panel = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float seam_x = smoothstep(0.455, 0.5, abs(fract(local_pos.x * 0.07) - 0.5));
	float seam_z = smoothstep(0.43, 0.5, abs(fract(local_pos.z * 0.15) - 0.5));
	float seam = clamp(max(seam_x, seam_z), 0.0, 1.0);
	float deck = clamp(n.y, 0.0, 1.0);
	vec3 col = albedo.rgb * (0.42 + 0.7 * deck);
	col *= 0.82 + 0.22 * panel;
	col = mix(col, col * vec3(0.18, 0.2, 0.22), seam);
	float brush = 0.9 + 0.1 * sin(local_pos.x * 2.2 + local_pos.z * 11.0);
	col *= brush;
	float along_x = fract(local_pos.x * 0.35);
	float along_z = fract(local_pos.z * 0.55);
	float rivet = max(seam_z * smoothstep(0.07, 0.0, abs(along_x - 0.5)), seam_x * smoothstep(0.07, 0.0, abs(along_z - 0.5)));
	col = mix(col, col * vec3(0.42, 0.46, 0.5), clamp(rivet, 0.0, 1.0) * 0.8);
	float aft = smoothstep(6.0, -22.0, local_pos.x);
	col = mix(col, col * vec3(1.22, 0.68, 0.38), aft * 0.34);
	float wear = smoothstep(0.45, 0.92, 1.0 - abs(n.y));
	col = mix(col, col * vec3(0.7, 0.68, 0.62), wear * 0.4);
	float stripe = smoothstep(1.35, 0.05, abs(local_pos.z));
	col = mix(col, col * vec3(1.04, 1.08, 1.02), stripe * deck * 0.4);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 halfv = normalize(normalize(vec3(0.25, 1.0, 0.12)) + eye);
	float spec = pow(clamp(dot(wn, halfv), 0.0, 1.0), 64.0);
	float edge = pow(clamp(1.0 - abs(dot(wn, eye)), 0.0, 1.0), 2.2);
	col += vec3(0.78, 0.86, 0.94) * spec * (1.0 - seam) * (0.25 + 0.55 * deck);
	col += albedo.rgb * edge * 0.22;
	ALBEDO = col;
	METALLIC = mix(0.84, 0.35, seam);
	ROUGHNESS = mix(0.24, 0.88, max(seam, 1.0 - deck));
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
	ALBEDO = mix(albedo.rgb * 0.22 * room, vec3(0.9, 0.97, 1.0), fres);
	EMISSION = vec3(0.42, 0.72, 0.78) * (0.08 + fres * 0.22);
	ROUGHNESS = mix(0.04, 0.2, 1.0 - fres);
	METALLIC = 0.08;
	ALPHA = clamp(0.16 + fres * 0.7, 0.0, 0.82);
}
"

const PLUME_SHADER := "shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
uniform vec4 albedo : source_color = vec4(1.0, 0.7, 0.3, 0.8);
uniform float core = 0.0;
void fragment() {
	float along = clamp(UV.x, 0.0, 1.0);
	float across = clamp(1.0 - abs(UV.y * 2.0 - 1.0), 0.0, 1.0);
	float flicker = 0.84 + 0.16 * sin(TIME * 31.0 + along * 18.0);
	float diamonds = 0.78 + 0.22 * sin(along * 34.0 - TIME * 16.0);
	float fade = (1.0 - smoothstep(0.04, 1.0, along)) * (0.28 + 0.72 * across);
	vec3 sheath = mix(vec3(0.85, 0.28, 0.05), albedo.rgb, 0.45);
	vec3 hot = mix(sheath, vec3(1.0, 0.97, 0.9), core * (1.0 - along) * flicker);
	hot *= mix(1.0, diamonds, across * (1.0 - along));
	ALBEDO = hot;
	EMISSION = hot * flicker * (1.35 + core * 1.8);
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
void vertex() {
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
	col *= 0.84 + 0.16 * grit;
	float spark = step(0.86, fract(sin(dot(UV * 48.0, vec2(19.1, 7.7)) + seed) * 43758.5));
	col += vec3(0.92, 0.96, 1.0) * spark * 0.45;
	vec3 radial = wpos - planet_pos;
	float lit = 0.7;
	if (dot(radial, radial) > 4.0) {
		lit = smoothstep(-0.25, 0.55, dot(normalize(radial), normalize(to_star)));
	}
	col *= 0.28 + 0.85 * lit;
	ALBEDO = col;
	ALPHA = albedo.a * (0.88 - gap * 0.7);
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
	vec3 col = mineral * (0.18 + 0.9 * ndl) * mix(1.0, 0.38, cavity);
	col *= 1.0 - pits * 0.35;
	float vein = smoothstep(0.52, 0.74, fbm(n * 11.0 + vec3(seed, 2.2, 0.5)));
	col = mix(col, mineral * vec3(0.62, 0.48, 0.32), vein * 0.42);
	float rim = pow(1.0 - ndl, 2.2);
	col += mineral * rim * 0.12;
	ALBEDO = col;
	ROUGHNESS = mix(0.78, 0.98, cavity);
	METALLIC = 0.06;
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
	ALBEDO = albedo.rgb * (0.55 + 0.45 * fade);
	EMISSION = albedo.rgb * fade * 0.55;
	ALPHA = albedo.a * fade;
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
var _sky: MultiMeshInstance3D
var _band: MultiMeshInstance3D
var _grid: MeshInstance3D
var _sun: DirectionalLight3D
var _planet_shader: Shader
var _cloud_shader: Shader
var _air_shader: Shader
var _star_shader: Shader
var _corona_shader: Shader
var _hull_shader: Shader
var _glass_shader: Shader
var _plume_shader: Shader
var _ring_shader: Shader
var _nebula_shader: Shader
var _gate_shader: Shader
var _rock_shader: Shader
var _wake_shader: Shader
var _ground_shader: Shader
var _fill: DirectionalLight3D
var _beacon_light: OmniLight3D
var _frame_delta := 0.016
var _used: Dictionary = {}


func _ready() -> void:
	_planet_shader = _compile(PLANET_SHADER)
	_cloud_shader = _compile(CLOUD_SHADER)
	_air_shader = _compile(AIR_SHADER)
	_star_shader = _compile(STAR_SHADER)
	_corona_shader = _compile(CORONA_SHADER)
	_hull_shader = _compile(HULL_SHADER)
	_glass_shader = _compile(GLASS_SHADER)
	_plume_shader = _compile(PLUME_SHADER)
	_ring_shader = _compile(RING_SHADER)
	_nebula_shader = _compile(NEBULA_SHADER)
	_gate_shader = _compile(GATE_SHADER)
	_rock_shader = _compile(ROCK_SHADER)
	_wake_shader = _compile(WAKE_SHADER)
	_ground_shader = _compile(GROUND_SHADER)
	_build_grid()
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color("fff0d4")
	_sun.light_energy = 1.55
	_sun.shadow_enabled = false
	add_child(_sun)
	_fill = DirectionalLight3D.new()
	_fill.name = "Fill"
	_fill.light_color = Color(0.72, 0.8, 0.95)
	_fill.light_energy = 0.58
	_fill.shadow_enabled = false
	_fill.basis = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0))
	add_child(_fill)


func _compile(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


func _process(delta: float) -> void:
	_frame_delta = maxf(delta, 0.001)
	if Game.sim == null or Game.mode != "sector":
		return
	_used.clear()
	tags.clear()
	_sync_star(Game.sim)
	_sync_planets(Game.sim)
	_sync_ships(Game.sim)
	_sync_craft(Game.sim)
	_sync_sky(Game.sim)
	_sync_band()
	_sync_props(Game.sim)
	_aim_sun(Game.sim)
	_hide_stale(_bodies)
	_hide_stale(_ships)
	_hide_stale(_craft)
	_hide_stale(_props)


func chart(p: Vector2, height: float = 0.0) -> Vector3:
	var render: Vector2 = p
	var gate: Variant = WorldCoord.gate()
	if gate != null:
		render = gate.render_of_world(p)
	return Vector3(render.x, height, -render.y)


func _sync_props(sim) -> void:
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
			var local := PackedVector2Array()
			for point in verts:
				local.append(point - center)
			var span := float(row.get("size", 12.0))
			chunk.mesh = _prism(local, maxf(8.0, span * 0.62))
			chunk.transform = _flat_xform(center, float(absi(hash(str(index))) % 7) * 0.2, 0.0)
			var stone := ShaderMaterial.new()
			stone.shader = _rock_shader
			stone.set_shader_parameter("albedo", Color(str(row.get("tint", "#6a6258"))))
			stone.set_shader_parameter("seed", float(absi(hash(str(index))) % 97) * 0.1)
			chunk.material_override = stone
			chunk.set_meta("built", "yes")
		chunk.visible = chunk.mesh != null
	if volume:
		_sync_belt_volume(sim, belt)
	index = 0
	for hull in sim.trash:
		var row: Dictionary = hull
		var scrap := _prop("trash%d" % index)
		index += 1
		if str(scrap.get_meta("built", "")) != "yes":
			var scale := float(row.get("scale", 1.0))
			var poly := _trash_poly(int(row.get("kind", 0)), scale)
			scrap.mesh = _prism(poly, maxf(4.0, 5.5 * scale))
			scrap.material_override = _hull_mat(Color("6a5344"))
			scrap.set_meta("built", "yes")
		scrap.transform = _flat_xform(row.pos, float(row.rot), 1.0)
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
		veil.position = hoop.position
		veil.basis = door
		_tag(str(row.get("name", "")), chart(row.pos, radius * 0.15 + 20.0), Color("e6d7a8"), 13)
	var mast := _prop("beacon")
	if str(mast.get_meta("built", "")) != "yes":
		var pole := CylinderMesh.new()
		pole.top_radius = 2.2
		pole.bottom_radius = 3.4
		pole.height = 36.0
		mast.mesh = pole
		mast.material_override = _metal(Color("8a7a62"))
		mast.set_meta("built", "yes")
	mast.position = chart(sim.beacon_pos, 18.0)
	var yard := _prop("beacon_yard")
	if str(yard.get_meta("built", "")) != "yes":
		var arm := BoxMesh.new()
		arm.size = Vector3(18.0, 1.4, 1.6)
		yard.mesh = arm
		yard.material_override = _metal(Color("6e6254"))
		yard.set_meta("built", "yes")
	yard.position = chart(sim.beacon_pos, 32.0)
	var pad := _prop("beacon_pad")
	if str(pad.get_meta("built", "")) != "yes":
		var slab := BoxMesh.new()
		slab.size = Vector3(22.0, 2.4, 22.0)
		pad.mesh = slab
		pad.material_override = _hull_mat(Color("6a5e50"))
		pad.set_meta("built", "yes")
	pad.position = chart(sim.beacon_pos, 1.2)
	var halo := _prop("beacon_halo")
	if str(halo.get_meta("built", "")) != "yes":
		halo.mesh = _annulus(10.0, 18.0, 1.2, 36)
		var ring_mat := ShaderMaterial.new()
		ring_mat.shader = _ring_shader
		ring_mat.set_shader_parameter("albedo", Color(0.72, 0.86, 0.74, 0.55))
		ring_mat.set_shader_parameter("planet_pos", chart(sim.beacon_pos, 0.0))
		ring_mat.set_shader_parameter("to_star", Vector3(0.0, 1.0, 0.0))
		halo.material_override = ring_mat
		halo.set_meta("built", "yes")
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
	lamp.position = chart(sim.beacon_pos, 40.0)
	if _beacon_light == null:
		_beacon_light = OmniLight3D.new()
		_beacon_light.name = "BeaconLight"
		_beacon_light.light_color = Color(0.78, 0.92, 0.74)
		_beacon_light.light_energy = 1.15
		_beacon_light.omni_range = 90.0
		_beacon_light.shadow_enabled = false
		add_child(_beacon_light)
	_beacon_light.position = chart(sim.beacon_pos, 38.0)
	_tag("Dock beacon", chart(sim.beacon_pos, 52.0), Color("8aa896"), 13)
	_sync_density(sim)
	_sync_pocket(sim)
	_sync_nebula()
	_sync_shots(sim)
	_sync_wrecks(sim)
	_sync_meteors(sim)
	_sync_claim(sim)


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
	hoop.position = chart(sim.pocket_pos, 2.0)
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
		index += 1
		if bolt.mesh == null:
			var ball := SphereMesh.new()
			ball.radius = 2.4
			ball.height = 4.8
			ball.radial_segments = 10
			ball.rings = 6
			bolt.mesh = ball
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color("fff1d2")
			mat.emission_enabled = true
			mat.emission = Color("e7b15a")
			mat.emission_energy_multiplier = 2.0
			bolt.material_override = mat
		var shot_vel: Vector2 = row.vel
		var reach := 2.4
		var aim := Vector2.RIGHT
		if shot_vel.length() > 1.0:
			aim = shot_vel.normalized()
			reach = clampf(shot_vel.length() * 0.045, 6.0, 22.0)
		var shot_x := Vector3(aim.x, 0.0, -aim.y)
		var shot_z := Vector3(-aim.y, 0.0, -aim.x)
		bolt.basis = Basis(shot_x, Vector3.UP, shot_z).scaled(Vector3(reach, 2.2, 2.2))
		bolt.position = chart(row.pos, 8.0)


func _sync_wrecks(sim) -> void:
	var index := 0
	for wreck in sim.wrecks:
		var row: Dictionary = wreck
		var hulk := _prop("wreck%d" % index)
		index += 1
		if str(hulk.get_meta("built", "")) != "yes":
			var poly := PackedVector2Array([Vector2(12, 2), Vector2(-6, 9), Vector2(-14, -2), Vector2(3, -8)])
			hulk.mesh = _prism(poly, 7.0)
			hulk.material_override = _hull_mat(Color("5a4038"))
			hulk.set_meta("built", "yes")
		hulk.transform = _flat_xform(row.pos, 0.4, 1.0)
		var shard := _prop("wreckbit%d" % (index - 1))
		if str(shard.get_meta("built", "")) != "yes":
			var bit := PackedVector2Array([Vector2(5, 1), Vector2(-4, 3), Vector2(-6, -1), Vector2(2, -3)])
			shard.mesh = _prism(bit, 3.4)
			shard.material_override = _hull_mat(Color("3a2a26"))
			shard.set_meta("built", "yes")
		var pos: Vector2 = row.pos
		shard.transform = _flat_xform(pos + Vector2(8.0, 6.0), 1.1, 2.4)
		_tag(str(row.get("name", "wreck")), chart(row.pos, 16.0), Color("a08070"), 12)


func _sync_meteors(sim) -> void:
	var index := 0
	for rock in sim.meteors:
		var row: Dictionary = rock
		var node := _prop("meteor%d" % index)
		index += 1
		if node.mesh == null:
			var ball := SphereMesh.new()
			ball.radius = float(row.get("size", 4.0)) * 2.2
			ball.height = ball.radius * 2.0
			node.mesh = ball
			var mat := ShaderMaterial.new()
			mat.shader = _rock_shader
			mat.set_shader_parameter("albedo", Color("8a3c22"))
			mat.set_shader_parameter("seed", float(index) * 0.37)
			node.material_override = mat
		node.position = chart(row.pos, float(row.get("size", 4.0)))


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


func _sync_star(sim) -> void:
	var radius := float(sim.star_radius)
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
	if _star_far == null:
		_star_far = MeshInstance3D.new()
		_star_far.name = "Halo"
		var shell := SphereMesh.new()
		shell.radial_segments = 28
		shell.rings = 14
		_star_far.mesh = shell
		var far := ShaderMaterial.new()
		far.shader = _corona_shader
		_star_far.material_override = far
		_star_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_star_far)
	(_star_far.mesh as SphereMesh).radius = radius * 2.35
	(_star_far.mesh as SphereMesh).height = radius * 4.7
	var far_col := core
	far_col.a = 0.45
	(_star_far.material_override as ShaderMaterial).set_shader_parameter("albedo", far_col)
	var show_star := int(sim.layer) == ScaleFrame.BAND
	_star_mesh.visible = show_star
	_star_glow.visible = show_star
	_star_far.visible = show_star


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
		var limb := bid == str(sim.body_id)
		var radius := float(row.radius)
		if limb:
			radius = ScaleFrame.LIMB_RADIUS
			var ship: Vector2 = sim.player.pos
			var away: Vector2 = ship - row.pos
			if away.length() < 1.0:
				away = Vector2.RIGHT
			away = away.normalized()
			var center2 := ship - away * (radius + 420.0)
			node.position = chart(center2, -140.0)
		else:
			node.position = chart(row.pos, 0.0)
		node.rotation.y = float(row.get("angle", 0.0)) + float(sim.time) * float(row.get("spin", 0.05))
		var ball := node.get_node("Ball") as MeshInstance3D
		(ball.mesh as SphereMesh).radius = radius
		(ball.mesh as SphereMesh).height = radius * 2.0
		var air := node.get_node("Air") as MeshInstance3D
		(air.mesh as SphereMesh).radius = radius * 1.012
		(air.mesh as SphereMesh).height = radius * 2.024
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
		_sync_ring(node, draw, radius, to_star)
		_sync_moon(node, sim, draw, radius)
		_parallax(node, radius, float(sim.time), limb)
		var label_at := chart(row.pos, float(row.radius) + 28.0)
		if limb:
			label_at = chart(sim.player.pos, 80.0)
		_tag(str(row.get("name", "")), label_at, Color("e6d7bf"), 16)
	var star_name := str(sim.defs.system.star.name)
	_tag(star_name, Vector3(0.0, float(sim.star_radius) + 40.0, 0.0), Color("f0c27a"), 16)


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
	hoop.position = Vector3.ZERO
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
		(well.mesh as TorusMesh).inner_radius = maxf(soi - 180.0, 20.0)
		(well.mesh as TorusMesh).outer_radius = soi + 180.0
		well.visible = true
		_tag(str(row.name), node.position + Vector3(0.0, icon + 200.0, 0.0), Color("e6d7bf"), 16)
	var mark := _prop("chart_ship")
	if mark.mesh == null:
		var dot := SphereMesh.new()
		dot.radius = 280.0
		dot.height = 560.0
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
		node.position = Vector3.ZERO
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
		_tag(str(row.name), Vector3(0.0, radius * 0.15, 0.0), Color("e6d7bf"), 16)


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
	sphere.radial_segments = 96
	sphere.rings = 48
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
	shell.radial_segments = 40
	shell.rings = 20
	air.mesh = shell
	var haze := ShaderMaterial.new()
	haze.shader = _air_shader
	air.material_override = haze
	air.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(air)
	add_child(node)
	_bodies[bid] = node
	return node


func _sync_ring(node: Node3D, row: Dictionary, radius: float, to_star: Vector3) -> void:
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
	var band := maxf(36.0, radius * 0.085)
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
	var outer_mat := outer.material_override as ShaderMaterial
	var dust := ice
	dust.a = 0.42
	outer_mat.set_shader_parameter("albedo", dust)
	outer_mat.set_shader_parameter("planet_pos", node.position)
	outer_mat.set_shader_parameter("to_star", to_star)
	outer_mat.set_shader_parameter("seed", 1.4)


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
		sphere.radial_segments = 24
		sphere.rings = 12
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
	var mesh_key := class_id + "|" + str(shapes) + "|" + str(layers.size())
	if str(holder.get_meta("mesh_key", "")) != mesh_key:
		_fill_ship(holder, class_id, shapes, layers)
		holder.set_meta("mesh_key", mesh_key)
	var hull: Dictionary = sim.defs.ships[class_id]
	var hp := clampf(float(ship.hp) / maxf(float(ship.max_hp), 1.0), 0.0, 1.0)
	var body := Color(str(hull.color)).lerp(Color("3a1818"), (1.0 - hp) * 0.65)
	var accent := Color(str(hull.accent))
	for child in holder.get_children():
		var part := str(child.name)
		if _hull_part(part):
			var paint := body
			if part == "Deck":
				paint = body.lightened(0.16)
			elif part.begins_with("Trim"):
				paint = accent
			_paint_hull(child, paint)
	var thrusting := bool(ship.get("thrusting", false))
	holder.set_meta("thrusting", thrusting)
	if int(sim.layer) == ScaleFrame.SITE and key == "player":
		holder.scale = Vector3(0.28, 0.28, 0.28)
		holder.position = chart(sim.site_pos + Vector2(36.0, -20.0), 280.0)
		holder.rotation = Vector3(-0.4, float(ship.rot), 0.15)
	else:
		holder.scale = Vector3.ONE
		_banked(holder, ship.pos, float(ship.rot), 2.0)
	_pulse_lamps(holder)
	var exhaust := holder.get_node_or_null("Exhaust") as MeshInstance3D
	if exhaust != null:
		exhaust.visible = thrusting
	var core := holder.get_node_or_null("ExhaustCore") as MeshInstance3D
	if core != null:
		core.visible = thrusting
	_place_wake(holder, ship)
	_place_jet_light(holder, thrusting)
	var call := str(ship.get("name", hull.get("callsign", class_id)))
	if key == "player":
		call = str(hull.get("callsign", call))
	_tag(call, chart(ship.pos + Vector2(22.0, 18.0), float(holder.get_meta("crown", 16.0))), Color("e6d7bf"), 14)


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
	var box := BoxMesh.new()
	box.size = deck_size
	bridge.mesh = box
	bridge.position = deck + Vector3(0.0, deck_size.y * 0.5, 0.0)
	bridge.material_override = _metal(Color("1c2428"))
	holder.add_child(bridge)
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var canopy := BoxMesh.new()
	canopy.size = Vector3(deck_size.x * 0.55, 2.4, deck_size.z * 0.45)
	glass.mesh = canopy
	glass.position = bridge.position + Vector3(deck_size.x * 0.1, deck_size.y * 0.5 + 0.8, 0.0)
	var pane := ShaderMaterial.new()
	pane.shader = _glass_shader
	pane.set_shader_parameter("albedo", Color(0.45, 0.78, 0.82, 0.4))
	glass.material_override = pane
	holder.add_child(glass)
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
	bell.mesh = _bell_mesh(7.5, 1.15, 2.7)
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
	var rail := BoxMesh.new()
	rail.size = Vector3(span * 0.72, 1.3, 1.5)
	spine.mesh = rail
	spine.position = Vector3((nose + tail) * 0.5, height * 1.08, 0.0)
	spine.material_override = _hull_mat(Color("14181c"))
	holder.add_child(spine)
	var fin_mesh := BoxMesh.new()
	fin_mesh.size = Vector3(span * 0.22, 0.45, 2.6)
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


func _fill_ship(holder: Node3D, class_id: String, shapes: Array, layers: Array) -> void:
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
		circle_i += 1
	_add_bridge(holder, class_id, height, float(geom.tail))


func _sync_craft(sim) -> void:
	var parked := 0
	var index := 0
	for item in sim.craft:
		var row: Dictionary = item
		var pos: Vector2 = row.pos
		var rot := float(row.rot)
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
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		_sky.material_override = mat
		_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_sky)
	var mm := _sky.multimesh
	var count: int = sim.stars.size()
	if mm.instance_count != count:
		mm.instance_count = count
	for i in count:
		var star: Dictionary = sim.stars[i]
		var p: Vector2 = star.pos
		var lift := float(absi(hash(str(i))) % 500) - 250.0
		var scale := 1.6 + float(star.a) * 5.4
		var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, lift, -p.y)))
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


func _banked(holder: Node3D, pos: Vector2, rot: float, height: float) -> void:
	var prev := float(holder.get_meta("prev_rot", rot))
	var dyaw := wrapf(rot - prev, -PI, PI)
	holder.set_meta("prev_rot", rot)
	var rate := dyaw / _frame_delta
	# Positive sim yaw is a screen-left turn under the mirrored overhead
	# camera, and it drops local +Z. That side is the screen-left wing
	# when the nose points up the frame, so the visible right side rises
	# into a left turn and drops into a right turn.
	var want := clampf(rate * 0.16, -0.42, 0.42)
	var shown := float(holder.get_meta("bank", 0.0))
	shown = move_toward(shown, want, 2.2 * _frame_delta)
	holder.set_meta("bank", shown)
	var want_pitch := 0.1 if bool(holder.get_meta("thrusting", false)) else 0.0
	var pitch := float(holder.get_meta("pitch", 0.0))
	pitch = move_toward(pitch, want_pitch, 0.55 * _frame_delta)
	holder.set_meta("pitch", pitch)
	var xf := _flat_xform(pos, rot, height)
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
	var reach := clampf(speed * 0.18, 16.0, 64.0)
	var width := clampf(12.0 + speed * 0.02, 12.0, 20.0)
	wake.visible = true
	wake.position = Vector3(trail.x * 8.0, 0.7, trail.y * 8.0)
	wake.basis = Basis(Vector3.UP, atan2(trail.y, -trail.x)).scaled(Vector3(reach, 1.0, width))


func _place_jet_light(holder: Node3D, thrusting: bool) -> void:
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
	lamp.visible = thrusting


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
	if part == "Plate" or part == "Deck" or part.begins_with("TrimC"):
		return true
	if part.begins_with("Trim") and part.trim_prefix("Trim").is_valid_int():
		return true
	return false


func _paint_hull(node: Node, color: Color) -> void:
	if node is MeshInstance3D == false:
		return
	var mat: Material = (node as MeshInstance3D).material_override
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("albedo", color)


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
	var segs := 14
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


func _prism(poly: PackedVector2Array, height: float, top_scale: float = 0.86) -> ArrayMesh:
	if poly.size() < 3:
		return null
	var indices := Geometry2D.triangulate_polygon(poly)
	if indices.size() < 3:
		return null
	var top := poly
	if top_scale < 0.995:
		top = _inset_poly(poly, top_scale)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := poly.size()
	var centroid := Vector2.ZERO
	for point in poly:
		centroid += point
	centroid /= float(count)
	for t in range(0, indices.size(), 3):
		_tri(st, top[indices[t]], top[indices[t + 1]], top[indices[t + 2]], height, Vector3.UP)
		_tri(st, poly[indices[t]], poly[indices[t + 2]], poly[indices[t + 1]], 0.0, Vector3.DOWN)
	for i in count:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		var edge := b - a
		var outward := Vector2(edge.y, -edge.x)
		if outward.dot(a - centroid) < 0.0:
			outward = -outward
		if outward.length_squared() < 0.0001:
			continue
		outward = outward.normalized()
		_slope(st, a, b, top[i], top[(i + 1) % count], height, outward)
	return st.commit()


func _slope(st: SurfaceTool, a: Vector2, b: Vector2, ta: Vector2, tb: Vector2, height: float, outward: Vector2) -> void:
	var edge := Vector3(b.x - a.x, 0.0, b.y - a.y)
	var rise := Vector3(ta.x - a.x, height, ta.y - a.y)
	var normal := edge.cross(rise)
	var out3 := Vector3(outward.x, 0.15, outward.y)
	if normal.dot(out3) < 0.0:
		normal = -normal
	if normal.length_squared() < 0.0001:
		normal = out3
	normal = normal.normalized()
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, 0.0, a.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(b.x, 0.0, b.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(tb.x, height, tb.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(a.x, 0.0, a.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(tb.x, height, tb.y))
	st.set_normal(normal)
	st.add_vertex(Vector3(ta.x, height, ta.y))


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
