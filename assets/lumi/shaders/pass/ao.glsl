#include lumi:shaders/pass/header.glsl

#include lumi:shaders/prog/tile_noise.glsl

#ifdef SSAO_OVERRIDE

const int STEPS		  = clamp(SSAO_NUM_STEPS, 1, 10);
const int DIRECTIONS  = clamp(SSAO_NUM_DIRECTIONS, 1, 10);
const float RADIUS	  = SSAO_RADIUS;
const float ANGLEBIAS = SSAO_BIAS;

#else

const int STEPS		  = 5;
const int DIRECTIONS  = 5;
const float RADIUS	  = 0.8; // 0.5 ~ 1.0 is good
const float ANGLEBIAS = 0.3;

#endif

#ifdef VERTEX_SHADER

out mat2 v_deltaRotator;

void calcDeltaRotator() {
	float theta    = (2.0 * PI) / float(DIRECTIONS);
	float cosTheta = cos(theta);
	float sinTheta = sin(theta);

	v_deltaRotator = mat2(
		cosTheta, -sinTheta,
		sinTheta, cosTheta
	);
}

void main()
{
	calcDeltaRotator();
	basicFrameSetup();
}

#else

uniform sampler2D u_vanilla_depth;
uniform sampler2DArray u_gbuffer_lightnormal;
uniform sampler2D u_tex_noise;

in mat2 v_deltaRotator;

out float ao_result;

vec3 getViewPos(vec2 texcoord, in sampler2D target)
{
	float depth = texture(target, texcoord).r;
	vec3  clip	= vec3(2.0 * texcoord - 1.0, 2.0 * depth - 1.0);
	vec4  view	= frx_inverseProjectionMatrix * vec4(clip, 1.0);

	return view.xyz / view.w;
}

void main()
{
	vec3  viewPos = getViewPos(v_texcoord, u_vanilla_depth);
	vec3  viewNormal = frx_normalModelMatrix * normalize(texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_SOLID_NORM)).xyz * 2.0 - 1.0);
	float viewRadius = RADIUS / max(1.0, abs(viewPos.z));

	vec2 deltaUV = vec2(1.0, 0.0) * (viewRadius / float(STEPS));
	vec3 sampleNoise = normalize(2.0 * getRandomVec(u_tex_noise, v_texcoord, frxu_size) - 1.0);
	mat2 randomRotation = mat2(
		sampleNoise.x, -sampleNoise.y,
		sampleNoise.y,  sampleNoise.x
	);

	deltaUV = randomRotation * deltaUV;

	float occlusion = 0.0;
	vec3 emission = vec3(0.0);

	for (int i = 0; i < DIRECTIONS; ++i) {
		deltaUV = v_deltaRotator * deltaUV;
		float prevPhi = ANGLEBIAS;

		// last step is ignored because it will have 0 attenuation.. probably
		for (int j = 1; j < STEPS - 1; ++j) {
			vec2 sampleUV	   = v_texcoord + deltaUV * (float(j) + sampleNoise.z);
			vec3 sampleViewPos = getViewPos(sampleUV, u_vanilla_depth);
			vec3 horizonVec	   = sampleViewPos - viewPos;
			float phi = (PI / 2.0) - acos(dot(viewNormal, normalize(horizonVec)));

			if (phi > prevPhi) {
				float r2 = dot(horizonVec, horizonVec) / (RADIUS * RADIUS); // optimized pow(len/rad, 2)
				float attenuation = clamp(1.0 - r2, 0.0, 1.0);
				float value		  = sin(phi) - sin(prevPhi);
				occlusion += attenuation * value;
				prevPhi = phi;
			}
		}
	}

	float fade = l2_clampScale(256.0, 0.0, -viewPos.z); // distant result are rather inaccurate, and I'm lazy
	occlusion  = 1.0 - occlusion / float(DIRECTIONS) * fade;
	ao_result = clamp(occlusion, 0.0, 1.0);
}

#endif
