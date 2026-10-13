// 1-bit look: ordered dither (Bayer 4x4) of everything on screen to two colours,
// paper and ink, like the HTML prototype. Used by dither.tscn (a CanvasLayer over the game).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 paper_color : source_color = vec4(0.922, 0.906, 0.863, 1.0); // #ebe7dc
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.090, 1.0);   // #1b1a17
uniform float pixel_size : hint_range(0.25, 4.0, 0.01) = 0.67; // the grain, in phone points (the game's 360-wide units), so it looks the same on the phone and on the PC
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;     // shifts the greys before dithering
uniform float contrast : hint_range(0.2, 3.0) = 1.0;

const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	// How many real pixels make a phone point here (3 on a 1080-wide phone, 1 in a 360x800 window),
	// so the grain is the same size on any screen; one block = one game pixel.
	vec2 real = 1.0 / SCREEN_PIXEL_SIZE;
	float k = min(real.x / 360.0, real.y / 800.0);
	float px = max(1.0, floor(pixel_size * k + 0.5));
	vec2 block = floor(FRAGCOORD.xy / px);
	vec2 uv = (block + 0.5) * px * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, uv).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	grey = clamp((grey - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0);
	ivec2 b = ivec2(mod(block, 4.0));
	float threshold = (BAYER[b.y * 4 + b.x] + 0.5) / 16.0;
	COLOR = grey > threshold ? paper_color : ink_color;
}
