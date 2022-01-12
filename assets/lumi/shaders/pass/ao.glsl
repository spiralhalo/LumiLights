#include lumi:shaders/pass/header.glsl

#include lumi:shaders/prog/tile_noise.glsl

#ifdef SSAO_OVERRIDE

const int RADIAL_STEPS	= clamp(SSAO_NUM_STEPS, 1, 10);
const int DIRECTIONS	= clamp(SSAO_NUM_DIRECTIONS, 1, 10);
const float VIEW_RADIUS	= SSAO_RADIUS;
const float ANGLE_BIAS	= SSAO_BIAS;
const float INTENSITY	= SSAO_INTENSITY;

#else

const int RADIAL_STEPS	= 5;
const int DIRECTIONS	= 5;
const float VIEW_RADIUS	= 0.8; // 0.5 ~ 1.0 is good
const float ANGLE_BIAS	= 0.3;
const float INTENSITY	= 4.0; // new: 4.0 is good for dim light, 7.0 for bright lights. old: 7.0 if divided by DIR, 40.0 if divided by STEP * DIR

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
	vec3  viewNormal = frx_normalModelMatrix * normalize(texture(u_gbuffer_lightnormal, vec3(v_texcoord, ID_SOLID_NORM)).xyz);
	float screenRadius = VIEW_RADIUS / (1.0 + abs(viewPos.z));

	// exclude last step here too
	vec2 deltaUV = vec2(float(RADIAL_STEPS - 1) / float(RADIAL_STEPS), 0.0) * (screenRadius / float(RADIAL_STEPS));
	vec3 fragNoise = normalize(2.0 * getRandomVec(u_tex_noise, v_texcoord, frxu_size) - 1.0);
	mat2 randomRotation = mat2(
		fragNoise.x, -fragNoise.y,
		fragNoise.y,  fragNoise.x
	);

	deltaUV = randomRotation * deltaUV;

	float occlusion = 0.0;
	for (int i = 0; i < DIRECTIONS; ++i) {
		deltaUV = v_deltaRotator * deltaUV;
		float prevPhi = ANGLE_BIAS;

		// last step is ignored because it will have 0 attenuation.. probably
		for (int j = 1; j < RADIAL_STEPS - 1; ++j) {
			vec2 sampleUV	   = v_texcoord + deltaUV * (float(j) + fragNoise.z);
			vec3 sampleViewPos = getViewPos(sampleUV, u_vanilla_depth);
			vec3 horizonVec	   = sampleViewPos - viewPos;
			float phi = (PI / 2.0) - acos(dot(viewNormal, normalize(horizonVec)));

			if (phi > prevPhi) {
				float r2 = dot(horizonVec, horizonVec) / (VIEW_RADIUS * VIEW_RADIUS); // optimized pow(len/rad, 2)
				float attenuation = clamp(1.0 - r2, 0.0, 1.0);
				float value		  = sin(phi) - sin(prevPhi);
				occlusion += attenuation * value;
				prevPhi = phi;
			}
		}
	}

	float fade = l2_clampScale(256.0, 0.0, -viewPos.z); // distant result are rather inaccurate, and I'm lazy
	occlusion  = 1.0 - occlusion / float(DIRECTIONS) * fade;

	// apply intensity before blurring
	ao_result = pow(clamp(occlusion, 0.0, 1.0), 1.0 + INTENSITY);
}

#endif
