shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Outer ground of the operation area. A flat grid is displaced by the
// surveyed relief: vertices land exactly on the 20 m nodes, so the drawn
// triangles are the collision heightmap's triangles. Land cover is sampled
// between the nodes; the battlefield in the middle has its own ground.
uniform sampler2D relief : filter_nearest, repeat_disable;
uniform sampler2D cover : source_color, filter_linear, repeat_disable;
// The battlefield ground's grain texture (noise ramped to 0.65–1).
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform sampler2D forest : filter_nearest, repeat_disable;
uniform float half_size = 6000.0;
uniform float grid_step = 20.0;
uniform float inner = 200.0;
uniform int nodes = 601;
// 0: bare ground; 1: far canopy of the woods, raised over forested nodes.
uniform float canopy = 0.0;
varying vec2 ground_xz;
varying float wood;

float node_height(ivec2 n) {
	n = clamp(n, ivec2(0), ivec2(nodes - 1));
	float h = texelFetch(relief, n, 0).r;
	if (canopy > 0.5) {
		float jitter = fract(sin(dot(vec2(n), vec2(12.9898, 78.233))) * 43758.5453);
		h += texelFetch(forest, n, 0).r > 0.5 ? 12.0 + jitter * 5.0 : 0.4;
	}
	return h;
}

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	ivec2 n = ivec2(round((world + half_size) / grid_step));
	vec2 exact = vec2(n) * grid_step - half_size;
	VERTEX.xz += exact - world;
	VERTEX.y = node_height(n);
	NORMAL = normalize(vec3(node_height(n - ivec2(1, 0)) - node_height(n + ivec2(1, 0)), 2.0 * grid_step, node_height(n - ivec2(0, 1)) - node_height(n + ivec2(0, 1))));
	ground_xz = exact;
	wood = texelFetch(forest, clamp(n, ivec2(0), ivec2(nodes - 1)), 0).r > 0.5 ? 1.0 : 0.0;
}

void fragment() {
	float margin = canopy > 0.5 ? 20.0 : 0.0;
	if (abs(ground_xz.x) < inner + margin && abs(ground_xz.y) < inner + margin) {
		discard;
	}
	float g = texture(grain, ground_xz * 0.35).r;
	if (canopy > 0.5) {
		if (wood < 0.02) {
			discard;
		}
		float patch = texture(grain, ground_xz * 0.013).r;
		ALBEDO = mix(vec3(0.110, 0.150, 0.055), vec3(0.190, 0.240, 0.095), (patch - 0.65) / 0.35) * g;
	} else {
		vec2 uv = ((ground_xz + half_size) / grid_step + 0.5) / float(nodes);
		// Field parcels and soil moisture vary slowly over hundreds of metres.
		float parcel = texture(grain, ground_xz * 0.0041 + vec2(0.37, 0.11)).r;
		ALBEDO = texture(cover, uv).rgb * g * mix(0.9, 1.08, (parcel - 0.65) / 0.35);
	}
	ROUGHNESS = 1.0;
}
