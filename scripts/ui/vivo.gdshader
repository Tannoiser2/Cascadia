// Movimento delle miniature senza scheletro: le ali del falco battono, la coda del salmone guizza.
// I vertici sono nello spazio del modello Meshy (falco: ali lungo X; salmone: corpo lungo Z).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform int mode = 0;            // 1 = ali, 2 = coda
uniform float half_w = 1.0;      // metà dell'apertura alare / della lunghezza
uniform float speed = 6.0;
uniform float amp = 0.3;
uniform float phase = 0.0;
uniform float floor_y = -100.0;  // sotto questa quota (mondo) il modello non si vede: il salmone «sott'acqua»

varying vec3 wpos;

void vertex() {
	float t = TIME * speed + phase;
	if (mode == 1) {
		float k = clamp(abs(VERTEX.x) / half_w, 0.0, 1.0);
		VERTEX.y += sin(t) * amp * k * k * half_w;
	} else if (mode == 2) {
		float k = clamp((VERTEX.z + half_w) / (2.0 * half_w), 0.0, 1.0);   // 0 a un capo, 1 all'altro
		float w = 1.0 - k;                                                   // la coda guizza di più
		VERTEX.x += sin(t + VERTEX.z * 3.0) * amp * w * w * half_w;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (wpos.y < floor_y) {
		discard;
	}
	ALBEDO = texture(albedo_tex, UV).rgb;
	ROUGHNESS = 0.85;
}
