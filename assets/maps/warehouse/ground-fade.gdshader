shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 edge = min(UV, vec2(1.0)-UV);
	COLOR.a *= smoothstep(0.0, 0.07, min(edge.x,edge.y));
}
