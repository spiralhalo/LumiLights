#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/cellular2x2.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/prog/tile_noise.glsl

/*******************************************************
 *  lumi:shaders/prog/clouds.glsl
 *******************************************************/

#define wnoise2(a) cellular2x2(a).x

struct cloud_result {
	float lightEnergy;
	float transmittance;
	vec3 worldPos;
};

const float CLOUD_MARCH_JITTER_STRENGTH = 1.0;
const float CLOUD_TEXTURE_ZOOM = 0.25;
const float TEXTURE_RADIUS = 512.0;
const int NUM_SAMPLE = 8;
const int LIGHT_SAMPLE = 5; 
const float LIGHT_ABSORPTION = 0.9;
const float LIGHT_SAMPLE_SIZE = 1.0;

vec2 worldXz2Uv(vec2 worldXz)
{
#if VOLUMETRIC_CLOUD_MODE != VOLUMETRIC_CLOUD_MODE_WORLD
	worldXz += frx_cameraPos.xz;
#endif
	vec2 ndc = worldXz / TEXTURE_RADIUS;
	return ndc * 0.5 + 0.5;
}

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	const float CLOUD_ALTITUDE = VOLUMETRIC_CLOUD_ALTITUDE - 60;
#else
	const float CLOUD_ALTITUDE = VOLUMETRIC_CLOUD_ALTITUDE;
#endif
const float CLOUD_HEIGHT = 20.0 / CLOUD_TEXTURE_ZOOM;
const float CLOUD_MID_HEIGHT = CLOUD_HEIGHT * .4;
const float CLOUD_TOP_HEIGHT = CLOUD_HEIGHT - CLOUD_MID_HEIGHT;
const float CLOUD_MID_ALTITUDE = CLOUD_ALTITUDE + CLOUD_MID_HEIGHT;
const float CLOUD_MIN_Y = CLOUD_ALTITUDE;
const float CLOUD_MAX_Y = CLOUD_ALTITUDE + CLOUD_HEIGHT;

const float CLOUD_COVERAGE = clamp(CLOUD_COVERAGE_RELATIVE * 0.1, 0.0, 1.0);
const float CLOUD_PUFFINESS = clamp(CLOUD_PUFFINESS_RELATIVE * 0.1, 0.0, 1.0);
const float CLOUD_BRIGHTNESS = clamp(CLOUD_BRIGHTNESS_RELATIVE * 0.1, 0.0, 1.0);

float sampleCloud(vec3 worldPos, sampler2D cloudTexture)
{
	vec2 uv = worldXz2Uv(worldPos.xz);
	float tF = l2_clampScale(0.5 * (1.0 - frx_rainGradient), 1.0, texture(cloudTexture, uv).r);
	float hF = tF;
	float yF = smoothstep(CLOUD_MID_ALTITUDE + CLOUD_TOP_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);
	yF *= smoothstep(CLOUD_MID_ALTITUDE - CLOUD_MID_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);

	return smoothstep(0.0, 1.0 - 0.7 * CLOUD_PUFFINESS, yF * tF);
}

cloud_result rayMarchCloud(sampler2D cloudTexture, sampler2D noiseTexture, float dSampled, vec2 texcoord, vec3 toSky, float numSample)
{
	float depth = (texcoord == clamp(texcoord, 0.0, 1.0)) ? dSampled : 1.0;
	float maxDist;

	const cloud_result nullcloud = cloud_result(0.0, 1.0, vec3(0.0));

	if (depth == 1.0) {
		maxDist = 1024.0;
	} else {
		#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
			return nullcloud; // Some sort of culling
		#else
			vec4 viewPos = frx_inverseProjectionMatrix * vec4(2.0 * texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
			viewPos.xyz /= viewPos.w;
			maxDist = length(viewPos.xyz);
		#endif
	}

	vec3 toLight = frx_skyLightVector * LIGHT_SAMPLE_SIZE;

	// Adapted from Sebastian Lague's code (technically not the same, but just case his code was MIT Licensed)

	float traveled = 0.0;
	vec3 currentWorldPos = vec3(0.0);
	float gotoBorder = 0.0;

	// Optimization block
#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	if (toSky.y <= 0) {
		return nullcloud;
	}

	gotoBorder = CLOUD_MIN_Y / toSky.y;
	maxDist = CLOUD_MAX_Y / toSky.y;
#else
	float borderDist = maxDist;
	currentWorldPos = frx_cameraPos;

	if (currentWorldPos.y >= CLOUD_MAX_Y) {
		if (toSky.y >= 0) {
			return nullcloud;
		}

		gotoBorder = (currentWorldPos.y - CLOUD_MAX_Y) / -toSky.y;
		borderDist = (currentWorldPos.y - CLOUD_MIN_Y) / -toSky.y;
	} else if (currentWorldPos.y <= CLOUD_MIN_Y) {
		if (toSky.y <= 0) {
			return nullcloud;
		}

		gotoBorder = (CLOUD_MIN_Y - currentWorldPos.y) / toSky.y;
		borderDist = (CLOUD_MAX_Y - currentWorldPos.y) / toSky.y;
	} else if (toSky.y <= 0) {
		borderDist = (currentWorldPos.y - CLOUD_MIN_Y) / -toSky.y;
	} else {
		borderDist = (CLOUD_MAX_Y - currentWorldPos.y) / toSky.y;
	}

	maxDist = min(maxDist, borderDist);
#endif

	currentWorldPos += toSky * gotoBorder;
	traveled += gotoBorder;

	float toTravel = max(0.0, maxDist - traveled);

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	const float sampleMult = 4.0;
	numSample *= sampleMult - 3.0 * CLOUD_HEIGHT / toTravel;
	numSample = clamp(numSample, 0., sampleMult * numSample);

	float sampleSize = toTravel / float(numSample);
#else
	numSample = 16.0 * numSample;

	float sampleSize = TEXTURE_RADIUS / float(numSample);

	numSample = min(numSample, toTravel / sampleSize);
#endif

	vec3 unitSample = toSky * sampleSize;
	float tileJitter = getRandomFloat(noiseTexture, texcoord, frxu_size) * CLOUD_MARCH_JITTER_STRENGTH;

	traveled = sampleSize * tileJitter;
	currentWorldPos += unitSample * tileJitter;

	float lightEnergy = 0.0;
	float transmittance = 1.0;

	// ATTEMPT 1
	bool first = true;
	vec3 firstHitPos = currentWorldPos + toSky * 1024.0;
	// ATTEMPT 2
	// float maxDensity = 0.0;
	// vec3 firstDensePos = worldPos - toSky * 0.1;

	int i = 0;
	while (i < numSample) {
		i ++;
		traveled += sampleSize;
		currentWorldPos += unitSample;

		float sampledDensity = sampleCloud(currentWorldPos, cloudTexture);

		if (sampledDensity > 0) {
			// ATTEMPT 1
			if (first) {
				first = false;
				firstHitPos = currentWorldPos;
			}
			// ATTEMPT 2
			// if (sampledDensity > maxDensity) {
			//	 maxDensity = sampledDensity;
			//	 firstDensePos = currentWorldPos;
			// }

			// vec3 lightPos = frx_skyLightVector * 512.0 + frx_cameraPos;
			vec3 occlusionWorldPos = currentWorldPos;
			float occlusionDensity = 0.0;
			int j = 0;

			while (j < LIGHT_SAMPLE) {
				j ++;
				occlusionWorldPos += toLight;
				occlusionDensity += sampleCloud(occlusionWorldPos, cloudTexture);
			}

			occlusionDensity *= LIGHT_SAMPLE_SIZE; // this is what *stepSize means

			float lightTransmittance = exp(-occlusionDensity * LIGHT_ABSORPTION);

			lightEnergy += sampledDensity * transmittance * lightTransmittance * sampleSize; // * phaseVal;
			transmittance *= exp(-sampledDensity * sampleSize);

			if (transmittance < 0.01) {
				break;
			}
		}
	}
	return cloud_result(lightEnergy, transmittance, firstHitPos);
}

vec4 volumetricCloud(sampler2D cloudTexture, sampler2D noiseTexture, float backDepth, float frontDepth, vec2 texcoord, vec3 toSky, int numSample)
{
	#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
		cloud_result volumetric = rayMarchCloud(cloudTexture, noiseTexture, backDepth, texcoord, toSky, numSample);
	#else
		cloud_result volumetric = frx_cameraInFluid == 1
								? rayMarchCloud(cloudTexture, noiseTexture, backDepth, texcoord, toSky, numSample)
								: rayMarchCloud(cloudTexture, noiseTexture, frontDepth, texcoord, toSky, numSample);
	#endif

	float alpha  = 1.0 - min(1.0, volumetric.transmittance);
	float energy = volumetric.lightEnergy;

	float rainBrightness = mix(0.13, 0.05, hdr_fromGammaf(frx_rainGradient)); // simulate dark clouds
	vec3  cloudShading	 = atmos_hdrCloudColorRadiance(toSky);
	vec3  celestRadiance = atmos_hdrCelestialRadiance();

	if (frx_worldIsMoonlit == 1) {
		celestRadiance *= 0.2;
	}

	celestRadiance = celestRadiance * energy * rainBrightness * CLOUD_BRIGHTNESS;
	vec3 color = celestRadiance + cloudShading;

	float out_depth;

	#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	out_depth = alpha > 0. ? 0.9999 : 1.0;
	#else
	vec3 reverseModelPos = volumetric.worldPos - frx_cameraPos;
	vec4 reverseClipPos  = frx_viewProjectionMatrix * vec4(reverseModelPos, 1.0);
	   reverseClipPos.z /= reverseClipPos.w;

	float backgroundDepth = frontDepth;
	float alphaThreshold  = backgroundDepth == 1. ? 0.5 : 0.; 

	out_depth = alpha > alphaThreshold ? reverseClipPos.z : 1.0;
	#endif

	// alpha *= energy + alpha - alpha * energy; // reduce dark border while minimizing loss of detail

	return vec4(color, alpha);
}
