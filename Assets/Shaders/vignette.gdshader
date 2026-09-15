shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.9, 0.05, 0.05, 1.0);
uniform float inner_radius : hint_range(0.0, 1.5) = 0.45;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.15;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 1.414;
	float alpha = smoothstep(inner_radius, outer_radius, dist) * intensity;
	COLOR = vec4(vignette_color.rgb, alpha * vignette_color.a);
}
