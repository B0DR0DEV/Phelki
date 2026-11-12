// Мультяшный свет: две ступени освещённости, мягкая граница тени,
// лёгкая подсветка по краю. Цвет — из цвета вершин (склеенные меши)
// или из tint (отдельные детали).
shader_type spatial;

uniform vec4 tint : source_color = vec4(1.0);
// Блик: 0 — матовое, 1 — глянец (стекло, мёд, золото)
uniform float gloss = 0.0;
// Отёк дачника: краснит только «кожу» (вершины с альфой 0)
uniform float flush = 0.0;
uniform vec4 flush_color : source_color = vec4(0.93, 0.36, 0.34, 1.0);
uniform float rim_strength = 0.16;

void fragment() {
	vec3 c = COLOR.rgb * tint.rgb;
	if (COLOR.a < 0.5) {
		c = mix(c, flush_color.rgb, flush);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = c * smoothstep(0.6, 0.9, edge) * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Две ступени: тень / полутон / свет
	float lit = smoothstep(-0.05, 0.05, ndl);
	float full = smoothstep(0.38, 0.46, ndl);
	float band = lit * mix(0.62, 1.0, full);
	float sh = smoothstep(0.3, 0.6, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * band * sh * (0.72 / PI);
	if (gloss > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float s = smoothstep(0.92, 0.95, dot(NORMAL, h)) * sh;
		SPECULAR_LIGHT += LIGHT_COLOR * s * gloss * 0.25;
	}
}
