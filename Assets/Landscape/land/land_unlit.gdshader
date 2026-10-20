// LAND, UNLIT: a material for the land's drawings (faraglioni, islands…): the picture as it is, with no light
// (the scene has none, so a lit material comes out black), and each pixel either solid or nothing, cut by the
// picture's alpha ("alpha scissor"). The solid pixels go into the depth buffer, so they hide what's behind them
// and get the ink outline round them; the dither turns the greys into dots.
// (In Unreal: an Unlit material with Blend Mode Masked, the texture into Emissive Color and Opacity Mask.)
shader_type spatial;
render_mode unshaded, cull_disabled;   // no light; both faces shown

uniform sampler2D picture : source_color, filter_nearest;   // the drawing (nearest: crisp pixels, not blurred)
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;       // less solid than this = see-through
uniform vec4 tint : source_color = vec4(1.0);               // multiplies the picture's colour (white = as drawn)

void fragment() {
	vec4 colour = texture(picture, UV);
	if (colour.a < alpha_cut) {
		discard;   // nothing here: what's behind shows through
	}
	ALBEDO = colour.rgb * tint.rgb;
}
