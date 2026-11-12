// Контур «как карандашом»: меш чуть раздувается вдоль нормалей
// и рисуется изнанкой тёмно-коричневым. Толщина почти не зависит от расстояния.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.17, 0.11, 0.08, 1.0);
uniform float width = 0.022;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = clamp(-view_pos.z, 1.0, 60.0);
	VERTEX += NORMAL * width * (0.55 + dist * 0.045);
}

void fragment() {
	ALBEDO = ink.rgb;
}
