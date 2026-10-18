// THE FOG OF WAR, as a screen effect (like a post-process material in Unreal): a rectangle stretched over
// the whole screen, drawn after everything in the world, that paints black over what the boat hasn't
// seen yet. It covers the sea and any 3D object alike (coasts, islands…).
// sea.gd makes the rectangle when the game starts and hands it the Fog autoload's picture (fog.gd).
//
// For each pixel it works out which point of the sea it shows: it follows the camera's line of sight
// through that pixel down to the water (height 0) and reads the fog picture there. A tall object is
// fogged as the patch of water just behind it, a small shift that the soft fog edge hides.
shader_type spatial;
// unshaded: no light; depth_test_disabled: drawn over everything; depth_draw_never: changes no depth.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled;

// The fog picture (one pixel a cell, white = not seen yet), stretched smoothly over the 504 m map.
uniform sampler2D fog_tex : filter_linear, hint_default_black;
uniform float world_size = 504.0;   // metres the picture covers, a side (as Fog.WORLD_SIZE)
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);   // black: ink once dithered
// How wide the fog's soft edge is, in metres (sea.gd's fog_falloff, in the Sea node's Inspector).
// 0 = as it comes: soft over about one cell (4.8 m). More = a wider, softer edge (a small blur).
uniform float falloff : hint_range(0.0, 30.0) = 0;

void vertex() {
	// Stretch the rectangle (a 1 x 1 QuadMesh, corners at -0.5 and 0.5) over the whole screen.
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

// A point of the screen at a given depth, back in the world (in metres).
vec3 screen_to_world(vec2 ndc, float z, mat4 inv_projection, mat4 inv_view) {
	vec4 view = inv_projection * vec4(ndc, z, 1.0);
	view.xyz /= view.w;
	return (inv_view * vec4(view.xyz, 1.0)).xyz;
}

void fragment() {
	// 1. This pixel as a line of sight: two points on it, one nearer and one farther from the camera.
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	vec3 a = screen_to_world(ndc, 0.0, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 b = screen_to_world(ndc, 1.0, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	// 2. Where that line meets the water (height 0): how far along from a to b the height drops to 0.
	float along = a.y / (a.y - b.y);
	vec3 water = mix(a, b, along);
	// 3. That point on the fog picture: the map's middle (home, 0, 0) is the picture's middle.
	vec2 uv = water.xz / world_size + 0.5;
	float fog = texture(fog_tex, uv).r;    // 1 = in fog, 0 = seen
	// 3b. The soft edge: with a falloff, average the fog here with 8 points round it, falloff metres away
	//     (a ring, 45 degrees apart): near the edge some are in fog and some not, so it shades off gently.
	if (falloff > 0.0) {
		float reach = falloff / world_size;        // falloff metres, as a share of the picture
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;         // 45 degrees apart
			fog += texture(fog_tex, uv + vec2(cos(a), sin(a)) * reach).r;
		}
		fog /= 9.0;
	}
	// 4. Paint the fog colour, as strong as the fog there (soft at its edge).
	ALBEDO = fog_color.rgb;
	ALPHA = fog;
}
