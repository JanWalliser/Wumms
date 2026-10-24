shader_type canvas_item;
render_mode unshaded;

float continue_edge(float coordinate) {
	// Mirror a narrow edge strip repeatedly, never the distant map interior.
	float distance_outside = max(-coordinate, coordinate - 1.0);
	float fold = 0.20 - abs(mod(max(distance_outside, 0.0), 0.40) - 0.20);
	if (coordinate < 0.0) { return fold; }
	if (coordinate > 1.0) { return 1.0 - fold; }
	return coordinate;
}

void fragment() {
	// Below the map, retain the actual water at the southern texture edge.
	vec2 sample_uv = vec2(continue_edge(UV.x), UV.y < 0.0 ? continue_edge(UV.y) : min(UV.y, 0.9999));
	COLOR = texture(TEXTURE, clamp(sample_uv, vec2(0.0001), vec2(0.9999)));
}
