shader_type canvas_item;
render_mode unshaded;

// Tiny local UV ripples; the footprint and its stone edge remain stationary.
uniform vec2 region_min = vec2(0.333333, 0.0);
uniform vec2 region_size = vec2(0.333333);
uniform float strength : hint_range(0.0, 0.01) = 0.0012;
varying vec4 surface_color;

void vertex() {
	surface_color = COLOR;
}

void fragment() {
	vec2 local_uv = (UV - region_min) / region_size;
	float edge = smoothstep(0.12, 0.23, min(min(local_uv.x, 1.0-local_uv.x), min(local_uv.y, 1.0-local_uv.y)));
	vec2 ripple = vec2(sin(local_uv.y*42.0 + TIME*0.7), cos(local_uv.x*37.0 - TIME*0.55))*strength*edge;
	vec2 sample_uv = clamp(UV+ripple, region_min+vec2(0.001), region_min+region_size-vec2(0.001));
	COLOR = texture(TEXTURE, sample_uv) * surface_color;
}
