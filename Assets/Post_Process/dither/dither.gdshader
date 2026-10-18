// 1-bit look: ordered dither (Bayer 4x4) of everything on screen to two colours,
// paper and ink, like the HTML prototype. Used by dither.tscn (a CanvasLayer over the game).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 paper_color : source_color = vec4(0.922, 0.906, 0.863, 1.0); // #ebe7dc
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.090, 1.0);   // #1b1a17
// The grain: how many game pixels (the 360 x 800 design screen) one dot covers. 1 = a dot per game pixel.
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
const vec2 DESIGN_SIZE = vec2(360.0, 800.0);   // the game's screen size in the project settings
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;     // shifts the greys before dithering
uniform float contrast : hint_range(0.2, 3.0) = 1.0;

const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	// How many real screen pixels make one game pixel. On the PC editor window (360 x 800) it's 1; a phone
	// draws at its full resolution (about 1080 wide), so 3: without this the dots would be one tiny real
	// pixel each and melt into grey. On an upright screen the width counts (the camera keeps the world's
	// width, so it's always 360 dots across; the browser's bars eat the height, which would give a smaller
	// number); on a wide screen the smaller of the two sides. Rounded, so every dot is the same size.
	// (dither.gd does the same sum for the 3D resolution: keep the two alike.)
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 ratio = screen_size / DESIGN_SIZE;
	float side = screen_size.y >= screen_size.x ? ratio.x : min(ratio.x, ratio.y);
	float scale = max(1.0, round(side));
	float dot_size = pixel_size * scale;   // real screen pixels per dot
	// One block of dot_size x dot_size screen pixels = one dot.
	vec2 block = floor(FRAGCOORD.xy / dot_size);
	vec2 uv = (block + 0.5) * dot_size * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, uv).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	grey = clamp((grey - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0);
	ivec2 b = ivec2(mod(block, 4.0));
	float threshold = (BAYER[b.y * 4 + b.x] + 0.5) / 16.0;
	COLOR = grey > threshold ? paper_color : ink_color;
}
