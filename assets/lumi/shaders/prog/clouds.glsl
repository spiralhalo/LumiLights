#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/cellular2x2.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/texconst.glsl
#include lumi:shaders/prog/fog.glsl
#include lumi:shaders/prog/tile_noise.glsl
#include lumi:shaders/prog/tonemap.glsl

/*******************************************************
 *  lumi:shaders/prog/clouds.glsl
 *******************************************************/

#define wnoise2(a) cellular2x2(a).x

const float CLOUD_MARCH_JITTER_STRENGTH = 1.0;
const float TEXTURE_RADIUS = 512.0;
const int NUM_SAMPLE = 32;
const int LIGHT_SAMPLE = 5; 
const float LIGHT_SAMPLE_SIZE = 1.0;

vec2 worldXz2Uv(vec2 worldXz)
{
	worldXz += frx_cameraPos.xz;
	worldXz += frx_renderSeconds;
	vec2 ndc = worldXz * CLOUD_SAMPLING_ZOOM / TEXTURE_RADIUS;
	return ndc * 0.5 + 0.5;
}

const float CLOUD_ALTITUDE = VOLUMETRIC_CLOUD_ALTITUDE;
const float CLOUD_HEIGHT = 20.0 / (CLOUD_TEXTURE_ZOOM * CLOUD_SAMPLING_ZOOM);
const float CLOUD_MID_HEIGHT = CLOUD_HEIGHT * .3;
const float CLOUD_TOP_HEIGHT = CLOUD_HEIGHT - CLOUD_MID_HEIGHT;
const float CLOUD_MID_ALTITUDE = CLOUD_ALTITUDE + CLOUD_MID_HEIGHT;
const float CLOUD_MIN_Y = CLOUD_ALTITUDE;
const float CLOUD_MAX_Y = CLOUD_ALTITUDE + CLOUD_HEIGHT;

const float CLOUD_COVERAGE = clamp(CLOUD_COVERAGE_RELATIVE * 0.1, 0.0, 1.0);
const float CLOUD_PUFFINESS = clamp(CLOUD_PUFFINESS_RELATIVE * 0.1, 0.0, 1.0);

const float MIN_COVERAGE = 0.325 + 0.1 * (1.0 - CLOUD_COVERAGE);

float sampleCloud(sampler2D natureTexture, vec3 worldPos)
{
	vec2 uv = worldXz2Uv(worldPos.xz);
	float tF = l2_clampScale(MIN_COVERAGE * (1.0 - frx_rainGradient), 1.0, texture(natureTexture, uv).r);
	float hF = tF;
	float yF = l2_clampScale(CLOUD_MID_ALTITUDE + CLOUD_TOP_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);
	yF *= l2_clampScale(CLOUD_MID_ALTITUDE - CLOUD_MID_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);
	return l2_clampScale(0.0, 1.0 - 0.7 * CLOUD_PUFFINESS, yF * tF);
}

bool optimizeStart(float startTravel, float maxDist, vec3 toSky, inout vec3 worldRayPos, inout float numSample, float sampleSize, out float preTraveled)
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

	numSample = min(numSample, toTravel / sampleSize);

	return false;
}

vec3 rayMarchCloud(sampler2D natureTexture, sampler2D noiseTexture, vec2 texcoord, float maxDist, vec3 toSky, float numSample, float startTravel)
{
	vec3 lightUnit = frx_skyLightVector * LIGHT_SAMPLE_SIZE;
	vec3 worldRayPos = vec3(0.0, 63.0, 0.0);

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_WORLD
	worldRayPos.y = frx_cameraPos.y;
#endif

	float sampleSize = 256.0 / float(numSample);
	float distanceTotal = 0.0;

	if (optimizeStart(startTravel, maxDist, toSky, worldRayPos, numSample, sampleSize, distanceTotal)) return vec3(0.0);

	vec3 unitRay = toSky * sampleSize;
	float i = getRandomFloat(noiseTexture, texcoord, frxu_size) * CLOUD_MARCH_JITTER_STRENGTH;

	worldRayPos += unitRay * i; // start position

	float lightEnergy = 0.0;
	float transmittance = 1.0;

	// Adapted from Sebastian Lague's method
	for (; i < numSample; i += 1.0) {
		worldRayPos += unitRay;

		float atRayDensity = sampleCloud(natureTexture, worldRayPos) * sampleSize;

		vec3 toLightPos = worldRayPos;
		float toLightDensity = 0.0;

		for (int j = 0; j < LIGHT_SAMPLE; j++) {
			toLightPos += lightUnit;
			toLightDensity += sampleCloud(natureTexture, toLightPos);
		}

		toLightDensity /= float(LIGHT_SAMPLE);

		float lightAtRay = exp(-toLightDensity * 5.);

		lightEnergy += atRayDensity * transmittance * lightAtRay;
		distanceTotal += sampleSize * transmittance;

		transmittance *= exp(-atRayDensity);
	}

	// meant to be fix for "dark aura" around clouds but causes light aura instead (with some mental gymnastic can be interpreted as silver lining?)
	lightEnergy += transmittance; // transparent clouds get more light

	return vec3(lightEnergy, 1.0 - transmittance, distanceTotal);
}

mat4 computeCloudRotator() {
	return l2_rotationMatrix(vec3(0.0, 1.0, 0.0), PI * 0.25);
}

vec4 flatCloud(in vec3 worldVec, in mat4 cloudRotator)
{
	float rainFactor = frx_rainGradient() * 0.8 + frx_thunderGradient() * 0.2;
	float cloud = 0.0;
	float skyDotUp = worldVec.y;

	// convert hemisphere to plane centered around cameraPos
	vec2 cloudPlane = worldVec.xz / (0.1 + worldVec.y) * 100.0
		+ frx_cameraPos().xz / 5.0 + vec2(0.2) * frx_renderSeconds();//(frx_worldDay() + frx_worldTime());
	vec2 rotatedCloudPlane = (cloudRotator * vec4(cloudPlane.x, 0.0, cloudPlane.y, 0.0)).xz;
	cloudPlane *= 0.1;

	float cloudBase = 1.0
		* l2_clampScale(0.0, 0.1, skyDotUp)
		* l2_clampScale(-0.5 - rainFactor * 0.5, 1.0 - rainFactor, snoise(rotatedCloudPlane * 0.005));
	float cloud1 = cloudBase * l2_clampScale(-1.0, 1.0, snoise(rotatedCloudPlane * 0.015));
	float cloud2 = cloud1 * l2_clampScale(-1.0, 1.0, snoise(rotatedCloudPlane * 0.04));
	float cloud3 = cloud2 * l2_clampScale(-1.0, 1.0, snoise(rotatedCloudPlane * 0.1));

	cloud = cloud1 * 0.5 + cloud2 * 0.75 + cloud3;
	cloud = l2_clampScale(0.0, 2.0, cloud);
	cloud *= (min(abs(frx_worldTime() * 4.0 - 1.0), 1.0) * 0.6 + 0.4) * 0.8; // less clouds at noon
	cloud *= (1.0 - rainFactor * 0.8);

	vec3 color = atmosv_hdrCelestialRadiance * 0.1 + atmosv_hdrCloudColorRadiance;
	return vec4(color, cloud);
}

vec4 layer(vec4 foreground, vec4 background) {
    return foreground * foreground.a + background * (1.0 - foreground.a);
}

vec4 customClouds(sampler2D cloudsDepthBuffer, sampler2D natureTexture, sampler2D noiseTexture, float depth, vec2 texcoord, vec3 eyePos, vec3 toSky, int numSample, float startTravel)
{
	vec3 result;
#ifdef VOLUMETRIC_CLOUDS
#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	if (depth != 1. || toSky.y <= 0) return vec4(0.0);
#endif

	float maxDist = frx_viewDistance * 4.; // actual far plane, prevents clipping

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_WORLD
	maxDist = min(length(eyePos), maxDist);
#endif

	result = rayMarchCloud(natureTexture, noiseTexture, texcoord, maxDist, toSky, numSample, startTravel);
#elif !defined(FLAT_CLOUDS)
	float dClouds = texture(cloudsDepthBuffer, texcoord).r;

	if (dClouds >= depth) return vec4(0.0);

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
	result = vec3(energy, 1.0, length(origin));
#endif

	float rainBrightness = mix(0.13, 0.05, hdr_fromGammaf(frx_rainGradient)); // emulate dark clouds
	vec3  cloudShading	 = atmosv_CloudRadiance;
	vec3  skyFadeColor	 = atmos_SkyGradientRadiance(toSky);
	vec3  celestRadiance = atmosv_CelestialRadiance;

	#ifdef VOLUMETRIC_CLOUDS
	if (frx_worldIsMoonlit == 1) {
		celestRadiance *= 0.2;
	}
	#endif

	celestRadiance = celestRadiance * result.x * rainBrightness;//
	vec3 color = celestRadiance + cloudShading;
	float fogF = sqrt(fogFactor(result.z));
	color = mix(color, skyFadeColor, fogF / 2);

#ifdef FLAT_CLOUDS
	vec4 flatCloudColor;
	if (depth != 1. || toSky.y <= 0 || frx_worldIsOverworld != 1)
	{
		flatCloudColor = vec4(0.0);
	}
	else
	{
		vec4 modelPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * v_texcoord - 1.0, 1.0, 1.0);
		modelPos.xyz /= modelPos.w;
		vec3 worldVec = normalize(modelPos.xyz);
		mat4 v_cloud_rotator = computeCloudRotator();

		flatCloudColor = flatCloud(worldVec, v_cloud_rotator);
		flatCloudColor.rgb = ldr_tonemap(flatCloudColor.rgb);
	}

	return layer(vec4(color, result.y), flatCloudColor);
#else
	return vec4(color, result.y);
#endif
}

vec4 customClouds(sampler2D cloudsDepthBuffer, sampler2D natureTexture, sampler2D noiseTexture, float depth, vec2 texcoord, vec3 eyePos, vec3 toSky, int numSample)
{
	return customClouds(cloudsDepthBuffer, natureTexture, noiseTexture, depth, texcoord, eyePos, toSky, numSample, 0.0);
}
