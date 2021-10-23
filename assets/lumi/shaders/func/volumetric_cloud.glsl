#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/cellular2x2.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/func/tile_noise.glsl

/*******************************************************
 *  lumi:shaders/func/volumetric_cloud.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

#if CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
#define wnoise2(a) cellular2x2(a).x

struct cloud_result {
	float lightEnergy;
	float transmittance;
	vec3 worldPos;
};

const float CLOUD_MARCH_JITTER_STRENGTH = 1.0;
const float CLOUD_TEXTURE_ZOOM = 1.0;
const float TEXTURE_RADIUS = 512.0;
const float TEXTURE_RADIUS_RCP = 1.0 / TEXTURE_RADIUS;
const int NUM_SAMPLE = 6;
const int LIGHT_SAMPLE = 5; 
const float LIGHT_ABSORPTION = 0.7;
const float LIGHT_SAMPLE_SIZE = 1.0;

// coordinate helper functions because it won't work properly
vec2 uv2worldXz(vec2 uv)
{
	vec2 ndc = uv * 2.0 - 1.0;
	return frx_cameraPos().xz + ndc * TEXTURE_RADIUS;
}

vec2 worldXz2Uv(vec2 worldXz)
{
#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_WORLD
	worldXz -= frx_cameraPos().xz;
#endif
	vec2 ndc = worldXz * TEXTURE_RADIUS_RCP;
	return ndc * 0.5 + 0.5;
}

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	const float CLOUD_ALTITUDE = VOLUMETRIC_CLOUD_ALTITUDE - 60;
#else
	const float CLOUD_ALTITUDE = VOLUMETRIC_CLOUD_ALTITUDE;
#endif
const float CLOUD_HEIGHT = 50.0 / CLOUD_TEXTURE_ZOOM;
const float CLOUD_MID_HEIGHT = 20.0;
const float CLOUD_TOP_HEIGHT = CLOUD_HEIGHT - CLOUD_MID_HEIGHT;
const float CLOUD_MID_ALTITUDE = CLOUD_ALTITUDE + CLOUD_MID_HEIGHT;
const float CLOUD_MIN_Y = CLOUD_ALTITUDE;
const float CLOUD_MAX_Y = CLOUD_ALTITUDE + CLOUD_HEIGHT;

const float CLOUD_COVERAGE = clamp(CLOUD_COVERAGE_RELATIVE * 0.1, 0.0, 1.0);
const float CLOUD_PUFFINESS = clamp(CLOUD_PUFFINESS_RELATIVE * 0.1, 0.0, 1.0);

float sampleCloud(in vec3 worldPos, in sampler2D scloudTex)
{
	vec2 uv = worldXz2Uv(worldPos.xz);
	vec2 tex = texture(scloudTex, uv).rg; 
	float tF = tex.r;
	float hF = tex.g;

#ifdef VOLUMETRIC_CLOUD_ULTRAPUFF
	hF = sqrt(hF);
#endif

	float yF = smoothstep(CLOUD_MID_ALTITUDE + CLOUD_TOP_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);
	yF *= smoothstep(CLOUD_MID_ALTITUDE - CLOUD_MID_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y);

	return smoothstep(0.0, 1.0 - 0.7 * CLOUD_PUFFINESS, yF * tF);
}

cloud_result rayMarchCloud(in sampler2D scloudTex, in sampler2D sdepth, in sampler2D sbluenoise, in vec2 texcoord, in vec3 worldVec, in float numSample)
{
	float depth = (texcoord == clamp(texcoord, 0.0, 1.0)) ? texture(sdepth, texcoord).r : 1.0;
	float maxDist;

	const cloud_result nullcloud = cloud_result(0.0, 1.0, vec3(0.0));

	if (depth == 1.0) {
		maxDist = 1024.0;
	} else {
		#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
			return nullcloud; // Some sort of culling
		#else
			vec4 viewPos = frx_inverseProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
			viewPos.xyz /= viewPos.w;
			maxDist = length(viewPos.xyz);
		#endif
	}

	vec3 toLight = frx_skyLightVector() * LIGHT_SAMPLE_SIZE;

	// Adapted from Sebastian Lague's code (technically not the same, but just in case his code was MIT Licensed)

	float traveled = 0.0;
	vec3 currentWorldPos = vec3(0.0);
	float gotoBorder = 0.0;

	// Optimization block
#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	if (worldVec.y <= 0) {
		return nullcloud;
	}

	gotoBorder = CLOUD_MIN_Y / worldVec.y;
	maxDist = CLOUD_MAX_Y / worldVec.y;
#else
	float borderDist = maxDist;
	currentWorldPos = frx_cameraPos();

	if (currentWorldPos.y >= CLOUD_MAX_Y) {
		if (worldVec.y >= 0) {
			return nullcloud;
		}

		gotoBorder = (currentWorldPos.y - CLOUD_MAX_Y) / -worldVec.y;
		borderDist = (currentWorldPos.y - CLOUD_MIN_Y) / -worldVec.y;
	} else if (currentWorldPos.y <= CLOUD_MIN_Y) {
		if (worldVec.y <= 0) {
			return nullcloud;
		}

		gotoBorder = (CLOUD_MIN_Y - currentWorldPos.y) / worldVec.y;
		borderDist = (CLOUD_MAX_Y - currentWorldPos.y) / worldVec.y;
	} else if (worldVec.y <= 0) {
		borderDist = (currentWorldPos.y - CLOUD_MIN_Y) / -worldVec.y;
	} else {
		borderDist = (CLOUD_MAX_Y - currentWorldPos.y) / worldVec.y;
	}

	maxDist = min(maxDist, borderDist);
#endif

	currentWorldPos += worldVec * gotoBorder;
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

	vec3 unitSample = worldVec * sampleSize;
	float tileJitter = getRandomFloat(sbluenoise, texcoord, frxu_size) * CLOUD_MARCH_JITTER_STRENGTH;

	traveled = sampleSize * tileJitter;
	currentWorldPos += unitSample * tileJitter;

	float lightEnergy = 0.0;
	float transmittance = 1.0;

	// ATTEMPT 1
	bool first = true;
	vec3 firstHitPos = currentWorldPos + worldVec * 1024.0;
	// ATTEMPT 2
	// float maxDensity = 0.0;
	// vec3 firstDensePos = worldPos - worldVec * 0.1;

	int i = 0;
	while (i < numSample) {
		i ++;
		traveled += sampleSize;
		currentWorldPos += unitSample;

		float sampledDensity = sampleCloud(currentWorldPos, scloudTex);

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

			// vec3 lightPos = frx_skyLightVector() * 512.0 + frx_cameraPos();
			vec3 occlusionWorldPos = currentWorldPos;
			float occlusionDensity = 0.0;
			int j = 0;

			while (j < LIGHT_SAMPLE) {
				j ++;
				occlusionWorldPos += toLight;
				occlusionDensity += sampleCloud(occlusionWorldPos, scloudTex);
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

vec4 generateCloudTexture(vec2 texcoord) {
	float rainCanopy = RAINCLOUD_CANOPY * 0.1;
	float rainFactor = frx_rainGradient() * 0.8 * rainCanopy + frx_thunderGradient() * 0.2 * rainCanopy;
	vec2 worldXz = uv2worldXz(texcoord);

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
	worldXz -= frx_cameraPos().xz * 0.8;
#endif

	vec2 cloudCoord = worldXz;
#if CLOUD_TIME == CLOUD_TIME_WORLD
	cloudCoord += (frx_worldDay() + frx_worldTime()) * 1200.0;
#elif CLOUD_TIME == CLOUD_TIME_CLIENT
	cloudCoord += frx_renderSeconds();
#endif
	cloudCoord *= CLOUD_TEXTURE_ZOOM;

	float animatonator = frx_renderSeconds() * 0.05;
	float cloudBase = l2_clampScale(0.0 - CLOUD_COVERAGE, 0.7 + 0.3 * rainCanopy - rainFactor, snoise(cloudCoord * 0.005) + rainFactor * rainCanopy);
	float cloud1 = cloudBase * l2_clampScale(0.0, 1.0, wnoise2(cloudCoord * 0.015 + animatonator));
	float cloud2 = cloud1 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.04));
	float cloud3 = cloud2 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.1));

	float cloud = cloud1 * 0.5 + cloud2 * 0.75 + cloud3 + rainFactor * 0.5 * rainCanopy;

	cloud = l2_clampScale(0.1, 1.0, cloud);

	vec2 edge = smoothstep(0.5, 0.4, abs(texcoord - 0.5));
	float eF = edge.x * edge.y;

	return vec4(cloud * eF, sqrt(1.0 - pow(1.0 - cloud1 * cloud2, 2.0)), 0.0, 1.0);
}

vec4 volumetricCloud(
	in sampler2D scloudTex,
	in sampler2D ssolidDepth,
	in sampler2D stranslucentDepth,
	in sampler2D sbluenoise,
	in vec2 texcoord,
	in vec3 worldVec,
	in int numSample,
	out float out_depth)
{
	#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
		cloud_result volumetric = rayMarchCloud(scloudTex, ssolidDepth, sbluenoise, texcoord, worldVec, numSample);
	#else
		cloud_result volumetric = frx_viewFlag(FRX_CAMERA_IN_FLUID)
								? rayMarchCloud(scloudTex, ssolidDepth, sbluenoise, texcoord, worldVec, numSample)
								: rayMarchCloud(scloudTex, stranslucentDepth, sbluenoise, texcoord, worldVec, numSample);
	#endif

	float alpha = 1.0 - min(1.0, volumetric.transmittance);
	float energy = volumetric.lightEnergy;

	float rainBrightness = mix(0.13, 0.05, hdr_fromGammaf(frx_rainGradient())); // simulate dark clouds
	vec3 cloudShading = atmos_hdrCloudColorRadiance(worldVec) * mix(1.0, smoothstep(-0.5, 0.5, energy), abs(worldVec.y));
	vec3 celestRadiance = atmos_hdrCelestialRadiance();

	if (frx_worldFlag(FRX_WORLD_IS_MOONLIT)) {
		celestRadiance *= 0.2;
	}

	vec3 color;

	celestRadiance = celestRadiance * energy * rainBrightness * 0.5;
	color = celestRadiance + cloudShading;

	#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
		out_depth = alpha > 0. ? 0.9999 : 1.0;
	#else
		vec3 reverseModelPos = volumetric.worldPos - frx_cameraPos();
		vec4 reverseClipPos = frx_viewProjectionMatrix() * vec4(reverseModelPos, 1.0);

		reverseClipPos.z /= reverseClipPos.w;

		float backgroundDepth = texture(stranslucentDepth, texcoord).r;
		float alphaThreshold = backgroundDepth == 1. ? 0.5 : 0.; 

		out_depth = alpha > alphaThreshold ? reverseClipPos.z : 1.0;
	#endif

	return vec4(color, alpha);
}
#endif
