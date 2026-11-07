// THE BOAT'S PLAIN MATERIAL (hull, mast): one colour, shaded by the fake sun (fake_light.gdshaderinc).
// Unshaded: it doesn't need any light in the scene (there is none).
shader_type spatial;
render_mode unshaded;

#include "res://Assets/Boat/fake_light.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.906, 0.906, 0.906, 1.0);   // the colour in full sun
// Only for the boat sheet's bake (Assets/Boat/boat_sprite/boat_sprite.gd, Enrico, Nov 2026): on, nothing below the
// water line (world height water_level) is drawn, as the sea hides it in the game. Off in the game.
uniform bool cut_below_water = false;
uniform float water_level = 0.0;

varying float world_height;   // how high this point is in the world (worked out per corner, blended per pixel)

void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (cut_below_water && world_height < water_level) {
		discard;
	}
	ALBEDO = base_color.rgb * fake_light(NORMAL, INV_VIEW_MATRIX);
}
