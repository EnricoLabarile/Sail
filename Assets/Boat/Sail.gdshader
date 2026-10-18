// THE SAIL: the cloth ripples a little, as if the wind shook it.
shader_type spatial;
// both faces visible (what cull_mode did on the old material); unshaded: no lights in the scene, the fake sun
// below shades it instead (fake_light.gdshaderinc, the same sun as the clouds' shadows)
render_mode cull_disabled, unshaded;

#include "res://Assets/Boat/fake_light.gdshaderinc"

// The knobs, shown in the Inspector (like a Material Instance's parameters).
uniform vec4 sail_color : source_color = vec4(0.53, 0.53, 0.53, 1.0);
uniform float flutter = 0.05;       // how far the cloth moves, in metres
uniform float speed = 4.0;          // how fast the ripples run
uniform float wave_length = 1;    // how many ripples fit on the sail

// vertex() runs once for every point of the mesh: here we move it.
// (In Unreal: World Position Offset.)
void vertex() {
		// How free this point is, from the colour painted on the mesh in Blender:
	// black (0) at the mast = still, white (1) at the free edge = moves the most.
	float free = COLOR.r;
	// A wave running along the sail: a sine of time and of where the point is.
	float wave = sin(TIME * speed + VERTEX.y * wave_length);
	// Push the point out of the cloth (along its NORMAL) by the wave.
	VERTEX += NORMAL * wave * flutter * free;
}

// fragment() runs for every pixel: the colour, shaded by the fake sun. The sail is seen from both sides:
// on its back face the normal points away from us, so it's turned round (FRONT_FACING is false there).
void fragment() {
	vec3 normal = FRONT_FACING ? NORMAL : -NORMAL;
	ALBEDO = sail_color.rgb * fake_light(normal, INV_VIEW_MATRIX);
}	