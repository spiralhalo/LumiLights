#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/cellular2x2.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/texconst.glsl
#include lumi:shaders/prog/tile_noise.glsl

/*******************************************************
 *  lumi:shaders/prog/clouds.glsl
 *******************************************************/

#define wnoise2(a) cellular2x2(a).x

const float CLOUD_MARCH_JITTER_STRENGTH = 1.0;
const float TEXTURE_RADIUS = 512.0;
const int NUM_SAMPLE = 8;
const int LIGHT_SAMPLE = 5; 
const float LIGHT_ABSORPTION = 0.9;
const float LIGHT_SAMPLE_SIZE = 1.0;

vec2 worldXz2Uv(vec2 worldXz)
{
	worldXz += frx_cameraPos.xz;
	worldXz += frx_renderSeconds;
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
	float tF = l2_clampScale(0.35 * (1.0 - frx_rainGradient), 1.0, texture(cloudTexture, uv).r);
	float hF = tF;
	float yF = smoothstep(CLOUD_MID_ALTITUDE + CLOUD_TOP_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);
	yF *= smoothstep(CLOUD_MID_ALTITUDE - CLOUD_MID_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);
	return smoothstep(0.0, 1.0 - 0.7 * CLOUD_PUFFINESS, yF * tF);
}

bool optimizeStart(float startTravel, float maxDist, vec3 toSky, inout vec3 worldRayPos, inout float numSample, out float sampleSize)
{
	if (startTravel > maxDist) return true;

	float preTraveled = 0.0;
	float nearBorder = 0.0;

	// Optimization block
#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	nearBorder = CLOUD_MIN_Y / toSky.y;
	maxDist = CLOUD_MAX_Y / toSky.y;
#else
	float farBorder = maxDist;

	if (worldRayPos.y >= CLOUD_MAX_Y) {
		if (toSky.y >= 0) return true;
		nearBorder = (worldRayPos.y - CLOUD_MAX_Y) / -toSky.y;
		farBorder = (worldRayPos.y - CLOUD_MIN_Y) / -toSky.y;
	} else if (worldRayPos.y <= CLOUD_MIN_Y) {
		if (toSky.y <= 0) return true;
		nearBorder = (CLOUD_MIN_Y - worldRayPos.y) / toSky.y;
		farBorder = (CLOUD_MAX_Y - worldRayPos.y) / toSky.y;
	} else if (toSky.y <= 0) {
		farBorder = (worldRayPos.y - CLOUD_MIN_Y) / -toSky.y;
	} else {
		farBorder = (CLOUD_MAX_Y - worldRayPos.y) / toSky.y;
	}

	maxDist = min(maxDist, farBorder);
#endif
	// nearBorder = max(nearBorder, startTravel);

	worldRayPos += toSky * nearBorder;
	preTraveled += nearBorder;

	float toTravel = max(0.0, maxDist - preTraveled);

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	const float sampleMult = 4.0;
	numSample *= sampleMult - 3.0 * CLOUD_HEIGHT / toTravel;
	numSample = clamp(numSample, 0., sampleMult * numSample);

	sampleSize = toTravel / float(numSample);
#else
	numSample = 16.0 * numSample;

	sampleSize = TEXTURE_RADIUS / float(numSample) * 2.0;

	numSample = min(numSample, toTravel / sampleSize);
#endif

	return false;
}

vec2 rayMarchCloud(sampler2D cloudTexture, sampler2D noiseTexture, vec2 texcoord, vec3 eyePos, vec3 toSky, float numSample, float startTravel)
{
	vec3 lightUnit = frx_skyLightVector * LIGHT_SAMPLE_SIZE;
	vec3 worldRayPos = vec3(0.0);

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_WORLD
	worldRayPos.y = frx_cameraPos.y;
#endif

	float sampleSize = 1.0;

	if (optimizeStart(startTravel, length(eyePos), toSky, worldRayPos, numSample, sampleSize)) return vec2(0.0);

	vec3 unitSample = toSky * sampleSize;
	float tileJitter = getRandomFloat(noiseTexture, texcoord, frxu_size) * CLOUD_MARCH_JITTER_STRENGTH;

	worldRayPos += unitSample * tileJitter;

	float lightEnergy = 0.0;
	float transmittance = 1.0;

	// Adapted from Sebastian Lague's method
	int i = 0;
	while (i < numSample) {
		i ++;
		worldRayPos += unitSample;

		float sampledDensity = sampleCloud(worldRayPos, cloudTexture);

		if (sampledDensity > 0) {
			vec3 occlusionWorldPos = worldRayPos;
			float occlusionDensity = 0.0;
			int j = 0;

			while (j < LIGHT_SAMPLE) {
				j ++;
				occlusionWorldPos += lightUnit;
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

	return vec2(lightEnergy, 1.0 - min(1.0, transmittance));
}

vec4 volumetricCloud(sampler2D cloudTexture, sampler2D noiseTexture, float depth, vec2 texcoord, vec3 eyePos, vec3 toSky, int numSample, float startTravel)
{
#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	if (depth != 1. || toSky.y <= 0) return vec4(0.0);
#endif

	vec2 result = rayMarchCloud(cloudTexture, noiseTexture,  texcoord, eyePos, toSky, numSample, startTravel);

	float rainBrightness = mix(0.13, 0.05, hdr_fromGammaf(frx_rainGradient)); // emulate dark clouds
	vec3  cloudShading	 = atmos_hdrCloudColorRadiance(toSky);
	vec3  celestRadiance = atmos_hdrCelestialRadiance();

	if (frx_worldIsMoonlit == 1) {
		celestRadiance *= 0.2;
	}

	celestRadiance = celestRadiance * result.x * rainBrightness * CLOUD_BRIGHTNESS;
	vec3 color = celestRadiance + cloudShading;

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	result.y *= smoothstep(0.0, 0.2, toSky.y);
#endif

	return vec4(color, result.y);
}

vec4 volumetricCloud(sampler2D cloudTexture, sampler2D noiseTexture, float depth, vec2 texcoord, vec3 eyePos, vec3 toSky, int numSample)
{
	return volumetricCloud(cloudTexture, noiseTexture, depth, texcoord, eyePos, toSky, numSample, 0.0);
}
