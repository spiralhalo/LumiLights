#include lumi:shaders/pass/header.glsl

#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/pass/ao2.frag
******************************************************/

#ifdef SSAO_OVERRIDE
const float INTENSITY = SSAO_INTENSITY;
#else
// 7 if divided by direction, 40 if divided by step * direction
const float INTENSITY = 4.0;
#endif

uniform sampler2D u_gbuffer_main_etc_copy;
uniform sampler2DArray u_gbuffer_lightnormal;
uniform sampler2D u_ao;

out vec4 rawMat;

void main()
{
	rawMat = texture(u_gbuffer_main_etc_copy, v_texcoord);

	float totalAo = 0.0;
	float total = 0.0;
	vec3 normal = texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_SOLID_NORM)).xyz;

	// this blurring costs about 0.1 ms in my hardware, helps unreliable TAA
	for (float x = -2.0; x < 2.2; x += 2.0) {
	for (float y = -2.0; y < 2.2; y += 2.0) {
		vec2 sampleUV = v_texcoord + vec2(x, y) * v_invSize;
		vec3 sampleNormal = texture(u_gbuffer_lightnormal, vec3(sampleUV, ID_SOLID_NORM)).xyz;

		float NdN = max(0.0, dot(sampleNormal, normal));
		totalAo += texture(u_ao, sampleUV).r * NdN;
		total += NdN;
	}
	}

	rawMat.z = pow(totalAo/total, 1.0 + INTENSITY);
}
