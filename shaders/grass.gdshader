// Пучки травы (MultiMesh): качаются на ветру, цвет — у каждого пучка свой.
shader_type spatial;
render_mode cull_disabled;

uniform float sway = 0.12;

void vertex() {
	float h = clamp(VERTEX.y / 0.35, 0.0, 1.0);
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 1.7 + w.x * 0.35 + w.z * 0.27;
	VERTEX.x += sin(t) * sway * h * h;
	VERTEX.z += cos(t * 0.8) * sway * 0.6 * h * h;
}

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0);
	ALBEDO = COLOR.rgb * mix(0.72, 1.15, h);
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = abs(dot(NORMAL, LIGHT));
	float sh = smoothstep(0.3, 0.6, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * mix(0.7, 1.0, step(0.2, ndl)) * sh * (0.72 / PI);
}
