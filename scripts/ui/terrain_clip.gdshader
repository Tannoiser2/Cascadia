// Diorama di habitat ritagliato: solo la parte dentro l'esagono della tessera, dentro l'arco
// [a0, a0 + span] (lati della tessera con quell'habitat) e sopra la base.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 center;
uniform float radius = 1.0;
uniform float a0 = 0.0;
uniform float span = 7.0;
uniform float ground = 0.0;
uniform vec3 tint = vec3(1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 d = wpos.xz - center.xz;
	if (wpos.y < ground) {
		discard;
	}
	float apo = radius * 0.8660254;
	for (int k = 0; k < 3; k++) {
		float a = float(k) * 1.0471976;
		if (abs(dot(d, vec2(cos(a), sin(a)))) > apo) {
			discard;
		}
	}
	if (span < 6.2) {
		float ang = atan(d.y, d.x);
		float rel = mod(ang - a0, 6.2831853);
		if (rel > span) {
			discard;
		}
	}
	ALBEDO = clamp(texture(albedo_tex, UV).rgb * tint, 0.0, 1.0);
	ROUGHNESS = 0.92;
}
