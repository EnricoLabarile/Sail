// TILT-SHIFT (Enrico, Nov 2026): the top and the bottom of the world are blurred, more and more toward the edge,
// so the sea looks like a little model (a miniature). In Unreal: a post-process material with a vertical gradient mask.
// It sits on a ColorRect over the whole game view, on a CanvasLayer (90) that game_view.gd makes at start: under the
// controls (95: wheel, lever, logbook's button) so they stay sharp, and under the dither (100), which then turns the
// blurred greys into its dots. Its numbers are on the GameView node (tilt_*), sent here by game_view.gd.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;   // the world as drawn so far
uniform float top_band = 0.35;     // how much of the screen's height, from the top, is blurred (0 = none)
uniform float bottom_band = 0.4;   // the same, from the bottom
uniform float blur_pixels = 6.0;   // how far the blur reaches at the very edge, in game-view pixels

void fragment() {
	vec2 uv = SCREEN_UV;
	// 1. How blurred this row is, 0..1: 0 in the sharp middle, rising to 1 at the top or bottom edge.
	float from_top = top_band > 0.0 ? clamp(1.0 - uv.y / top_band, 0.0, 1.0) : 0.0;
	float from_bottom = bottom_band > 0.0 ? clamp(1.0 - (1.0 - uv.y) / bottom_band, 0.0, 1.0) : 0.0;
	float amount = max(from_top, from_bottom);
	amount = amount * amount;   // eased: it starts gently and grows toward the edge

	// 2. The blur: the picture here plus 12 samples on two rings round it (8 near, 4 far), averaged.
	//    Where amount is 0 the rings shrink to nothing: just the picture as it is.
	vec2 step_size = SCREEN_PIXEL_SIZE * blur_pixels * amount;
	vec3 sum = texture(screen_tex, uv).rgb;
	float count = 1.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;   // 8 directions, every 45 degrees
		sum += texture(screen_tex, uv + vec2(cos(a), sin(a)) * step_size * 0.5).rgb;
		count += 1.0;
	}
	for (int i = 0; i < 4; i++) {
		float a = float(i) * 1.570796 + 0.785398;   // 4 diagonals, further out
		sum += texture(screen_tex, uv + vec2(cos(a), sin(a)) * step_size).rgb;
		count += 1.0;
	}
	COLOR = vec4(sum / count, 1.0);
}
