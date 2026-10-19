// ONE WIND LINE: a thin wavy ink line drawn on a long, narrow flat rectangle lying on the water.
// (In Unreal: an unlit translucent material on a plane.) wind_lines.gd sets the numbers below for each line.
//
// The rectangle runs along its length the way the wind blows (UV.x: 0 = the tail end, 1 = the head end).
// As `progress` goes from 0 to 1 over the line's life, the head draws itself out down the wind, then the
// tail catches up and the line is gone, fading quickly in at the start and out at the end (as in the prototype).
// The dither then turns the ink into dots.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;   // no light; seen from both sides; hides nothing behind it

uniform float progress = 0.0;       // 0 = just born, 1 = gone (wind_lines.gd counts it up)
uniform float plane_length = 6.0;   // the rectangle's size in metres (the same as its mesh)
uniform float plane_width = 0.8;
uniform float line_width = 0.12;    // how thick the line is, in metres
uniform float wave_height = 0.2;    // how far the line bends to either side, in metres
uniform float wave_length = 9.0;    // metres for one whole bend there and back
uniform float seed = 0.0;           // a different number for each line, so they don't all bend alike
uniform float alpha = 0.85;         // how dark the ink is

void fragment() {
	// 1. Where this pixel is on the rectangle, in metres: along the line and across it (0 = the middle).
	float along = UV.x * plane_length;
	float across = (UV.y - 0.5) * plane_width;

	// 2. The line's middle at this point: a slow bend, plus a slight ripple that moves with time.
	float bend = wave_height * sin(along / wave_length * 6.2832 + seed);
	float ripple = 0.04 * sin(TIME * 3.0 + along * 4.0 + seed);
	float distance_to_line = abs(across - (bend + ripple));

	// 3. Which part of the line is showing now: the head runs ahead first, then the tail follows.
	float head = min(1.0, progress / 0.55);
	float tail = max(0.0, (progress - 0.45) / 0.55);

	// 4. Ink only on the line, and only between the tail and the head.
	if (distance_to_line > line_width * 0.5 || UV.x < tail || UV.x > head) {
		discard;
	}
	float fade = min(1.0, min(progress * 9.0, (1.0 - progress) * 9.0));   // quick fade in and out
	ALBEDO = vec3(0.0);
	ALPHA = alpha * fade;
}
