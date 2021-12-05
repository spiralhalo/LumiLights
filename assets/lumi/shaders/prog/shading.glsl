#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/contrast.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/prog/shadow.glsl
#include lumi:shaders/prog/water.glsl

/*******************************************************
 *  lumi:shaders/prog/shading.glsl
 *******************************************************/

// TODO: make better ?
const vec3 skylessDarkenedDir = vec3(0, -0.977358, 0.211593);
const vec3 skylessDir = vec3(0, 0.977358, 0.211593);

/*******************************************************
 *  vertexShader: lumi:shaders/post/shading.vert
 *******************************************************/

l2_vary float pbrv_coneInner;
l2_vary float pbrv_coneOuter;
l2_vary vec3  pbrv_flashLightView;

#ifdef VERTEX_SHADER
void shadingSetup() {
	// const vec3 view_CV	= vec3(0.0, 0.0, -1.0); //camera view in view space
	// float cAngle		= asin(frx_cameraView.y);
	// float hlAngle		= clamp(HANDHELD_LIGHT_ANGLE, -45, 45) * PI / 180.0;
	// pbrv_flashLightView = (l2_rotationMatrix(vec3(1.0, 0.0, 0.0), l2_clampScale(abs(hlAngle), 0.0, abs(cAngle)) * hlAngle) * vec4(-view_CV, 0.0)).xyz;
	// pbrv_flashLightView = normalize(pbrv_flashLightView * frx_normalModelMatrix);

	pbrv_flashLightView = -frx_cameraView;
	pbrv_coneInner = clamp(frx_heldLightInnerRadius, 0.0, PI) / PI;
	pbrv_coneOuter = max(pbrv_coneInner, clamp(frx_heldLightOuterRadius, 0.0, PI) / PI);
}
#endif

float lightmapRemap(float lightMapCoords)
{
	return hdr_fromGammaf(l2_clampScale(0.03125, 0.96875, lightMapCoords));
}

#ifndef VERTEX_SHADER
float denoisedShadowFactor(sampler2DArrayShadow shadowMap, vec2 texcoord, vec3 eyePos, float depth, float lighty) {
#ifdef SHADOW_MAP_PRESENT
#ifdef TAA_ENABLED
	vec2 uvJitter	   = taa_jitter(v_invSize);
	vec4 unjitteredPos = frx_inverseViewProjectionMatrix * vec4(2.0 * texcoord - uvJitter - 1.0, 2.0 * depth - 1.0, 1.0);
	vec4 shadowViewPos = frx_shadowViewMatrix * vec4(unjitteredPos.xyz / unjitteredPos.w, 1.0);
#else
	vec4 shadowViewPos = frx_shadowViewMatrix * vec4(eyePos, 1.0);
#endif

	float val = calcShadowFactor(shadowMap, shadowViewPos);

#ifdef SHADOW_WORKAROUND
	val *= l2_clampScale(0.03125, 0.04, lighty);
#endif

	return val;
#else
	return lighty;
#endif
}

#define pbr_dot(a, b) clamp(dot(a, b), 0.0, 1.0)

float pbr_distributionGGX(vec3 N, vec3 H, float roughness)
{
	float a		 = roughness*roughness;
	float a2	 = a*a;
	float NdotH  = pbr_dot(N, H);
	float NdotH2 = NdotH*NdotH;

	float num   = a2;
	float denom = (NdotH2 * (a2 - 1.0) + 1.0);
		  denom = PI * denom * denom;

	return max(0.0, num / denom);
}

float pbr_geometrySchlickGGX(float NdotV, float roughness)
{
	float r = (roughness + 1.0);
	float k = (r*r) / 8.0;

	float num   = NdotV;
	float denom = NdotV * (1.0 - k) + k;
	
	return num / denom;
}

float pbr_geometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
	float NdotV = pbr_dot(N, V);
	float NdotL = pbr_dot(N, L);
	float ggx2  = pbr_geometrySchlickGGX(NdotV, roughness);
	float ggx1  = pbr_geometrySchlickGGX(NdotL, roughness);

	return ggx1 * ggx2;
}

vec3 pbr_fresnelSchlick(float cosTheta, vec3 F0)
{
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 pbr_specularBRDF(float roughness, vec3 radiance, vec3 halfway, vec3 lightDir, vec3 viewDir, vec3 normal, vec3 fresnel, float NdotL)
{
	// cook-torrance brdf
	float distribution = pbr_distributionGGX(normal, halfway, roughness);
	float geometry	   = pbr_geometrySmith(normal, viewDir, lightDir, roughness);

	vec3  num   = distribution * geometry * fresnel;
	float denom = 4.0 * pbr_dot(normal, viewDir) * NdotL;

	vec3  specular = num / max(denom, 0.001);
	return specular * radiance * NdotL;
}

vec3 reflectionPbr(vec3 albedo, vec3 material, vec3 radiance, vec3 toLight, vec3 toEye)
{
	vec3 f0 = mix(vec3(material.z), albedo, material.y);
	vec3 halfway = normalize(toEye + toLight);
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(toEye, halfway), f0);
	float smoothness = (1. - material.x);

	return clamp(fresnel * radiance * smoothness * smoothness, 0.0, 1.0);
}

vec3 lightPbr(vec3 albedo, float alpha, vec3 radiance, float roughness, float metallic, vec3 f0, vec3 toLight, vec3 toEye, vec3 normal)
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

vec4 shading(vec4 color, sampler2D natureTexture, vec4 light, float ao, vec3 material, vec3 eyePos, vec3 normal, bool isUnderwater)
{
	float causticLight = 0.0;

#ifdef WATER_CAUSTICS
	if (isUnderwater && frx_worldHasSkylight == 1) {
		causticLight  = caustics(natureTexture, eyePos + frx_cameraPos, normal.y);
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

#ifdef VANILLA_AO_ENABLED
	ao = min(1., light.z);
	light.z = max(0., light.z - ao);
#endif

	float luminance = frx_luminance(color.rgb);
	float vanillaEmissive = step(0.93625, light.x) * luminance * luminance;

	light.z += vanillaEmissive;

	vec3 albedo = hdr_fromGamma(color.rgb);
	vec3 f0 = mix(vec3(material.z), albedo, material.y); // TODO: multiply metallic f0?

	vec3 toEye = -normalize(eyePos);

	vec3 baseLight = vec3(BASE_AMBIENT_STR * USER_AMBIENT_MULTIPLIER);
		 baseLight += hdr_fromGamma(NIGHT_VISION_COLOR) * NIGHT_VISION_STR * frx_effectNightVision;
		 baseLight += frx_worldHasSkylight == 0 ? (atmosv_hdrFogColorRadiance + 1.0) * SKYLESS_AMBIENT_STR * 0.5 : vec3(0.0);

	float bl = l2_clampScale(0.03125, 0.96875, light.x);

	float blWhite = max(light.z, step(0.93625, light.x));
	vec3  blColor = mix(BLOCK_LIGHT_COLOR, BLOCK_LIGHT_NEUTRAL, blWhite);

	baseLight += blColor * BLOCK_LIGHT_STR * bl;
	baseLight += atmosv_hdrSkyAmbientRadiance * lightmapRemap(light.y);
	baseLight += albedo * light.z * EMISSIVE_LIGHT_STR;

	vec3 shaded = lightPbr(albedo, color.a, baseLight, max(material.x * (1.0 - material.y), 0.5), material.y, f0, normal, toEye, normal);

#if HANDHELD_LIGHT_RADIUS != 0
	if (frx_heldLight.w > 0) {
		vec3 toLight = toEye;

		vec4 heldLight = frx_heldLight;
		float cosView  = max(dot(toLight, pbrv_flashLightView), 0.0);
		float cone	   = l2_clampScale(1.0 - pbrv_coneOuter, 1.0 - pbrv_coneInner, cosView);
		float distSq   = dot(eyePos, eyePos);
		float hlRadSq  = heldLight.w * HANDHELD_LIGHT_RADIUS * heldLight.w * HANDHELD_LIGHT_RADIUS;
		float hl	   = hdr_fromGammaf(l2_clampScale(hlRadSq, 0.0, distSq));

		hl *= cone;

		vec3 hlLight = hdr_fromGamma(heldLight.rgb) * BLOCK_LIGHT_STR * hl;

		shaded += lightPbr(albedo, color.a, hlLight, material.x, material.y, f0, toLight, toEye, normal);
	}
#endif

	shaded *= ao;

	vec3 skyLight = frx_worldHasSkylight * light.w * atmosv_hdrCelestialRadiance * (1. - frx_rainGradient);
		 skyLight += frx_worldIsNether * NETHER_SKYLESS_LIGHT_COLOR * USER_NETHER_AMBIENT_MULTIPLIER;
		 skyLight += (1.0 - max(frx_worldHasSkylight, frx_worldIsNether)) * SKYLESS_LIGHT_COLOR * USER_END_AMBIENT_MULTIPLIER;

	vec3 toLight = (frx_worldHasSkylight == 1) ? frx_skyLightVector : ((frx_worldIsSkyDarkened == 1) ? skylessDarkenedDir : skylessDir);

	shaded += lightPbr(albedo, color.a, skyLight, material.x, material.y, f0, toLight, toEye, normal);

	return vec4(shaded, color.a);
}

vec4 shading(vec4 color, sampler2D natureTexture, vec4 light, vec3 material, vec3 eyePos, vec3 normal, bool isUnderwater) {
	return shading(color, natureTexture, light, 1.0, material, eyePos, normal, isUnderwater);
}
#endif
