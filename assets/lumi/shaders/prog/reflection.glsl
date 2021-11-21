#include lumi:shaders/prog/shading.glsl
#include lumi:shaders/prog/sky.glsl
#include lumi:shaders/prog/tile_noise.glsl

/*******************************************************
 *  lumi:shaders/prog/reflection.glsl
 *******************************************************/

const float HITBOX = 0.125;
const int MAXSTEPS = 20;
const int PERIOD = 2;
const int REFINE = 8;

const float REFLECTION_MAXIMUM_ROUGHNESS = REFLECTION_MAXIMUM_ROUGHNESS_RELATIVE / 10.0;
const float SKYLESS_FACTOR = 0.5;

vec3 reflectionMarch(sampler2D depthBuffer, sampler2DArray normalBuffer, float idNormal, vec3 viewStartPos, vec3 viewToEye, vec3 viewMarch)
{
	// TODO: rewrite
	viewStartPos = viewStartPos + viewMarch * -viewStartPos.z / vec3(50.); // magic

	vec3 worldMarch = viewMarch * frx_normalModelMatrix;

	vec3 viewRayPos = viewStartPos;
	float edgeZ = viewStartPos.z + 0.25;

	float hitboxZ = HITBOX;
	vec3 viewRayUnit = viewMarch * hitboxZ;

	// limit hitbox size for inbound reflection
	bool inbound = viewMarch.z > 0.0;
	float hitboxLimit = inbound ? 1. : 1024000.;

	vec4 temp;
	vec2 uvRayHitPos;
	int steps = 0;
	while (steps < MAXSTEPS && viewRayPos.z < 0.0) {
		viewRayPos += viewRayUnit;

		temp = frx_projectionMatrix * vec4(viewRayPos, 1.0);
		uvRayHitPos = (temp.xy / temp.w) * 0.5 + 0.5;

		temp.z = texture(depthBuffer, uvRayHitPos).r;
		temp = frx_inverseProjectionMatrix * vec4(uvRayHitPos * 2.0 - 1.0, temp.z * 2.0 - 1.0, 1.0);

		vec3 viewRayHitPos = temp.xyz / temp.w;

		float dZ = viewRayHitPos.z - viewRayPos.z; 
		// vec3 reflectedNormal   = texture(normalBuffer, vec3(uvRayHitPos, idNormal)).xyz * 2.0 - 1.0;
		// bool reflectsFrontFace = true;//dot(worldMarch, reflectedNormal) < 0.;

		if (dZ > 0 && (/*reflectsFrontFace &&*/ viewRayHitPos.z < edgeZ || inbound)) {
			// Pad hitbox
			float hitboxNow = min(hitboxLimit, hitboxZ * 2);

			if (dZ < hitboxNow) {
				//refine
				int refine_steps = 0;
				vec2 uvLastHitPos = uvRayHitPos;
				float lastdZ = dZ;
				float refineRayLength = 0.0625;
				viewRayUnit = viewMarch * refineRayLength;

				// 0.01 is the dZ at which no more detail will be achieved even for very nearby reflection
				// PERF: adapt based on initial z
				while (refine_steps < REFINE && abs(dZ) > 0.01) {

					if (abs(dZ) < refineRayLength) {
						refineRayLength = abs(dZ);
						viewRayUnit = viewMarch * refineRayLength;
					}

					viewRayPos -= viewRayUnit;

					temp = frx_projectionMatrix * vec4(viewRayPos, 1.0);
					uvRayHitPos = (temp.xy / temp.w) * 0.5 + 0.5;

					temp.z = texture(depthBuffer, uvRayHitPos).r;
					temp = frx_inverseProjectionMatrix * vec4(uvRayHitPos * 2.0 - 1.0, temp.z * 2.0 - 1.0, 1.0);

					viewRayHitPos = temp.xyz / temp.w;

					dZ = viewRayHitPos.z - viewRayPos.z;
					// Ensure dZ never increases
					if (abs(dZ) > abs(lastdZ)) break;

					uvLastHitPos = uvRayHitPos;
					lastdZ = dZ;
					refine_steps ++;
				}

				return vec3(uvLastHitPos, 1.0);
			}
		}

		if (mod(steps, PERIOD) == 0 && hitboxZ < hitboxLimit) {
			viewRayUnit *= 2.;
			hitboxZ *= 2.;
		}

		steps ++;
	}

	return vec3(uvRayHitPos, 0.0);
}

const float JITTER_STRENGTH = 0.6;

vec4 reflection(vec3 albedo, sampler2D colorBuffer, sampler2DArray mainEtcBuffer, sampler2DArray lightBuffer, sampler2DArray normalBuffer, sampler2D depthBuffer, sampler2DArrayShadow shadowMap, sampler2D sunTexture, sampler2D moonTexture, sampler2D noiseTexture, float idLight, float idMaterial, float idNormal, float idMicroNormal, vec3 eyePos)
{
	vec3 material = texture(mainEtcBuffer, vec3(v_texcoord, idMaterial)).xyz;

	bool isUnmanaged = material.x == 0.0;

	// TODO: end portal glitch?

	if (isUnmanaged) return vec4(0.0); // unmanaged draw

	vec4 light	= texture(lightBuffer, vec3(v_texcoord, idLight));
	vec3 normal	= texture(normalBuffer, vec3(v_texcoord, idMicroNormal)).xyz * 2.0 - 1.0;
	float depth	= texture(depthBuffer, v_texcoord).r;

	light.w = denoisedShadowFactor(shadowMap, eyePos, depth, light.y);

	vec3 viewPos = (frx_viewMatrix * vec4(eyePos, 1.0)).xyz;
	float roughness = material.x;

	// TODO: rain puddles?

	vec3 jitterRaw = getRandomVec(noiseTexture, v_texcoord, frxu_size) * 2.0 - 1.0;
	vec3 jitterPrc = jitterRaw * JITTER_STRENGTH * roughness * roughness;

	vec3 viewToEye  = normalize(-viewPos);
	vec3 viewToFrag = -viewToEye;
	vec3 viewNormal = frx_normalModelMatrix * normal;
	vec3 viewMarch  = normalize(reflect(viewToFrag, viewNormal) + jitterPrc);

	vec3 result = vec3(0.0);

	// Impossible Ray Resultion:
	vec3 rawNormal = texture(normalBuffer, vec3(v_texcoord, idNormal)).xyz * 2.0 - 1.0;
	vec3 rawViewNormal = frx_normalModelMatrix * rawNormal;
	bool impossibleRay	= dot(rawViewNormal, viewMarch) < 0;

	if (impossibleRay) {
		normal = rawNormal;
		viewNormal = rawViewNormal;
		viewMarch = normalize(reflect(viewToFrag, viewNormal) + jitterPrc);
	}

	// Roughness Threshold Resolution: 
	bool withinThreshold = roughness <= REFLECTION_MAXIMUM_ROUGHNESS;

	if (withinThreshold) {
		result = reflectionMarch(depthBuffer, normalBuffer, idNormal, viewPos, viewToEye, viewMarch);
	}

	vec2 uvFade = smoothstep(0.5, 0.45, abs(result.xy - 0.5));
	result.z *= min(uvFade.x, uvFade.y);

	vec4 reflectedColor = texture(colorBuffer, result.xy);
	vec3 objLight = reflectionPbr(albedo, material, reflectedColor.rgb, viewMarch, viewToEye).rgb;
	vec3 skyLight = skyReflection(sunTexture, moonTexture, albedo, material, viewToFrag * frx_normalModelMatrix, viewMarch * frx_normalModelMatrix, normal, light.yw).rgb;

	vec3 reflectedLight = skyLight * (1.0 - result.z) * smoothstep(0.0, 1.0, viewNormal.y) + objLight * result.z;

	return vec4(reflectedLight, 0.0);
}
