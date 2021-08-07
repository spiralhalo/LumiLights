#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/common/contrast.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/block_dir.glsl

/*******************************************************
 *  lumi:shaders/func/pbr_shading.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

const vec3 skylessDarkenedDir = vec3(0, -0.977358, 0.211593);
const vec3 skylessDir = vec3(0, 0.977358, 0.211593);

float lightmapRemap(float lightMapCoords)
{
	return hdr_fromGammaf(l2_clampScale(0.03125, 0.96875, lightMapCoords));
}

const float PBR_SPECULAR_BLOOM_ADD = 0.01;
const float PBR_SPECULAR_ALPHA_ADD = 0.01;

vec3 pbr_fakeMetallicDiffuseMultiplier(vec3 albedo, float metallic, vec3 radiance)
{
	return mix(vec3(1.0), albedo * frx_luminance(clamp(radiance, 0.0, 1.0)) * 0.25, metallic);
}

vec3 pbr_nonDirectional(vec3 albedo, float metallic, vec3 radiance)
{
	return albedo * pbr_fakeMetallicDiffuseMultiplier(albedo, metallic, radiance) / PI * radiance;
}

vec3 pbr_lightCalc(vec3 albedo, float roughness, float metallic, vec3 pbr_f0, vec3 radiance, vec3 lightDir, vec3 viewDir, vec3 normal, float translucency, bool diffuseOn, inout vec3 specularAccu)
{
	vec3 halfway = normalize(viewDir + lightDir);
	// disableDiffuse hack
	if (!diffuseOn) {
		return albedo / PI * radiance * pbr_dot(lightDir, vec3(.0, 1.0, .0));
	}
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(viewDir, halfway), pbr_f0);
	float NdotL = pbr_dot(normal, lightDir);
	vec3 specularRadiance = pbr_specularBRDF(roughness, radiance, halfway, lightDir, viewDir, normal, fresnel, NdotL);
	//Fake metallic diffuse applied
	float diffuseNdotL = mix(NdotL, 1.0, translucency); // let more light pass through translucent objects
	vec3 diffuse = (1.0 - fresnel);
	vec3 diffuseRadiance = albedo * pbr_fakeMetallicDiffuseMultiplier(albedo, metallic, radiance) / PI * radiance * diffuseNdotL;
	specularAccu += specularRadiance;
	return specularRadiance + diffuseRadiance;
}

struct light_data{
	bool diffuse;
	vec3 albedo;
	float roughness;
	float metallic;
	vec3 f0;
	vec3 light;
	vec3 normal;
	vec3 viewDir;
	vec3 modelPos;
	vec3 specularAccu;
	float translucency;
};

vec3 hdr_calcBlockLight(inout light_data data, in float bloom)
{
	float bl = smoothstep(0.03125, 0.96875, data.light.x);
	float brightness = frx_viewBrightness();

	bl *= pow(bl, 3.0 + brightness * 2.0) * (2.0 - brightness * 0.5); // lyfe hax
	
	vec3 color = mix(BLOCK_LIGHT_COLOR, data.albedo / l2_max3(data.albedo), bloom);
	vec3 radiance = color * BLOCK_LIGHT_STR * bl;

	bool useFancySpecular = data.diffuse;
	#if BLOCKLIGHT_SPECULAR_MODE == BLOCKLIGHT_SPECULAR_MODE_FAST
		useFancySpecular = useFancySpecular && data.metallic > 0.0;
	#endif
	
	if (!useFancySpecular) return pbr_nonDirectional(data.albedo, data.metallic, radiance);
	
	#if BLOCKLIGHT_SPECULAR_MODE == BLOCKLIGHT_SPECULAR_MODE_FANTASTIC
		vec3 lightDir = preCalc_blockDir;
	#else
		vec3 lightDir = data.normal;
	#endif

	// low fancy specular smoothness for metals
	float roughness = mix(data.roughness, max(0.4, data.roughness), data.metallic);
	// harshly lower f0 the further away from light source for non-metal
	vec3 f0 = data.f0 * mix(l2_clampScale(0.5, 0.96875, data.light.x), 1.0, data.metallic);
	
	return pbr_lightCalc(data.albedo, roughness, data.metallic, f0, radiance, lightDir, data.viewDir, data.normal, data.translucency, true, data.specularAccu);
}

vec3 hdr_calcHeldLight(inout light_data data)
{
#if HANDHELD_LIGHT_RADIUS != 0
	if (frx_heldLight().w > 0) {
		vec3 handHeldDir = data.viewDir;

		vec4 heldLight = frx_heldLight();
		float coneInner = clamp(frx_heldLightInnerRadius(), 0.0, 3.14159265359) / 3.14159265359;
		float coneOuter = max(coneInner, clamp(frx_heldLightOuterRadius(), 0.0, 3.14159265359) / 3.14159265359);
		float cosView = max(dot(handHeldDir, -frx_cameraView()), 0.0);
		float cone = l2_clampScale(1.0 - coneOuter, 1.0 - coneInner, cosView);
		float distSq = dot(data.modelPos, data.modelPos);
		float hlRadSq = heldLight.w * HANDHELD_LIGHT_RADIUS * heldLight.w * HANDHELD_LIGHT_RADIUS;
		float hl = l2_clampScale(hlRadSq, 0.0, distSq);
		float brightness = frx_viewBrightness();

		hl *= pow(hl, 3.0 + brightness * 2.0) * (2.0 - brightness * 0.5); // lyfe hax
		hl *= cone;

		vec3 handHeldRadiance = hdr_fromGamma(heldLight.rgb) * BLOCK_LIGHT_STR * hl;

		if (handHeldRadiance.x + handHeldRadiance.y + handHeldRadiance.z > 0) {
			vec3 adjustedNormal = data.diffuse ? data.normal : data.viewDir;
			return pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, handHeldRadiance, handHeldDir, data.viewDir, adjustedNormal, data.translucency, true, data.specularAccu);
		}
	}
#endif
	return vec3(0.0);
}

vec3 hdr_calcSkyLight(inout light_data data)
{
	if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
		vec3 celestialRad = data.light.z * atmos_hdrCelestialRadiance() * (1. - frx_rainGradient()); // no direct sunlight during rain
		return pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, celestialRad, frx_skyLightVector(), data.viewDir, data.normal, data.translucency, data.diffuse, data.specularAccu);
	} else {

	#ifdef TRUE_DARKNESS_END
		if (frx_worldFlag(FRX_WORLD_IS_END)) return vec3(0.0);
	#endif

		vec3 color = SKYLESS_LIGHT_COLOR;

		if (frx_worldFlag(FRX_WORLD_IS_NETHER)) {
		#ifdef TRUE_DARKNESS_NETHER
			return vec3(0.0);
		#endif
			color = NETHER_SKYLESS_LIGHT_COLOR;
		}

		float darkenedFactor = frx_isSkyDarkened() ? 0.6 : 1.0;
		vec3 skylessRadiance = darkenedFactor * SKYLESS_LIGHT_STR * color;
		vec3 skylessLight = pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, skylessRadiance, skylessDir, data.viewDir, data.normal, data.translucency, data.diffuse, data.specularAccu);

		if (frx_isSkyDarkened()) {
			skylessLight += pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, skylessRadiance, skylessDarkenedDir, data.viewDir, data.normal, data.translucency, data.diffuse, data.specularAccu);
		}

		return skylessLight;
	}
}

vec3 emissiveRadiance(vec3 hdrFragColor, float emissivity)
{
	return hdrFragColor * emissivity * EMISSIVE_LIGHT_STR;
}

vec3 baseAmbientRadiance(vec3 fogRadiance)
{
	vec3 bar = vec3(0.0);

	#ifndef TRUE_DARKNESS_DEFAULT
		bar += vec3(BASE_AMBIENT_STR);
	#endif

	if (frx_playerHasNightVision()) {
		bar += hdr_fromGamma(NIGHT_VISION_COLOR) * NIGHT_VISION_STR;
	}

	if (!frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
		bar += fogRadiance * SKYLESS_AMBIENT_STR * 0.5;
		bar += vec3(SKYLESS_AMBIENT_STR) * 0.5;
	}

	return bar;
}

void pbr_shading(inout vec4 a, inout float bloom, vec3 modelPos, vec3 light, vec3 normal, float roughness, float metallic, float pbr_f0, bool isDiffuse, bool translucent)
{
	vec3 albedo = hdr_fromGamma(a.rgb);
	light_data data = light_data(
		isDiffuse,
		albedo,
		roughness,
		metallic,
		mix(vec3(pbr_f0), albedo, metallic),
		light,
		normal,
		normalize(-modelPos),
		modelPos,
		vec3(0.0),
		(translucent && a.a > 0.) ? (1.0 - min(a.a, 1.0)) : 0.0
	);

	vec3 held_light  = hdr_calcHeldLight(data);
	vec3 block_light = hdr_calcBlockLight(data, bloom);
	vec3 sky_light   = hdr_calcSkyLight(data);

	vec3 ndRadiance = baseAmbientRadiance(atmosv_hdrFogColorRadiance);

	ndRadiance += atmos_hdrSkyAmbientRadiance() * lightmapRemap(data.light.y);
	ndRadiance += emissiveRadiance(data.albedo, bloom);

	vec3 nd_light = pbr_nonDirectional(data.albedo, data.metallic, ndRadiance);

	a.rgb = held_light + block_light + sky_light + nd_light;

	float specularLuminance = frx_luminance(data.specularAccu);
	float smoothness = 1 - data.roughness;
	bloom += specularLuminance * PBR_SPECULAR_BLOOM_ADD * smoothness * smoothness; 
	if (translucent && data.diffuse) {
		float opacityLerp = a.a > 0.0 ? pow(1.0 - pbr_dot(data.viewDir, data.normal), 5.0) : 0.0;
		// make sure opacity interpolation doesn't make it excessively brighter.
		float luminanceCompensation = (1.0 - a.a) * opacityLerp;
		a.a += (1.0 - a.a) * opacityLerp;
		a.rgb *= hdr_fromGammaf(1.0 - luminanceCompensation);

		a.a += specularLuminance * PBR_SPECULAR_ALPHA_ADD;
	}
}
