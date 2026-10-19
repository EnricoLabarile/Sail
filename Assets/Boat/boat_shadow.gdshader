// THE BOAT'S SHADOW on the water (a "planar shadow"): every mesh of the boat is drawn a second time, squashed
// flat onto the sea, each point slid away from the sun by as much as it stands above the water. So the mast
// makes a long thin shadow, the hull a short wide one, and the sail's follows the boom as it swings.
// The direction is the clouds' shadows' one (the global sun_direction, set by clouds.gd); how long it is, is
// boat.gd's shadow_slant. Ink, see-through (shadow_opacity): the dither turns it into dots, like the clouds'.
// boat.gd puts it on the boat's meshes as a material_overlay (add_shadow), so it follows her every movement.
// (In Unreal: a second "planar shadow" material drawn on the same mesh.)
shader_type spatial;
// unshaded: no light; depth_draw_never: changes no depth; cull_disabled: both faces count.
render_mode unshaded, depth_draw_never, cull_disabled;
// The stencil: draw only where it isn't 2 yet, and write 2. So where the hull, mast and sail's shadows overlap,
// the water is darkened once, not two or three times over. (1 is the boat's inner mask, boat_mask.gdshader.)
stencil_mode read, write, compare_not_equal, 2;

// Toward the sun: a global shader parameter (Project Settings > Shader Globals), set by clouds.gd, the same
// sun that lights the boat (fake_light.gdshaderinc) and casts the clouds' shadows.
global uniform vec3 sun_direction;

uniform float shadow_slant = 0.5;     // metres the shadow slides sideways for every metre of height
uniform float shadow_opacity = 0.6;   // 0 = no shadow, 1 = solid ink

void vertex() {
	// 1. This point of the boat, in the world, and how high it stands above the water.
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = max(world.y, 0.0);
	// 2. Which way the shadow falls on the water: away from the sun, flat (only x and z).
	vec2 away_from_sun = -normalize(sun_direction.xz);
	// 3. Slide it that way, the higher the further, and lay it on the sea (a hair above it).
	vec2 on_water = world.xz + away_from_sun * height * shadow_slant;
	vec3 shadow_point = vec3(on_water.x, 0.01, on_water.y);
	// 4. Onto the screen, as the camera sees it.
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(shadow_point, 1.0);
}

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = shadow_opacity;
}
