// LAND, UNLIT: a material for the land's drawings (faraglioni, islands…): the picture as it is, with no light
// (the scene has none, so a lit material comes out black), and each pixel either solid or nothing, cut by the
// picture's alpha ("alpha scissor"); they hide what's behind them; the dither turns the greys into dots.
// (In Unreal: an Unlit material with Blend Mode Masked, the texture into Emissive Color and Opacity Mask.)
// NO INK OUTLINE (Enrico): the outline (boat_outline.gdshader) is drawn round whatever is in the depth buffer, so
// this doesn't write depth (depth_draw_never) and is drawn with the see-through things (ALPHA = 1.0), after the
// solid ones like the boat. It still tests the depth: the boat in front of it stays in front, the boat behind it is
// covered. Its material's render_priority is 2: after the sea, the wake and the wind lines (1), before the fog (3).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;   // no light; both faces shown; no depth (no outline)

uniform sampler2D picture : source_color, filter_nearest;   // the drawing (nearest: crisp pixels, not blurred)
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;       // less solid than this = see-through
uniform vec4 tint : source_color = vec4(1.0);               // multiplies the picture's colour (white = as drawn)

void fragment() {
	vec4 colour = texture(picture, UV);
	if (colour.a < alpha_cut) {
		discard;   // nothing here: what's behind shows through
	}
	ALBEDO = colour.rgb * tint.rgb;
	ALPHA = 1.0;   // drawn with the see-through things (see the notes at the top): solid where drawn, but no outline
}
