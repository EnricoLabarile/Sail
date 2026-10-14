// THE SEA AND THE LAND, painted.
// This shader draws the big plane under everything (Sea, in sea.tscn). It does two things:
//   1. it shows the map Enrico paints (map_paint.png), stretched over the whole world;
//   2. on the sea only (where map_collision.png is black), it adds short dark wavelets that stay
//      fixed in the world, so you can see the boat moving.
// Unshaded: no light on it, the greys are shown as painted; the dither turns them into paper and ink.
shader_type spatial;
render_mode unshaded;

// The painted map. repeat_enable: past one edge the map starts again from the other (the world wraps).
uniform sampler2D map_tex : source_color, filter_linear_mipmap, repeat_enable;
// White = land, black = sea (the same image the boat uses to find the shore).
uniform sampler2D land_mask : filter_linear, repeat_enable;
// How many metres one copy of the map covers (the prototype's 5040 px world = 504 m).
uniform float world_size = 504.0;

uniform vec4 wavelet : source_color = vec4(0.25, 0.25, 0.24, 1.0);
uniform float cell = 2.2;       // metres between wavelets
uniform float dash_len = 0.22;  // a wavelet's half length, in cells

// world_pos: where on the sea this pixel is, in metres. vertex() works it out, fragment() reads it.
varying vec3 world_pos;

// A cheap "random" number between 0 and 1 for each cell, always the same for the same cell.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Which point of the map is here: home (world 0, 0) is the middle of the picture (0.5, 0.5).
	vec2 uv = world_pos.xz / world_size + 0.5;
	vec3 painted = texture(map_tex, uv).rgb;
	float is_land = texture(land_mask, uv).r;            // 0 at sea, 1 on land

	// The wavelets: the sea is cut into cells, each with one short curved dash at a random spot.
	vec2 p = world_pos.xz / cell;
	vec2 id = floor(p);
	vec2 f = fract(p) - (vec2(hash(id), hash(id + 7.3)) * 0.5 + 0.25);
	float bend = f.x * f.x * 1.5;                       // a slight curve
	float on = step(abs(f.y + bend), 0.03) * step(abs(f.x), dash_len);
	float blink = step(0.35, 0.5 + 0.5 * sin(TIME * 0.7 + hash(id + 3.1) * 6.28));   // each fades in and out
	float at_sea = step(is_land, 0.5);                  // 1 at sea, 0 on land: no wavelets on the land

	ALBEDO = mix(painted, wavelet.rgb, on * blink * at_sea);
}
