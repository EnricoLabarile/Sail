// THE SAIL: the cloth ripples a little, as if the wind shook it.
shader_type spatial;
render_mode cull_disabled;   // both faces visible (what cull_mode did on the old material)

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

// fragment() runs for every pixel: here only the colour.
void fragment() {
	ALBEDO = sail_color.rgb;
}	