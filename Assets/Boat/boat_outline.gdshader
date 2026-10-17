// THE BOAT'S OUTLINE: an ink line round the boat's silhouette, a few pixels wide.
// A screen effect (like a post-process material in Unreal): a rectangle stretched over the whole screen,
// drawn after the sea, that looks at the depth buffer. The depth buffer only holds the solid things, the
// boat (the sea is drawn as see-through, so it isn't in it): where it's empty there's no boat. A pixel
// with no boat but with the boat within outline_width of it is on the edge: it gets the ink colour.
// boat.gd makes the rectangle (add_outline) in front of the camera when the game starts.
shader_type spatial;
// unshaded: no light; depth_test_disabled: always drawn, over everything; depth_draw_never: no depth.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled;

// The depth of what's on screen (0.0 = nothing there: Godot 4 counts depth backwards, 0 is the far end).
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.106, 0.102, 0.090, 1.0);   // ink (#1b1a17)
uniform float outline_width = 1.5;   // how thick the line is, in phone points (the 360 x 800 screen)

void vertex() {
	// Stretch the rectangle (a 1 x 1 QuadMesh, corners at -0.5 and 0.5) over the whole screen,
	// whatever the camera does: -1 .. 1 is the screen from edge to edge.
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

// Is there boat at this point of the screen?
bool boat_at(vec2 uv) {
	return texture(depth_tex, uv).r > 0.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// 1. On the boat itself: nothing to draw here.
	if (boat_at(uv)) {
		discard;
	}
	// 2. How far to look, as a share of the screen: outline_width phone points, scaled to the real screen.
	float pixels = outline_width * VIEWPORT_SIZE.y / 800.0;
	vec2 reach = pixels / VIEWPORT_SIZE;
	// 3. Look all round, in 8 directions: is there boat that close?
	bool near = false;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;   // 45 degrees apart
		if (boat_at(uv + vec2(cos(a), sin(a)) * reach)) {
			near = true;
		}
	}
	// 4. Not near the boat: nothing. Near it: ink.
	if (!near) {
		discard;
	}
	ALBEDO = outline_color.rgb;
	ALPHA = 1.0;   // see-through pass: drawn after the solid things, so the depth buffer is ready
}
