// THE SEA: the big flat plane under everything (Sea, in sea.tscn), 504 x 504 metres, fixed in place with
// home in the middle. The coasts are separate 3D meshes on top of it. It does three things:
//   1. it paints the sea one flat grey (sea_color), with short dark wavelets that stay fixed in the
//      world, so you can see the boat moving;
//   2. it covers in black what the boat hasn't seen yet (the fog of war, fog.gd);
//   3. it never covers the boat: it skips every pixel the boat's mask has marked (a stencil, see
//      Assets/Boat/boat_mask.gdshader), so the water doesn't cut through her when she heels.
// Unshaded: no light on it, the greys are shown as they are; the dither turns them into paper and ink.
shader_type spatial;
render_mode unshaded;
// The stencil: draw only where the stencil buffer is NOT 1 (1 = the boat's mask was drawn there).
stencil_mode read, compare_not_equal, 1;

uniform vec4 sea_color : source_color = vec4(0.91, 0.91, 0.91, 1.0);   // the water's grey
uniform vec4 wavelet : source_color = vec4(0.25, 0.25, 0.24, 1.0);
uniform float cell = 2.2;       // metres between wavelets
uniform float dash_len = 0.22;  // a wavelet's half length, in cells
// The fog of war (set by sea.gd from the Fog autoload): one pixel a cell, white = not seen yet.
// filter_linear stretches it smoothly, so the fog's edge is soft, not blocky.
// hint_default_black: when no picture is given, it counts as all black = no fog. That's the editor:
// the Fog autoload and sea.gd only run in the game, so in the editor you see the whole map.
uniform sampler2D fog_tex : filter_linear, hint_default_black;

// world_pos: where on the sea this pixel is, in metres. vertex() works it out, fragment() reads it.
varying vec3 world_pos;

// A cheap "random" number between 0 and 1 for each cell, always the same for the same cell.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The wavelets: the sea is cut into cells, each with one short curved dash at a random spot.
	vec2 p = world_pos.xz / cell;
	vec2 id = floor(p);
	vec2 f = fract(p) - (vec2(hash(id), hash(id + 7.3)) * 0.5 + 0.25);
	float bend = f.x * f.x * 1.5;                       // a slight curve
	float on = step(abs(f.y + bend), 0.03) * step(abs(f.x), dash_len);
	float blink = step(0.35, 0.5 + 0.5 * sin(TIME * 0.7 + hash(id + 3.1) * 6.28));   // each fades in and out

	vec3 col = mix(sea_color.rgb, wavelet.rgb, on * blink);

	// The fog of war: where the boat hasn't been, solid black (ink once dithered), as in the prototype.
	// UV is this pixel's place on the plane, (0, 0) at one corner and (1, 1) at the other.
	float fog = texture(fog_tex, UV).r;                 // 1 = in fog, 0 = seen
	ALBEDO = mix(col, vec3(0.0), fog);
	// Fully solid, but writing ALPHA puts the sea among the see-through things, which Godot draws AFTER
	// the solid ones: so the boat (and its mask) is already drawn when the sea comes, and the stencil works.
	ALPHA = 1.0;
}
