// AN ISLAND'S PICTURE: Enrico's drawing of the island seen slightly from the side (3/4 view: the shore in front at
// the bottom, the hills rising up the picture), on a card that faces the camera (island.gd turns it).
// Each pixel is either solid or nothing (cut by the picture's alpha, "alpha scissor"): the solid ones are drawn
// like any solid thing and go into the depth buffer, so the boat passing behind the island is hidden by it, and
// the ink outline (boat_outline.gdshader, the screen effect that reads the depth) is drawn round it for free.
// No light: the drawing's own greys, which the dither turns into dots. (In Unreal: an unlit Masked material.)
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D picture : source_color, filter_nearest;   // the island's drawing (nearest: crisp pixels)
uniform float alpha_cut = 0.5;   // pixels less solid than this are left out (see-through)

void fragment() {
	vec4 colour = texture(picture, UV);
	if (colour.a < alpha_cut) {
		discard;   // nothing here: the sea (or whatever is behind) shows
	}
	ALBEDO = colour.rgb;
}
