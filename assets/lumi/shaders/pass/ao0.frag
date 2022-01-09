#include lumi:shaders/pass/header.glsl

/******************************************************
  lumi:shaders/pass/ao0.frag
******************************************************/

uniform sampler2DArray u_gbuffer_main_etc;
// uniform sampler2D u_ao;

layout(location = 0) out vec4 copy;
// layout(location = 1) out float ao_value;

void main()
{
	copy = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_SOLID_LIGT));

	// float totalAo = 0.0;
	// float total = 0.0;
	// vec3 normal = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_SOLID_NORM)).xyz * 2.0 - 1.0;

	// for (float x = -2.0; x < 2.2; x += 2.0) {
	// 	for (float y = -2.0; y < 2.2; y += 2.0) {
	// 		vec2 sampleUV = v_texcoord + vec2(x, y) * v_invSize;
	// 		vec3 sampleNormal = texture(u_gbuffer_lightnormal, vec3(sampleUV, ID_SOLID_NORM)).xyz * 2.0 - 1.0;

	// 		float NdN = max(0.0, dot(sampleNormal, normal));
	// 		totalAo += textureLod(u_ao, sampleUV, 1.0).r * NdN;
	// 		total += NdN;
	// 	}
	// }

	// ao_value = totalAo / total;
}
