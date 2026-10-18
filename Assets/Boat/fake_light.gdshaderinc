// FAKE LIGHT: a piece of shader shared by the boat's materials (in Unreal: a Material Function).
// There are no lights in the scene: everything is drawn unshaded and dithered to paper and ink. So the boat
// shades herself: the side facing the "sun" is light, the side away from it darker.
// The sun is the same one that casts the clouds' shadows: `sun_direction` is a global shader parameter
// (Project Settings > Shader Globals, like a Material Parameter Collection in Unreal), set by clouds.gd
// from the clouds' shadow_offset and height. It points toward the sun (north-west and high up).

global uniform vec3 sun_direction;
uniform float ambient : hint_range(0.0, 1.0) = 0.45;   // how light the side away from the sun still is (0 = black)

// How lit a point is, 0..1: `ambient` in full shade, 1 facing the sun straight on.
// view_normal: the surface's normal as the fragment shader gets it (NORMAL, in camera space);
// inv_view: INV_VIEW_MATRIX, to turn it into the world's directions, where the sun is.
float fake_light(vec3 view_normal, mat4 inv_view) {
	vec3 normal = normalize((inv_view * vec4(view_normal, 0.0)).xyz);
	float facing = max(0.0, dot(normal, normalize(sun_direction)));   // 1 = facing the sun, 0 = side-on or away
	return ambient + (1.0 - ambient) * facing;
}
