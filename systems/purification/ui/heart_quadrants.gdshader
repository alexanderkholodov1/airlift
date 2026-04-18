shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 ira_color : source_color = vec4(0.87, 0.22, 0.20, 1.0);
uniform vec4 pereza_color : source_color = vec4(0.96, 0.68, 0.24, 1.0);
uniform vec4 gula_color : source_color = vec4(0.29, 0.72, 0.85, 1.0);
uniform vec4 soberbia_color : source_color = vec4(0.74, 0.39, 0.82, 1.0);
uniform vec4 empty_color : source_color = vec4(0.16, 0.10, 0.10, 1.0);
uniform vec4 outline_color : source_color = vec4(0.98, 0.93, 0.89, 0.95);

uniform float ira : hint_range(0.0, 1.0) = 0.0;
uniform float pereza : hint_range(0.0, 1.0) = 0.0;
uniform float gula : hint_range(0.0, 1.0) = 0.0;
uniform float soberbia : hint_range(0.0, 1.0) = 0.0;

uniform float edge_softness : hint_range(0.001, 0.030) = 0.007;
uniform float outline_thickness : hint_range(0.001, 0.050) = 0.013;


float heart_function(vec2 p) {
	// Implicit heart equation: values <= 0 are inside.
	float x2 = p.x * p.x;
	float y2 = p.y * p.y;
	float part = x2 + y2 - 1.0;
	return part * part * part - x2 * p.y * p.y * p.y;
}


void fragment() {
	vec2 uv = UV;
	vec2 p = uv * 2.0 - 1.0;
	p.y *= -1.0;
	p *= 1.25;
	p.y += 0.08;

	float heart = heart_function(p);
	float mask = smoothstep(edge_softness, -edge_softness, heart);

	float metric = 0.0;
	vec4 tint = empty_color;

	if (uv.x < 0.5 && uv.y >= 0.5) {
		metric = ira;
		tint = ira_color;
	} else if (uv.x < 0.5 && uv.y < 0.5) {
		metric = pereza;
		tint = pereza_color;
	} else if (uv.x >= 0.5 && uv.y >= 0.5) {
		metric = gula;
		tint = gula_color;
	} else {
		metric = soberbia;
		tint = soberbia_color;
	}

	vec2 local_quad_uv = vec2(fract(uv.x * 2.0), fract(uv.y * 2.0));
	float height_from_bottom = 1.0 - local_quad_uv.y;
	float fill = smoothstep(metric + 0.018, metric - 0.018, height_from_bottom);

	vec4 base_color = mix(empty_color, tint, fill);
	float border = smoothstep(outline_thickness, outline_thickness * 0.35, abs(heart));
	vec4 final_color = mix(base_color, outline_color, border * 0.8);
	final_color.a *= mask;

	COLOR = final_color;
}
