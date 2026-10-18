// THE CLOUDS' SHADOWS, as a screen effect (like a post-process material in Unreal): a rectangle stretched
// over the whole screen, drawn after the sea, the coasts and the boat, but before the clouds themselves.
// It darkens whatever is under a cloud: sea, land and boat alike.
//
// clouds.gd makes it, and gives it the "cloud map": a small picture of the clouds seen from straight above
// (a SubViewport with a camera looking down that sees only the clouds, like a Scene Capture 2D in Unreal).
//
// For each pixel of the screen:
//   1. find the point of the world it shows: on something solid (land, boat) from the depth buffer,
//      otherwise on the water, following the line of sight down to height 0 (as the fog does);
//   2. from that point go up toward the "sun" to the clouds' height: is there a cloud there in the map?
//   3. if so, darken the pixel, as much as the cloud is solid there (its picture's alpha) × shadow_opacity.
// Taller things reach the clouds sooner, so their shadow falls shifted, as a real shadow would.
shader_type spatial;
// unshaded: no light; depth_test_disabled: drawn over everything; depth_draw_never: changes no depth.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled;

// The depth of what's on screen (0.0 = nothing solid there, only the see-through sea).
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// The cloud map from above (clouds.gd): alpha = how solid the cloud is there.
uniform sampler2D cloud_map : filter_linear, hint_default_transparent;
uniform vec2 map_center = vec2(0.0, 0.0);   // where the cloud map's middle is on the sea (x, z), in metres
uniform float map_size = 160.0;             // metres the cloud map covers, a side
uniform float cloud_height = 15.0;          // the clouds' height (clouds.gd height)
// How far the shadow moves sideways for every metre of height it falls (the sun's slant), on x and z.
uniform vec2 sun_shift = vec2(0.27, 0.27);
uniform float shadow_opacity = 0.35;        // how dark under a solid cloud: 0 = no shadow, 1 = black

void vertex() {
	// Stretch the rectangle (a 1 x 1 QuadMesh, corners at -0.5 and 0.5) over the whole screen.
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

// A point of the screen at a given depth, back in the world (in metres).
vec3 screen_to_world(vec2 ndc, float z, mat4 inv_projection, mat4 inv_view) {
	vec4 view = inv_projection * vec4(ndc, z, 1.0);
	view.xyz /= view.w;
	return (inv_view * vec4(view.xyz, 1.0)).xyz;
}

void fragment() {
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	// 1. The point of the world this pixel shows.
	vec3 point;
	float depth = texture(depth_tex, SCREEN_UV).r;
	if (depth > 0.0) {
		// Something solid here (land, boat): its depth tells where it is (the Compatibility renderer's way).
		point = screen_to_world(ndc, depth * 2.0 - 1.0, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	} else {
		// Only sea: follow the line of sight through this pixel down to the water (height 0), as the fog does.
		vec3 a = screen_to_world(ndc, 0.0, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
		vec3 b = screen_to_world(ndc, 1.0, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
		point = mix(a, b, a.y / (a.y - b.y));
	}
	// 2. Up toward the sun to the clouds' height: the shadow falls shifted by sun_shift a metre of drop,
	//    so the cloud over this point is back the other way, by the height still to climb.
	vec2 cloud_spot = point.xz - sun_shift * (cloud_height - point.y);
	// 3. That spot on the cloud map (its middle is map_center; the top of the picture is north, -z).
	vec2 uv = (cloud_spot - map_center) / map_size + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;   // outside the map: no shadow
	}
	float cloud = texture(cloud_map, uv).a;
	// 4. Darken: ink, as strong as the cloud is solid there.
	ALBEDO = vec3(0.0);
	ALPHA = cloud * shadow_opacity;
}
