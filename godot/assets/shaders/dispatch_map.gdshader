shader_type canvas_item;
// Tinte HUD tactico tipo Dispatch: mapa oscuro + linea verde neon.

uniform vec4 base_tint : source_color = vec4(0.04, 0.12, 0.08, 1.0);
uniform vec4 line_tint : source_color = vec4(0.25, 0.95, 0.55, 1.0);
uniform float contrast : hint_range(0.5, 2.5) = 1.55;
uniform float edge_boost : hint_range(0.0, 2.0) = 0.85;
uniform float darkness : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	luma = clamp((luma - 0.08) * contrast, 0.0, 1.0);

	// Resaltar bordes / estructuras claras como wireframe
	vec2 px = 1.0 / vec2(textureSize(TEXTURE, 0));
	float n = texture(TEXTURE, UV + vec2(0.0, -px.y)).r;
	float s = texture(TEXTURE, UV + vec2(0.0, px.y)).r;
	float e = texture(TEXTURE, UV + vec2(px.x, 0.0)).r;
	float w = texture(TEXTURE, UV + vec2(-px.x, 0.0)).r;
	float edge = abs(n - s) + abs(e - w);
	edge = clamp(edge * 4.5, 0.0, 1.0);

	float mix_w = clamp(luma * 0.65 + edge * edge_boost, 0.0, 1.0);
	vec3 col = mix(base_tint.rgb, line_tint.rgb, mix_w);
	col = mix(col, col * (1.0 - darkness), 0.55);
	col = mix(vec3(0.015, 0.04, 0.03), col, 0.92);
	COLOR = vec4(col, src.a);
}
