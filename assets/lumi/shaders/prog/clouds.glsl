#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/cellular2x2.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/texconst.glsl
#include lumi:shaders/prog/fog.glsl
#include lumi:shaders/prog/tile_noise.glsl

/*******************************************************
 *  lumi:shaders/prog/clouds.glsl
 *******************************************************/

#define wnoise2(a) cellular2x2(a).x

const float CLOUD_MARCH_JITTER_STRENGTH = 1.0;
const float TEXTURE_RADIUS = 512.0;
const int NUM_SAMPLE = 12;
const int LIGHT_SAMPLE = 5; 
const float LIGHT_SAMPLE_SIZE = 1.0;

vec2 worldXz2Uv(vec2 worldXz)
{
	worldXz += frx_cameraPos.xz;
	worldXz += frx_renderSeconds;
	vec2 ndc = worldXz * CLOUD_SAMPLING_ZOOM / TEXTURE_RADIUS;
	return ndc * 0.5 + 0.5;
}

const float CLOUD_HEIGHT = 15.0 / (CLOUD_TEXTURE_ZOOM * CLOUD_SAMPLING_ZOOM);
const float CLOUD_MID_HEIGHT = CLOUD_HEIGHT * .3;
const float CLOUD_TOP_HEIGHT = CLOUD_HEIGHT - CLOUD_MID_HEIGHT;
const float CLOUD_MID_ALTITUDE = CLOUD_ALTITUDE + CLOUD_MID_HEIGHT;
const float CLOUD_MIN_Y = CLOUD_ALTITUDE;
const float CLOUD_MAX_Y = CLOUD_ALTITUDE + CLOUD_HEIGHT;

const float CLOUD_COVERAGE = clamp(CLOUD_COVERAGE_RELATIVE / 10.0, 0.0, 1.0);
const float CLOUD_PUFFINESS = clamp(CLOUD_PUFFINESS_RELATIVE / 10.0, 0.0, 1.0);

const float MIN_COVERAGE = 0.325 + 0.2 * (1.0 - CLOUD_COVERAGE);

float sampleCloud(sampler2D natureTexture, vec3 worldPos)
{
	vec2 uv = worldXz2Uv(worldPos.xz);
	float tF = l2_clampScale(MIN_COVERAGE * (1.0 - frx_smoothedRainGradient * 0.6), 1.0, texture(natureTexture, uv).r);
	float hF = 0.1 + 0.9 * tF;
	float yF = l2_clampScale(CLOUD_MID_ALTITUDE + CLOUD_TOP_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);
	yF *= l2_clampScale(CLOUD_MID_ALTITUDE - CLOUD_MID_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);
	return l2_clampScale(0.0, 1.0 - 0.7 * CLOUD_PUFFINESS, yF * tF);
}

bool optimizeStart(float startTravel, float maxDist, vec3 toSky, inout vec3 worldRayPos, inout float sampleSize, float numSample, out float preTraveled)
{
	float nearBorder = 0.0;

	// Optimization block
#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	nearBorder = (CLOUD_MIN_Y - worldRayPos.y) / toSky.y;
	maxDist = min(maxDist, (CLOUD_MAX_Y - worldRayPos.y) / toSky.y);
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
	nearBorder = max(nearBorder, startTravel);

	if (nearBorder > maxDist) return true;

	worldRayPos += toSky * nearBorder;
	preTraveled += nearBorder;

	float toTravel = max(0.0, maxDist - preTraveled);

	sampleSize = min(sampleSize, toTravel / numSample);

	return false;
}

vec3 rayMarchCloud(sampler2D natureTexture, sampler2DArray resources, vec2 texcoord, float maxDist, vec3 toSky, float numSample, float startTravel)
{
	vec3 lightUnit = frx_skyLightVector * LIGHT_SAMPLE_SIZE;
	vec3 worldRayPos = vec3(0.0, 63.0, 0.0);

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_WORLD
	worldRayPos.y = frx_cameraPos.y;
#endif

	float sampleSize = 256.0 / float(numSample);
	float distanceTotal = 0.0;

	if (optimizeStart(startTravel, maxDist, toSky, worldRayPos, sampleSize, numSample, distanceTotal)) return vec3(0.0);

	vec3 unitRay = toSky * sampleSize;
	float i = getRandomFloat(resources, texcoord, frxu_size) * CLOUD_MARCH_JITTER_STRENGTH;

	worldRayPos += unitRay * i; // start position

	float lightEnergy = 0.0;
	float alpha = sampleSize * 0.3;
	float toLightAlpha = LIGHT_SAMPLE_SIZE * 0.99;
	float transmittance = 1.0;

	// Inspired by Sebastian Lague
	for (; i < numSample; i += 1.0) {
		float atRayDensity = sampleCloud(natureTexture, worldRayPos) * alpha * transmittance;
		transmittance = max(0.0, transmittance - atRayDensity);

		vec3 toLightPos = worldRayPos;
		float toLightTransmittance = 1.0;

		for (int j = 0; j < LIGHT_SAMPLE; j++) {
			toLightPos += lightUnit;
			toLightTransmittance -= sampleCloud(natureTexture, toLightPos) * toLightAlpha * toLightTransmittance;
		}

		lightEnergy += atRayDensity * max(0.0, toLightTransmittance);
		worldRayPos += unitRay;
	}

	distanceTotal += sampleSize * numSample;
	float fade = min(1.0, distanceTotal / 2048.0);
	// I guess this works because we limit the distance when we are on cloud level with world-clouds
	float fadeOut = 1.0 - pow(fade, 2.0);

	lightEnergy = clamp(lightEnergy, 0.0, 1.0);

	return vec3(lightEnergy, 1.0 - transmittance, fadeOut);
}

vec2 vanillaClouds(sampler2D cloudsDepthBuffer, float depth, vec2 texcoord)
{
	float dClouds = texture(cloudsDepthBuffer, texcoord).r;

	if (dClouds >= depth) return vec2(0.0);

	vec4 temp = frx_inverseViewProjectionMatrix * vec4(texcoord * 2.0 - 1.0, dClouds * 2.0 - 1.0, 1.0);
	vec3 origin = temp.xyz / temp.w;

	vec2 txc, txc0, txc1;
	float dd, d0, d1, mul0, mul1;

	txc0 = vec2(texcoord.x + v_invSize.x, texcoord.y);
	txc1 = vec2(texcoord.x - v_invSize.x, texcoord.y);
	d0 = texture(cloudsDepthBuffer, txc0).r;
	d1 = texture(cloudsDepthBuffer, txc1).r;

	if (abs(d0 - dClouds) < abs(d1 - dClouds)) {
		txc = txc0;
		dd = d0;
		mul0 = 1.0;
	} else {
		txc = txc1;
		dd = d1;
		mul0 = -1.0;
	}

	temp = frx_inverseViewProjectionMatrix * vec4(txc * 2.0 - 1.0, dd * 2.0 - 1.0, 1.0);
	vec3 right = temp.xyz / temp.w;

	txc0 = vec2(texcoord.x, texcoord.y + v_invSize.y);
	txc1 = vec2(texcoord.x, texcoord.y - v_invSize.y);
	d0 = texture(cloudsDepthBuffer, txc0).r;
	d1 = texture(cloudsDepthBuffer, txc1).r;

	if (abs(d0 - dClouds) < abs(d1 - dClouds)) {
		txc = txc0;
		dd = d0;
		mul1 = 1.0;
	} else {
		txc = txc1;
		dd = d1;
		mul1 = -1.0;
	}

	temp = frx_inverseViewProjectionMatrix * vec4(txc * 2.0 - 1.0, dd * 2.0 - 1.0, 1.0);
	vec3 bottom = temp.xyz / temp.w;

	vec3 normal = normalize(cross((right - origin) * mul0, (bottom - origin) * mul1));

	float energy = (dot(normal, frx_skyLightVector) * 0.5 + 0.5) * 0.7 + 0.3;
	return vec2(energy, 1.0);
}

vec4 customClouds(sampler2D cloudsDepthBuffer, sampler2D natureTexture, sampler2DArray resources, float depth, vec2 texcoord, vec3 eyePos, vec3 toSky, int numSample, float startTravel, vec4 fallback)
{
	vec3 result;
	if (frx_worldIsOverworld != 1) {
		result = vec3(vanillaClouds(cloudsDepthBuffer, depth, texcoord), 1.0);
	} else {
		#ifdef VOLUMETRIC_CLOUDS
		#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
		if (depth != 1. || toSky.y <= 0) return vec4(0.0);
		#endif

		float maxDist = frx_viewDistance * 4.; // actual far plane, prevents clipping

		#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
		maxDist = max(maxDist, CLOUD_ALTITUDE * 4.);
		#endif

		#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_WORLD
		maxDist = min(length(eyePos), maxDist);
		#endif

		result = rayMarchCloud(natureTexture, resources, texcoord, maxDist, toSky, numSample, startTravel);
		#else
		result = vec3(vanillaClouds(cloudsDepthBuffer, depth, texcoord), 1.0);
		#endif
	}

	float night = frx_worldIsMoonlit * frx_skyLightTransitionFactor; // night cloud brightening hack
	float rainCloudBrightness = 1.0 - hdr_fromGammaf(frx_smoothedRainGradient) * 0.2 - hdr_fromGammaf(frx_smoothedThunderGradient) * 0.1; // emulate dark clouds
	float celestLuminance = lightLuminanceUnclamped(atmosv_CelestialRadiance);
	vec3  celestRadiance = safeDiv(atmosv_CelestialRadiance, celestLuminance) * min(1.0, celestLuminance) * DEF_SKY_STR * result.x * mix(0.6, 0.12, night); // magic multiplier

	#ifdef VOLUMETRIC_CLOUDS
	if (frx_worldIsMoonlit == 1) {
		celestRadiance *= 0.2;
	}
	#endif

	vec3 cloudRadiance = mix(atmosv_SkyRadiance, vec3(lightLuminance(atmosv_SkyRadiance)), 0.5 - 0.5 * night) * (1.0 + night * 0.5);

	vec3 color = (celestRadiance + cloudRadiance) * rainCloudBrightness;
	color = mix(fallback.rgb, color.rgb, result.z);
	return vec4(color, result.y);
}

vec4 customClouds(sampler2D cloudsDepthBuffer, sampler2D natureTexture, sampler2DArray resources, float depth, vec2 texcoord, vec3 eyePos, vec3 toSky, int numSample, vec4 fallback)
{
	return customClouds(cloudsDepthBuffer, natureTexture, resources, depth, texcoord, eyePos, toSky, numSample, 0.0, fallback);
}
