// THE BOAT'S PLAIN MATERIAL (hull, mast): one colour, shaded by the fake sun (fake_light.gdshaderinc).
// Unshaded: it doesn't need any light in the scene (there is none).
shader_type spatial;
render_mode unshaded;

#include "res://Assets/Boat/fake_light.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.906, 0.906, 0.906, 1.0);   // the colour in full sun

void fragment() {
	ALBEDO = base_color.rgb * fake_light(NORMAL, INV_VIEW_MATRIX);
}
