#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/contrast.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/prog/shading.glsl
 *******************************************************/

// TODO: make better ?
const vec3 skylessDarkenedDir = vec3(0, -0.977358, 0.211593);
const vec3 skylessDir = vec3(0, 0.977358, 0.211593);

/*******************************************************
 *  vertexShader: lumi:shaders/post/shading.vert
 *******************************************************/

// TODO: make lumi_vary but optimize includes?
in float pbrv_coneInner;
in float pbrv_coneOuter;
in vec3  pbrv_flashLightView;

float lightmapRemap(float lightMapCoords)
{
	return hdr_fromGammaf(l2_clampScale(0.03125, 0.96875, lightMapCoords));
}

vec3 pbr_lightCalc(vec3 albedo, float alpha, vec3 radiance, float roughness, float metallic, vec3 f0, vec3 toLight, vec3 toEye, vec3 normal)
{
	vec3 halfway = normalize(toEye + toLight);
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(toEye, halfway), f0);
	float NdotL  = pbr_dot(normal, toLight);

	//fake metallic diffuse
	metallic = min(0.5, metallic);

	float diffuseNdotL = mix(1.0, NdotL, alpha * alpha * alpha);
	vec3 specularLight = pbr_specularBRDF(roughness, radiance, halfway, toLight, toEye, normal, fresnel, NdotL);
	vec3  diffuseLight = albedo * radiance * diffuseNdotL * (1.0 - fresnel) * (1.0 - metallic) / PI;

	return specularLight + diffuseLight;
}

vec4 shading(vec4 color, vec4 light, vec3 material, vec3 eyePos, vec3 normal, bool isUnderwater)
{
	float causticLight = 0.0;

#ifdef WATER_CAUSTICS
	if (isUnderwater && frx_worldHasSkylight == 1) {
		causticLight  = caustics(eyePos + frx_cameraPos);
		causticLight  = pow(causticLight, 15.0);
		causticLight *= smoothstep(0.0, 1.0, light.y);
	}
#endif

#ifdef SHADOW_MAP_PRESENT
	causticLight *= max(0.15, light.w); // TODO: can improve even more?

	if (isUnderwater || frx_cameraInWater == 1) {
		light.w *= lightmapRemap(light.y);
	}
#endif

	light.w += causticLight;

	vec3 albedo = hdr_fromGamma(color.rgb);
	vec3 f0 = mix(vec3(material.z), albedo, material.y); // TODO: multiply metallic f0?

	vec3 toEye = -normalize(eyePos);

	vec3 baseLight = vec3(BASE_AMBIENT_STR * USER_AMBIENT_MULTIPLIER);
		 baseLight += hdr_fromGamma(NIGHT_VISION_COLOR) * NIGHT_VISION_STR * frx_effectNightVision;
		 baseLight += frx_worldHasSkylight == 0 ? (atmosv_hdrFogColorRadiance + 1.0) * SKYLESS_AMBIENT_STR * 0.5 : vec3(0.0);

	float bl = smoothstep(0.03125, 0.96875, light.x);
		  bl *= pow(bl, 3.0 + frx_viewBrightness * 2.0) * (2.0 - frx_viewBrightness * 0.5); // lyfe hax

	float blWhite = max(light.z, step(0.93625, light.x));
	vec3  blColor = mix(BLOCK_LIGHT_COLOR, BLOCK_LIGHT_NEUTRAL, blWhite);

	baseLight += blColor * BLOCK_LIGHT_STR * bl;
	baseLight += atmos_hdrSkyAmbientRadiance() * lightmapRemap(light.y);
	baseLight += albedo * light.z * EMISSIVE_LIGHT_STR;

	vec3 shaded = pbr_lightCalc(albedo, color.a, baseLight, max(material.x * (1.0 - material.y), 0.5), material.y, f0, normal, toEye, normal);

#if HANDHELD_LIGHT_RADIUS != 0
	if (frx_heldLight.w > 0) {
		vec3 toLight = toEye;

		vec4 heldLight = frx_heldLight;
		float cosView  = max(dot(toLight, pbrv_flashLightView), 0.0);
		float cone	   = l2_clampScale(1.0 - pbrv_coneOuter, 1.0 - pbrv_coneInner, cosView);
		float distSq   = dot(eyePos, eyePos);
		float hlRadSq  = heldLight.w * HANDHELD_LIGHT_RADIUS * heldLight.w * HANDHELD_LIGHT_RADIUS;
		float hl	   = l2_clampScale(hlRadSq, 0.0, distSq);

		hl *= pow(hl, 3.0 + frx_viewBrightness * 2.0) * (2.0 - frx_viewBrightness * 0.5); // lyfe hax
		hl *= cone;

		vec3 hlLight = hdr_fromGamma(heldLight.rgb) * BLOCK_LIGHT_STR * hl;

		shaded += pbr_lightCalc(albedo, color.a, hlLight, material.x, material.y, f0, toLight, toEye, normal);
	}
#endif

	vec3 skyLight = frx_worldHasSkylight * light.w * atmos_hdrCelestialRadiance() * (1. - frx_rainGradient);
		 skyLight += frx_worldIsNether * NETHER_SKYLESS_LIGHT_COLOR * USER_NETHER_AMBIENT_MULTIPLIER;
		 skyLight += (1.0 - max(frx_worldHasSkylight, frx_worldIsNether)) * SKYLESS_LIGHT_COLOR * USER_END_AMBIENT_MULTIPLIER;

	vec3 toLight = (frx_worldHasSkylight == 1) ? frx_skyLightVector : ((frx_worldIsSkyDarkened == 1) ? skylessDarkenedDir : skylessDir);

	shaded += pbr_lightCalc(albedo, color.a, skyLight, material.x, material.y, f0, toLight, toEye, normal);
	color.a += color.a > 0.0 ? (1.0 - color.a) * pow(1.0 - pbr_dot(toEye, normal), 5.0) : 0.0;

	return vec4(shaded, color.a);
}
