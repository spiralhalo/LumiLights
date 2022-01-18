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
#include lumi:shaders/prog/shadow.glsl
#include lumi:shaders/prog/tile_noise.glsl
#include lumi:shaders/prog/water.glsl

/*******************************************************
 *  lumi:shaders/prog/shading.glsl
 *******************************************************/

float fastLight(vec2 light) {
	float reduction = max(1.0 - frx_skyLightTransitionFactor, frx_worldIsMoonlit);
		  reduction = max(reduction, max(0.5 * frx_rainGradient, frx_thunderGradient));

	return max(light.x, light.y * (1.0 - 0.9 * reduction));
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

float lightmapRemap(float lightMapCoords)
{
	return hdr_fromGammaf(l2_clampScale(0.03125, 0.96875, lightMapCoords));
}

#ifndef VERTEX_SHADER
float denoisedShadowFactor(sampler2DArrayShadow shadowMap, vec2 texcoord, vec3 eyePos, float depth, float lighty) {
#ifdef SHADOW_MAP_PRESENT
#ifdef TAA_ENABLED
	vec2 uvJitter	   = taaJitter(v_invSize, frx_renderFrames);
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
	return lighty * lighty;
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
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 10.0);
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

vec3 reflectRough(sampler2D noiseTexture, vec3 toFrag, vec3 normal, float materialx, out vec3 jitterPrc)
{
	const float strength = 0.6;
	vec3 jitterRaw = getRandomVec(noiseTexture, v_texcoord, frxu_size) * 2.0 - 1.0;
	jitterPrc = jitterRaw * strength * materialx * materialx;
	return normalize(reflect(toFrag, normal) + jitterPrc);
}

vec3 reflectRough(sampler2D noiseTexture, vec3 toFrag, vec3 normal, float materialx)
{
	vec3 ignored;
	return reflectRough(noiseTexture, toFrag, normal, materialx, ignored);
}

vec3 reflectionPbr(vec3 albedo, vec2 material, vec3 radiance, vec3 toLight, vec3 toEye)
{
	vec3 f0 = mix(vec3(0.01), albedo, material.y);
	vec3 halfway = normalize(toEye + toLight);
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(toEye, halfway), f0);
	float smoothness = (1. - material.x);

	return clamp(fresnel * radiance * smoothness * smoothness, 0.0, 1.0);
}

struct shadingResult {
	vec3 specular;
	vec3 diffuse;
} shading0;

float diffuseNdL(float NdotL, float alpha, float disableDiffuse)
{
	float diffuseNdotL = mix(1.0, NdotL, alpha);

	#ifdef SHADOW_MAP_PRESENT
	diffuseNdotL += (1.0 - diffuseNdotL) * disableDiffuse * 0.5;
	#else
	diffuseNdotL += (1.0 - diffuseNdotL) * disableDiffuse;
	#endif

	return diffuseNdotL;
}

void lightPbr(vec3 albedo, float alpha, vec3 radiance, float roughness, float metallic, vec3 f0, vec3 toLight, vec3 toEye, vec3 normal, float disableDiffuse)
{
	vec3 halfway = normalize(toEye + toLight);
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(toEye, halfway), f0);
	float rawNdL = dot(normal, toLight);
	float NdotL  = clamp(rawNdL, 0.0, 1.0);

	//fake metallic diffuse
	metallic = min(0.5, metallic);

	float diffuseNdotL = diffuseNdL(NdotL, alpha, disableDiffuse);

	shading0.specular = pbr_specularBRDF(roughness, radiance, halfway, toLight, toEye, normal, fresnel, NdotL);
	shading0.diffuse = albedo * radiance * diffuseNdotL * (1.0 - fresnel * step(0.0, rawNdL)) * (1.0 - metallic) / PI;
}

void prepare(vec4 color, sampler2D natureTexture, vec3 eyePos, float vertexNormaly, bool isUnderwater, inout vec4 light)
{
	float causticLight = 0.0;

#ifdef WATER_CAUSTICS
	if (isUnderwater && frx_worldHasSkylight == 1) {
		causticLight  = caustics(natureTexture, eyePos + frx_cameraPos, vertexNormaly);
		causticLight  = pow(causticLight, 15.0);
		causticLight *= smoothstep(0.0, 1.0, light.y);
	}
#endif

#ifdef SHADOW_MAP_PRESENT
	causticLight *= max(0.15, light.w); // TODO: can improve even more?
#endif

	if (isUnderwater) {
		light.w *= lightmapRemap(light.y);
	}

	light.w += causticLight;

	float luminance = frx_luminance(color.rgb);
	float vanillaEmissive = step(0.93625, light.x) * luminance * luminance;

	light.z += vanillaEmissive;
}

void lights(vec3 albedo, vec4 light, vec3 eyePos, vec3 toEye, out vec3 baseLight, out vec3 blockLight, out vec3 hlLight, out vec3 skyLight)
{
	baseLight = vec3(BASE_AMBIENT_STR * USER_AMBIENT_MULTIPLIER);
	baseLight += hdr_fromGamma(NIGHT_VISION_COLOR) * NIGHT_VISION_STR * frx_effectNightVision;

	vec3 skylessColor = mix(SKYLESS_LIGHT_COLOR * USER_END_AMBIENT_MULTIPLIER, NETHER_LIGHT_COLOR * USER_NETHER_AMBIENT_MULTIPLIER, frx_worldIsNether);

	baseLight += (1.0 - frx_worldHasSkylight) * (atmosv_FogRadiance * 0.5 + 0.5) * SKYLESS_AMBIENT_STR;
	baseLight += (1.0 - frx_worldHasSkylight) * skylessColor * SKYLESS_AMBIENT_STR;
	baseLight += atmosv_SkyAmbientRadiance * lightmapRemap(light.y);
	baseLight += albedo * light.z * EMISSIVE_LIGHT_STR;

	float bl = l2_clampScale(0.03125, 0.96875, light.x);
	vec3 blColor = BLOCK_LIGHT_COLOR;
	
	// makes builds look better outside
	float sunAdaptation = frx_smoothedEyeBrightness.y * lightLuminance(atmosv_CelestialRadiance) * (1. - frx_rainGradient);

#if BLOCK_LIGHT_MODE != BLOCK_LIGHT_MODE_NEUTRAL
	float blWhite = light.z;
	blWhite = max(blWhite, sunAdaptation * 0.5);
	blColor = mix(blColor, BLOCK_LIGHT_NEUTRAL, blWhite);
#endif

	blockLight = blColor * BLOCK_LIGHT_STR * bl * (1.0 - 0.5 * sunAdaptation);

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

		hlLight = hdr_fromGamma(heldLight.rgb) * BLOCK_LIGHT_STR * hl;
	}
#endif

	skyLight = frx_worldHasSkylight * light.w * atmosv_CelestialRadiance * (1. - frx_rainGradient);
}

#if ALBEDO_BRIGHTENING == 0
#define hdrAlbedo(color) hdr_fromGamma(color.rgb)
#else
#define hdrAlbedo(color) hdr_fromGamma(color.rgb) * (1.0 - USER_ALBEDO_BRIGHTENING) + vec3(USER_ALBEDO_BRIGHTENING)
#endif

vec4 shading(vec4 color, sampler2D natureTexture, vec4 light, float ao, vec2 material, vec3 eyePos, vec3 normal, float vertexNormaly, bool isUnderwater, float disableDiffuse)
{
	vec3 albedo = hdrAlbedo(color);

	// unmanaged
	if (light.x == 0.0) return vec4(albedo, color.a);

	prepare(color, natureTexture, eyePos, vertexNormaly, isUnderwater, light);

	vec3 f0 = mix(vec3(0.01), albedo, material.y);
	vec3 toEye = -normalize(eyePos);

	vec3 baseLight, blockLight, hlLight, skyLight;

	lights(albedo, light, eyePos, toEye, baseLight, blockLight, hlLight, skyLight);

	// block light fresnel
	vec3 blH = normalize(toEye + normal);
	vec3 blF = pbr_fresnelSchlick(pbr_dot(toEye, blH), f0);
	// vanilla-ish style diffuse
	float dotUpNorth = l2_max3(abs(normal * vec3(0.6, 1.0, 0.8)));
	// perfect diffuse light
	vec3 shaded = albedo * (baseLight + blockLight * (1.0 - blF)) * dotUpNorth * max(1.0 - material.y, 0.5) / PI;
	// block light specular
	vec3 specular = pbr_specularBRDF(max(material.x, 0.5 * material.y), blockLight, blH, normal, toEye, normal, blF, 1.0);
	shaded += specular;

	lightPbr(albedo, color.a, hlLight, material.x, material.y, f0, toEye, toEye, normal, disableDiffuse);
	shaded += shading0.specular + shading0.diffuse;
	specular += shading0.specular;

	lightPbr(albedo, color.a, skyLight, material.x, material.y, f0, frx_skyLightVector, toEye, normal, disableDiffuse);
	shaded += shading0.specular + shading0.diffuse;
	specular += shading0.specular;

	ao = min(1.0, ao + light.z);

	shaded *= ao;
	specular *= ao;

	return vec4(shaded, min(1.0, color.a + frx_luminance(specular)));
}

vec4 particleShading(vec4 color, sampler2D natureTexture, vec4 light, vec3 eyePos, bool isUnderwater)
{
	vec3 albedo = hdrAlbedo(color);
	// unmanaged
	if (light.x == 0.0) return vec4(albedo, color.a);

	vec3 toEye = -normalize(eyePos);
	prepare(color, natureTexture, eyePos, toEye.y, isUnderwater, light);

	vec3 baseLight, blockLight, hlLight, skyLight;
	lights(albedo, light, eyePos, toEye, baseLight, blockLight, hlLight, skyLight);

	vec3 shaded = albedo * (baseLight + blockLight + hlLight);
	shaded += albedo * skyLight;

	return vec4(shaded / PI, color.a);
}

vec4 shading(vec4 color, sampler2D natureTexture, vec4 light, vec3 rawMat, vec3 eyePos, vec3 normal, float vertexNormaly, bool isUnderwater, float disableDiffuse) {
	return shading(color, natureTexture, light, rawMat.z, rawMat.xy, eyePos, normal, vertexNormaly, isUnderwater, disableDiffuse);
}
#endif
#endif
