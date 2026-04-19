shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 ira_color : source_color = vec4(0.87, 0.22, 0.20, 1.0);
uniform vec4 pereza_color : source_color = vec4(0.96, 0.68, 0.24, 1.0);
uniform vec4 gula_color : source_color = vec4(0.29, 0.72, 0.85, 1.0);
uniform vec4 soberbia_color : source_color = vec4(0.74, 0.39, 0.82, 1.0);
uniform vec4 empty_color : source_color = vec4(0.16, 0.10, 0.10, 1.0);
uniform vec4 outline_color : source_color = vec4(0.98, 0.93, 0.89, 0.95);
uniform vec4 divider_color : source_color = vec4(1.00, 0.97, 0.92, 1.0);

uniform float ira : hint_range(0.0, 1.0) = 0.0;
uniform float pereza : hint_range(0.0, 1.0) = 0.0;
uniform float gula : hint_range(0.0, 1.0) = 0.0;
uniform float soberbia : hint_range(0.0, 1.0) = 0.0;

uniform vec2 pixel_grid_size = vec2(54.0, 54.0);
uniform float heart_scale : hint_range(0.80, 1.80) = 1.25;
uniform float heart_y_offset : hint_range(-0.40, 0.40) = 0.08;
uniform float divider_thickness : hint_range(0.005, 0.060) = 0.018;


float heart_function(vec2 p) {
	// Implicit heart equation: values <= 0 are inside.
	float x2 = p.x * p.x;
	float y2 = p.y * p.y;
	float part = x2 + y2 - 1.0;
	return part * part * part - x2 * p.y * p.y * p.y;
}


vec2 pixelate_uv(vec2 uv) {
	vec2 snapped = floor(uv * pixel_grid_size) + vec2(0.5);
	return snapped / pixel_grid_size;
}


vec2 to_heart_space(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	p.y *= -1.0;
	p *= heart_scale;
	p.y += heart_y_offset;
	return p;
}


float heart_fn_uv(vec2 uv) {
	return heart_function(to_heart_space(clamp(uv, vec2(0.0), vec2(1.0))));
}


float inside_at(vec2 uv) {
	if (heart_fn_uv(uv) <= 0.0) {
		return 1.0;
	}
	return 0.0;
}


void fragment() {
	vec2 uv = pixelate_uv(UV);
	float inside = inside_at(uv);
	if (inside < 0.5) {
		COLOR = vec4(0.0);
		return;
	}

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
	float fill = 0.0;
	if (metric >= height_from_bottom) {
		fill = 1.0;
	}

	vec4 base_color = mix(empty_color, tint, fill);

	float v_divider = 1.0 - step(divider_thickness + 0.0001, abs(uv.x - 0.5));
	float h_divider = 1.0 - step(divider_thickness + 0.0001, abs(uv.y - 0.5));
	float divider = max(v_divider, h_divider) * inside;
	base_color = mix(base_color, divider_color, divider);

	vec2 px = 1.0 / pixel_grid_size;
	float neighbors =
		inside_at(uv + vec2(px.x, 0.0))
		+ inside_at(uv - vec2(px.x, 0.0))
		+ inside_at(uv + vec2(0.0, px.y))
		+ inside_at(uv - vec2(0.0, px.y));
	float outline = 0.0;
	if (inside > 0.5 && neighbors < 4.0) {
		outline = 1.0;
	}

	vec4 final_color = mix(base_color, outline_color, outline);
	final_color.a = inside;

	COLOR = final_color;
}
