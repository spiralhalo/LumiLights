#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/contrast.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/prog/celest.glsl
#include lumi:shaders/prog/shadow.glsl
#include lumi:shaders/prog/tile_noise.glsl
#include lumi:shaders/prog/water.glsl

/*******************************************************
 *  lumi:shaders/prog/shading.glsl
 *******************************************************/

float fastLight(vec2 light, vec3 normal) {
	float reduction = max(1.0 - frx_skyLightTransitionFactor, frx_worldIsMoonlit);
		  reduction = max(reduction, max(0.5 * frx_rainGradient, frx_thunderGradient));

	float sun = 0.6 * max(0.0, dot(normal, frx_skyLightVector)) * (1.0 - 0.9 * reduction);
	float blockFactor = 1.0 - 0.8 * frx_worldHasSkylight * frx_smoothedEyeBrightness.y;
	float result = (light.x * blockFactor + light.y * (0.4 + mix(0.6, sun, frx_worldHasSkylight)) * (1.0 - blockFactor));

	// prevents overblown values when recovering the original as well as representing ambient light
	return 0.2 + 0.8 * result;
}

#ifdef POST_SHADER
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

#ifndef VERTEX_SHADER

float denoisedShadowFactor(sampler2DArrayShadow shadowMap, vec2 texcoord, vec3 eyePos, float depth, float lighty, vec3 vertexNormal) {
	// nasty
	float transitionClamping = l2_clampScale(0.0, 0.1, frx_skyLightTransitionFactor);

#ifdef SHADOW_MAP_PRESENT
#ifdef TAA_ENABLED
	// TODO: might as well apply unjitter to root shading eyePos?
	vec2 uvJitter	   = taaJitter(v_invSize, frx_renderFrames);
	vec4 unjitteredPos = frx_inverseViewProjectionMatrix * vec4(2.0 * texcoord - uvJitter - 1.0, 2.0 * depth - 1.0, 1.0);
	vec4 shadowViewPos = frx_shadowViewMatrix * vec4(unjitteredPos.xyz / unjitteredPos.w, 1.0);
#else
	vec4 shadowViewPos = frx_shadowViewMatrix * vec4(eyePos, 1.0);
#endif

	float val = calcShadowFactor(shadowMap, shadowViewPos, vertexNormal);

	// shadow workaround is dead. long live shadow workaround
// #ifdef SHADOW_WORKAROUND
// 	val *= l2_clampScale(0.03125, 0.04, lighty);
// #endif

	return val * transitionClamping;
#else
	return lighty * lighty * transitionClamping;
#endif
}

vec4 premultBlend(vec4 src, vec4 dst)
{
	float a = src.a + dst.a * (1.0 - src.a);
	vec3 color = src.rgb + dst.rgb * (1.0 - src.a);
	return vec4(color, a);
}

// ugh
bool notEndPortal(sampler2DArray lightNormalBuffer)
{
	vec3 A = texture(lightNormalBuffer, vec3(v_texcoord, ID_TRANS_LIGT)).xyz;
	vec3 B = texture(lightNormalBuffer, vec3(v_texcoord, ID_TRANS_NORM)).xyz;
	vec3 C = texture(lightNormalBuffer, vec3(v_texcoord, ID_TRANS_MNORM)).xyz;

	return !(A == B && A == C);
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

	return denom == 0.0 ? 0.0 : max(0.0, num / denom);
}

float pbr_geometrySchlickGGX(float NdotV, float roughness)
{
	float r = (roughness + 1.0);
	float k = (r*r) / 8.0;

	float num   = NdotV;
	float denom = NdotV * (1.0 - k) + k;
	
	return num / denom;
}

// #define FAST_GGX

float pbr_geometrySmith(float NdotV, float NdotL, float roughness)
{
	#ifdef FAST_GGX
	return 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, roughness * roughness);
	#else
	float ggx2  = pbr_geometrySchlickGGX(NdotV, roughness);
	float ggx1  = pbr_geometrySchlickGGX(NdotL, roughness);

	return ggx1 * ggx2;
	#endif
}

vec3 pbr_calcF0(vec3 albedo, vec2 material) {
	return mix(lightLuminance(albedo) * vec3(material.y), albedo, material.y);
	// return mix(vec3(material.y), albedo, step(1.0, material.y));
}

float pbr_fresnelSchlick(float cosTheta, float F0)
{
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 pbr_fresnelSchlick(float cosTheta, vec3 F0)
{
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 pbr_specularBRDF(float roughness, vec3 radiance, vec3 halfway, vec3 viewDir, vec3 normal, vec3 fresnel, float NdotL)
{
	float NdotV = pbr_dot(normal, viewDir);

	// cook-torrance brdf
	float distribution = pbr_distributionGGX(normal, halfway, roughness);
	float geometry	   = pbr_geometrySmith(NdotV, NdotL, roughness);

	vec3  num   = distribution * geometry * fresnel;
	float denom = 4.0 * NdotV * NdotL;

	vec3  specular = num / max(denom, 0.001);
	return specular * radiance * NdotL;
}

vec3 reflectRough(sampler2DArray resources, vec3 toFrag, vec3 normal, float materialx, out vec3 jitterPrc)
{
	const float strength = 0.6;
	vec3 jitterRaw = getRandomVec(resources, v_texcoord, frxu_size) * 2.0 - 1.0;
	jitterPrc = jitterRaw * strength * materialx * materialx;
	return normalize(reflect(toFrag, normal) + jitterPrc);
}

vec3 reflectRough(sampler2DArray resources, vec3 toFrag, vec3 normal, float materialx)
{
	vec3 ignored;
	return reflectRough(resources, toFrag, normal, materialx, ignored);
}

vec3 reflectionPbr(vec3 albedo, vec2 material, vec3 radiance, vec3 toLight, vec3 toEye)
{
	vec3 f0 = pbr_calcF0(albedo, material);
	vec3 halfway = normalize(toEye + toLight);
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(toEye, halfway), f0);
	float smoothness = (1. - material.x);

	return clamp(fresnel * radiance * smoothness * smoothness, 0.0, 1.0);
}

struct shadingResult {
	vec3 specular;
	vec3 diffuse;
} shading0;

float diffuseNdL(float NdotL, float alpha, float disableDiffuse, float dielectricity)
{
	float diffuseNdotL = mix(1.0, NdotL, alpha);
	diffuseNdotL = max(l2_softenUp(diffuseNdotL, 5.0), disableDiffuse);
	return diffuseNdotL;
}

void lightPbr(vec3 albedo, float alpha, vec3 radiance, float roughness, vec3 f0, vec3 toLight, vec3 toEye, vec3 halfway, vec3 normal, float disableDiffuse)
{
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(toEye, halfway), f0);
	float rawNdL = dot(normal, toLight);
	float NdotL  = clamp(rawNdL, 0.0, 1.0);

	// darken diffuse on conductive materials
	float dielectricity = 1.0 - l2_max3(f0);

	float diffuseNdotL = diffuseNdL(NdotL, alpha, disableDiffuse, dielectricity);

	shading0.specular = pbr_specularBRDF(roughness, radiance, halfway, toEye, normal, fresnel, NdotL);
	shading0.diffuse = albedo * radiance * diffuseNdotL * (1.0 - fresnel * step(0.0, rawNdL)) * dielectricity / PI;
}

void prepare(vec4 color, sampler2D natureTexture, vec3 eyePos, float vertexNormaly, bool isUnderwater, inout vec4 light)
{
	float causticLight = 0.0;

#ifdef WATER_CAUSTICS
	if (isUnderwater && frx_worldHasSkylight == 1) {
		causticLight  = caustics(natureTexture, eyePos + frx_cameraPos, vertexNormaly);
		causticLight *= 2.0;
		causticLight *= smoothstep(0.0, 1.0, light.y);
	}
#endif

#ifdef SHADOW_MAP_PRESENT
	causticLight *= max(0.15, light.w); // TODO: can improve even more?
#endif

	// this is mostly for underwater and acts as wide range "ambient occlusion"
	// replaces shadow workaround
	light.w *= lightmapRemap(light.y);

	// caustics is unclamped
	light.w += causticLight;
}

vec3 blockLightColor(float lightx, float blWhite) {
#if BLOCK_LIGHT_MODE != BLOCK_LIGHT_MODE_NEUTRAL
	vec3 blColor = mix(BLOCK_LIGHT_NEUTRAL, BLOCK_LIGHT_WARM, l2_clampScale(0.5, 0.7, lightx));
	blWhite = max(blWhite, atmosv_eyeAdaptation * 0.5);
	return mix(blColor, BLOCK_LIGHT_NEUTRAL, blWhite);
#else
	return BLOCK_LIGHT_NEUTRAL;
#endif
}

void lights(vec3 albedo, vec4 light, vec3 eyePos, vec3 toEye, out vec3 baseLight, out vec3 blockLight, out vec3 hlLight, out vec3 skyLight)
{
	float userBrightness = frx_viewBrightness <= 0.5 ? (0.5 + frx_viewBrightness) : (2.0 * frx_viewBrightness);

	baseLight = vec3(BASE_AMBIENT_STR);
	baseLight += hdr_fromGamma(NIGHT_VISION_COLOR) * NIGHT_VISION_STR * frx_effectNightVision;

	vec3 skylessColor = SKYLESS_LIGHT_COLOR * mix(USER_END_AMBIENT_MULTIPLIER, USER_NETHER_AMBIENT_MULTIPLIER * 0.25, frx_worldIsNether);

	baseLight += (1.0 - frx_worldHasSkylight) * skylessColor * SKYLESS_AMBIENT_STR;

	// user brightness afects every base ambient except for sky ambient (emissive isn't ambient)
	baseLight *= userBrightness;

	float remappedY = lightmapRemap(light.y);

	baseLight += atmosv_SkyAmbientRadiance * remappedY;
	baseLight += albedo * light.z * EMISSIVE_LIGHT_STR;

	float bl = l2_clampScale(0.03125, 0.96875, light.x);


	// exaggerate block light
	#define BL_MULT 3.0
	bl = clamp(pow(bl, 0.5 + BL_MULT / 2.0) * BL_MULT, 0.0, BL_MULT); // unnecessary if BL_MULT is 1
	bl += pow(l2_clampScale(0.7, 0.96875, light.x), 2.0) * 3.0;

	// makes builds look better outside
	float adaptationTerm = mix(1.0, 0.5 / BL_MULT, atmosv_eyeAdaptation);

	vec3 blColor = blockLightColor(light.x, light.z);
	
	blockLight = blColor * BLOCK_LIGHT_STR * bl * adaptationTerm;
	blockLight *= 0.7 + userBrightness * 0.4;

	hlLight = vec3(0.0);
#if HANDHELD_LIGHT_RADIUS != 0
	if (frx_heldLight.w > 0) {
		vec3 toLight = toEye;

		vec4 heldLight = frx_heldLight;
		float cosView  = max(dot(toLight, pbrv_flashLightView), 0.0);
		float cone	   = l2_clampScale(1.0 - pbrv_coneOuter, 1.0 - pbrv_coneInner, cosView);
		float distSq   = dot(eyePos, eyePos);
		float hlRadSq  = heldLight.w * HANDHELD_LIGHT_RADIUS * heldLight.w * HANDHELD_LIGHT_RADIUS;
		float hl	   = hdr_fromGammaf(l2_clampScale(hlRadSq, 0.0, distSq)) * cone;

		hlLight = hdr_fromGamma(heldLight.rgb) * BLOCK_LIGHT_STR * hl * adaptationTerm;
	}
#endif

	skyLight = frx_worldHasSkylight * light.w * mix(atmosv_CelestialRadiance, vec3(frx_skyFlashStrength * LIGHTNING_FLASH_STR), frx_smoothedRainGradient);

	float darkness = pow(frx_darknessEffectFactor, 2.0);
	baseLight *= 0.1 + 0.9 * darkness;
	blockLight *= 0.5 + 0.5 * darkness;
	skyLight *= 0.1 + 0.9 * darkness;
}

// #if ALBEDO_BRIGHTENING == 0
// #define hdrAlbedo(color) hdr_fromGamma(color.rgb)
// #else
// #define hdrAlbedo(color) hdr_fromGamma(color.rgb) * (1.0 - USER_ALBEDO_BRIGHTENING) + vec3(USER_ALBEDO_BRIGHTENING)
// #endif

#define hdrAlbedo(color) hdr_fromGamma(color.rgb) * vec3(0.98, 0.96, 0.94) * 0.98 + 0.02

vec4 shading(vec4 color, sampler2D natureTexture, vec4 light, float ao, vec2 material, vec3 eyePos, vec3 normal, vec3 vertexNormal, bool isUnderwater, float disableDiffuse)
{
	vec3 albedo = hdrAlbedo(color);

	// unmanaged
	if (light.x == 0.0) return vec4(albedo, color.a);

	prepare(color, natureTexture, eyePos, vertexNormal.y, isUnderwater, light);

	vec3 f0 = pbr_calcF0(albedo, material);
	vec3 toEye = -normalize(eyePos);

	vec3 baseLight, blockLight, hlLight, skyLight;

	lights(albedo, light, eyePos, toEye, baseLight, blockLight, hlLight, skyLight);

	// block light fresnel
	vec3 blH = normalize(toEye + normal);
	vec3 blF = pbr_fresnelSchlick(pbr_dot(toEye, blH), f0);
	// vanilla-ish style diffuse
	const vec3 upNorth = vec3(0, 0.5547, -0.83205);
	float dotPerfect = 0.5 + 0.5 * max(0.0, dot(normal, upNorth));
	// perfect diffuse light
	vec3 shaded = albedo * (baseLight + blockLight * (1.0 - blF)) * (1.0 - material.y * 0.5) / PI;
	// block light specular
	vec3 specular = pbr_specularBRDF(max(material.x, 0.5 * material.y), blockLight, blH, toEye, normal, blF, 1.0);
	shaded += specular;

	lightPbr(albedo, color.a, hlLight, material.x, f0, toEye, toEye, toEye, normal, disableDiffuse);
	shaded += shading0.specular + shading0.diffuse;
	specular += shading0.specular;

	lightPbr(albedo, color.a, skyLight, material.x, f0, frx_skyLightVector, toEye, normalize(toEye + frx_skyLightVector), normal, disableDiffuse);
	shaded += shading0.specular + shading0.diffuse;
	specular += shading0.specular;

	ao = min(1.0, ao + light.z);
	ao = pow(ao, mix(1.0, SSAO_INTENSITY, lightLuminance(shaded / max(vec3(0.01), albedo)) * 0.5));

	shaded *= ao;
	specular *= ao;

	// emulate refraction, becoming opaque as less light is let through
	float alpha = pbr_fresnelSchlick(pbr_dot(toEye, vertexNormal), color.a);
	alpha += lightLuminance(specular);

	return vec4(shaded, min(1.0, alpha));
}

vec4 particleShading(vec4 color, sampler2D natureTexture, vec4 light, vec3 eyePos, bool isUnderwater)
{
	vec3 albedo = hdrAlbedo(color);
	
	// unmanaged
	if (light.x == 0.0) return vec4(albedo, color.a);

	vec3 toEye = -normalize(eyePos);
	prepare(color, natureTexture, eyePos, 1.0, isUnderwater, light);

	vec3 baseLight, blockLight, hlLight, skyLight;

	lights(albedo, light, eyePos, toEye, baseLight, blockLight, hlLight, skyLight);

	vec3 shaded = albedo * (baseLight + blockLight + hlLight);
	shaded += albedo * skyLight;

	return vec4(shaded / PI, color.a);
}

vec4 shading(vec4 color, sampler2D natureTexture, vec4 light, vec3 rawMat, vec3 eyePos, vec3 normal, vec3 vertexNormal, bool isUnderwater, float disableDiffuse) {
	return shading(color, natureTexture, light, rawMat.z, rawMat.xy, eyePos, normal, vertexNormal, isUnderwater, disableDiffuse);
}
#endif
#endif
