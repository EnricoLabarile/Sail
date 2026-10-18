// A CLOUD, cut out in dots: every pixel is either cloud or what's under it, never a mix (1-bit, like the
// rest). Where the picture is half see-through (its soft edge), only some of its pixels are kept, in the same
// 4 x 4 Bayer pattern as the dither (dither.gdshader): the edge stays soft, made of dots.
// Being solid (not see-through), it's drawn with the solid things: no blending, no sorting.
// (In Unreal: a Masked material with a dithered opacity mask.)
// The cloud map for the shadows doesn't use this: it sees soft copies of the clouds (clouds.gd).
shader_type spatial;
render_mode unshaded, cull_disabled;   // no light on it; both faces drawn

uniform sampler2D cloud_tex : source_color, filter_linear_mipmap;   // the cloud's picture (its alpha = how solid)
uniform float opacity : hint_range(0.0, 1.0) = 1.0;                 // less = fewer dots kept: a thinner cloud

// The 4 x 4 Bayer pattern: 16 thresholds spread evenly, so any share of the pixels can be kept as even dots.
const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	vec4 picture = texture(cloud_tex, UV);
	// This pixel's threshold, from where it is on the screen (its cell in the 4 x 4 pattern).
	ivec2 cell = ivec2(mod(floor(FRAGCOORD.xy), 4.0));
	float threshold = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0;
	// Less solid than its threshold: not drawn here (the sea shows through).
	if (picture.a * opacity < threshold) {
		discard;
	}
	ALBEDO = picture.rgb;
}
