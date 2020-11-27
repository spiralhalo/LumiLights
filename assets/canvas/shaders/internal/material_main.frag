/*
 *  Lumi Lights - A shader pack for Canvas
 *  Copyright (c) 2020 spiralhalo and Contributors
 *
 *  See `README.md` for license notice.
 */

#include canvas:shaders/internal/header.glsl
#include canvas:shaders/internal/varying.glsl
#include canvas:shaders/internal/diffuse.glsl
#include canvas:shaders/internal/flags.glsl
#include canvas:shaders/internal/fog.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/camera.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include canvas:shaders/internal/program.glsl
#include lumi:shaders/api/pbr_frag.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/api/context_bump.glsl

#define LUMI_PBR
#include canvas:apitarget

/******************************************************
  canvas:shaders/internal/material_main.frag
******************************************************/

varying vec3 pbrv_viewDir;

const float pbr_specularBloomStr = 0.01;
const float hdr_sunStr = 5;
const float hdr_moonStr = 0.4;
const float hdr_blockStr = 3;
const float hdr_handHeldStr = 1.5;
const float hdr_skylessStr = 0.2;
const float hdr_baseMinStr = 0.01;
const float hdr_baseMaxStr = 0.8;
const float hdr_emissiveStr = 1;
const float hdr_relAmbient = 0.2;
const float hdr_relSunHorizon = 0.5;
const float hdr_zWobbleDefault = 0.1;
const float hdr_finalMult = 1;
const float hdr_gamma = 2.2;

float hdr_gammaAdjust(float x){
	return pow(x, hdr_gamma);
}

vec3 hdr_gammaAdjust(vec3 x){
	return pow(x, vec3(hdr_gamma));
}

vec3 hdr_reinhardJodieTonemap(in vec3 v) {
    float l = frx_luminance(v);
    vec3 tv = v / (1.0f + v);
    return mix(v / (1.0f + l), tv, tv);
}

void _cv_startFragment(inout frx_FragmentData data) {
	int cv_programId = _cv_fragmentProgramId();
#include canvas:startfragment
}

float l2_clampScale(float e0, float e1, float v){
    return clamp((v-e0)/(e1-e0), 0.0, 1.0);
}

float l2_max3(vec3 vec){
	return max(vec.x, max(vec.y, vec.z));
}

// vec3 l2_what(vec3 rgb){
// 	return vec3(0.4123910 * rgb.r + 0.3575840 * rgb.g + 0.1804810 * rgb.b,
// 				0.2126390 * rgb.r + 0.7151690 * rgb.g + 0.0721923 * rgb.b,
// 				0.0193308 * rgb.r + 0.1191950 * rgb.g + 0.9505320 * rgb.b);
// }

vec3 l2_blockLight(float blockLight){
	float bl = l2_clampScale(0.03125, 1.0, blockLight);
	bl *= bl * hdr_blockStr;
	return hdr_gammaAdjust(vec3(bl, bl*0.875, bl*0.75));
}

vec3 pbr_handHeldRadiance(){
#if HANDHELD_LIGHT_RADIUS != 0
	vec4 held = frx_heldLight();
	float hl = l2_clampScale(held.w * HANDHELD_LIGHT_RADIUS, 0.0, gl_FogFragCoord);
	hl *= hl * hdr_handHeldStr;
	return hdr_gammaAdjust(held.rgb * hl);
#endif
}

vec3 l2_emissiveLight(float emissivity){
	return vec3(hdr_gammaAdjust(emissivity) * hdr_emissiveStr);
}

float l2_skyLight(float skyLight, float intensity)
{
	float sl = l2_clampScale(0.03125, 1.0, skyLight);
	return hdr_gammaAdjust(sl) * intensity;
}

vec3 l2_ambientColor(float time){
	vec3 ambientColor = hdr_gammaAdjust(vec3(0.6, 0.9, 1.0)) * hdr_sunStr * hdr_relAmbient;
	vec3 sunriseAmbient = hdr_gammaAdjust(vec3(1.0, 0.8, 0.4)) * hdr_sunStr * hdr_relAmbient * hdr_relSunHorizon;
	vec3 sunsetAmbient = hdr_gammaAdjust(vec3(1.0, 0.6, 0.2)) * hdr_sunStr * hdr_relAmbient * hdr_relSunHorizon;
	vec3 nightAmbient = hdr_gammaAdjust(vec3(1.0, 1.0, 2.0)) * hdr_moonStr * hdr_relAmbient;
	if(time > 0.94){
		ambientColor = mix(nightAmbient, sunriseAmbient, l2_clampScale(0.94, 0.98, time));
	} else if(time > 0.52){
		ambientColor = mix(sunsetAmbient, nightAmbient, l2_clampScale(0.52, 0.56, time));
	} else if(time > 0.48){
		ambientColor = mix(ambientColor, sunsetAmbient, l2_clampScale(0.48, 0.5, time));
	} else if(time < 0.02){
		ambientColor = mix(ambientColor, sunriseAmbient, l2_clampScale(0.02, 0, time));
	}
	return ambientColor;
}

vec3 l2_skyAmbient(float skyLight, float time, float intensity){
	float sa = l2_skyLight(skyLight, intensity) * 2.5;
	return sa * l2_ambientColor(time);
}

float l2_userBrightness(){
	float base = texture2D(frxs_lightmap, vec2(0.03125, 0.03125)).r;
	// if(frx_isWorldTheNether()){
	// 	return smoothstep(0.15/*0.207 no true darkness in nether*/, 0.577, base);
	// } else if (frx_isWorldTheEnd(){
	// 	return smoothstep(0.18/*0.271 no true darkness in the end*/, 0.685, base);
	// } else {
	// 	return smoothstep(0.053, 0.135, base);
	// }

	// Simplify nether/the end check
	if(frx_worldHasSkylight()){
		return smoothstep(0.053, 0.135, base);
	} else {
		return smoothstep(0.15, 0.63, base);
	}
}

vec3 l2_skylessLightColor(){
	return hdr_gammaAdjust(vec3(1.0));
}

vec3 l2_dimensionColor(){
	if (frx_isWorldTheNether()) {
		float min_col = min(min(gl_Fog.color.rgb.x, gl_Fog.color.rgb.y), gl_Fog.color.rgb.z);
		float max_col = max(max(gl_Fog.color.rgb.x, gl_Fog.color.rgb.y), gl_Fog.color.rgb.z);
		float sat = 0.0;
		if (max_col != 0.0) {
			sat = (max_col-min_col)/max_col;
		}
	
		return hdr_gammaAdjust(clamp((gl_Fog.color.rgb*(1/max_col))+pow(sat,2)/2, 0.0, 1.0));
	}
	else {
		return hdr_gammaAdjust(vec3(0.8, 0.7, 1.0));
	}
}

vec3 pbr_skylessDarkenedDir() {
	return vec3(0, -0.977358, 0.211593);
}

vec3 pbr_skylessDir() {
	return vec3(0, 0.977358, 0.211593);
}

vec3 pbr_skylessRadiance(){
	if (frx_worldHasSkylight()) {
		return vec3(0);
	} else {
		return ( frx_isSkyDarkened() ? 0.5 : 1.0 )
			* hdr_skylessStr
			* l2_skylessLightColor()
			* l2_userBrightness();
	}
}

vec3 pbr_lightCalc(vec3 albedo, vec3 f0, vec3 radiance, vec3 lightDir, vec3 viewDir, vec3 normal, bool diffuseOn, bool isAmbiance, inout vec3 specularAccu) {
	
	vec3 halfway = normalize(viewDir + lightDir);
	float roughness = pbr_roughness;

	if (isAmbiance) {
		roughness = min(1.0, roughness + 0.5 * (1 - pbr_metallic));
	}
	
	// cook-torrance brdf
	float distribution = pbr_distributionGGX(normal, halfway, roughness);
	float geometry = pbr_geometrySmith(normal, viewDir, lightDir, roughness);
	vec3 fresnel = pbr_fresnelSchlick(max(0.0, dot(viewDir, halfway)), f0);

	float NdotL = max(dot(normal, lightDir), 0.0);  
	vec3 num = distribution * geometry * fresnel;
	float denom = 4.0 * max(dot(normal, viewDir), 0.0) * NdotL;
	vec3 specular = num / max(denom, 0.001);

	vec3 diffuse = (1.0 - fresnel) * (1.0 - pbr_metallic);

	vec3 specularRadiance = specular * radiance * NdotL;
	vec3 diffuseRadiance = albedo * diffuse / PI * radiance * (diffuseOn ? NdotL : max(0.0, dot(lightDir, vec3(.0, 1.0, .0))));
	specularAccu += specularRadiance;

	return specularRadiance + diffuseRadiance;
}

vec3 l2_baseAmbient(){
	if(frx_worldHasSkylight()){
		return vec3(0.1) * mix(hdr_baseMinStr, hdr_baseMaxStr, l2_userBrightness());
	} else {
		return l2_dimensionColor() * mix(hdr_baseMinStr, hdr_baseMaxStr, l2_userBrightness());
	}
}

vec3 l2_sunColor(float time){
	vec3 sunColor = hdr_gammaAdjust(vec3(1.0, 1.0, 0.8)) * hdr_sunStr;
	vec3 sunriseColor = hdr_gammaAdjust(vec3(1.0, 0.8, 0.4)) * hdr_sunStr * hdr_relSunHorizon;
	vec3 sunsetColor = hdr_gammaAdjust(vec3(1.0, 0.6, 0.4)) * hdr_sunStr * hdr_relSunHorizon;
	if(time > 0.94){
		sunColor = sunriseColor;
	} else if(time > 0.56){
		sunColor = vec3(0); // pitch black at night
	} else if(time > 0.54){
		sunColor = mix(sunsetColor, vec3(0), l2_clampScale(0.54, 0.56, time));
	} else if(time > 0.5){
		sunColor = sunsetColor;
	} else if(time > 0.48){
		sunColor = mix(sunColor, sunsetColor, l2_clampScale(0.48, 0.5, time));
	} else if(time < 0.02){
		sunColor = mix(sunColor, sunriseColor, l2_clampScale(0.02, 0, time));
	}
	return sunColor;
}

vec3 pbr_vanillaSunDir(in float time, float zWobble){

	// wrap time to account for sunrise
	time -= (time >= 0.75) ? 1.0 : 0.0;

	// supposed offset of sunset/sunrise from 0/12000 daytime. might get better result with datamining?
	float sunHorizonDur = 0.04;

	// angle of sun in radians
	float angleRad = l2_clampScale(-sunHorizonDur, 0.5+sunHorizonDur, time) * PI;

	return normalize(vec3(cos(angleRad), sin(angleRad), zWobble));
}

vec3 pbr_sunRadiance(float skyLight, in float time, float intensity, float rainGradient){

	// wrap time to account for sunrise
	float customTime = (time >= 0.75) ? (time - 1.0) : time;

    float customIntensity = l2_clampScale(-0.08, 0.00, customTime);

    if(customTime >= 0.25){
		customIntensity = l2_clampScale(0.58, 0.5, customTime);
    }

	customIntensity *= mix(1.0, 0.0, rainGradient);

	float sl = l2_skyLight(skyLight, max(customIntensity, intensity));

	// direct sun light doesn't reach into dark spot as much as sky ambient
	sl = frx_smootherstep(0.5,1.0,sl);

	return sl * l2_sunColor(time);
}

vec3 pbr_moonDir(float time){
    float aRad = l2_clampScale(0.56, 0.94, time) * PI;
	return normalize(vec3(cos(aRad), sin(aRad), 0));
}

vec3 pbr_moonRadiance(float skyLight, float time, float intensity){
	float ml = l2_skyLight(skyLight, intensity) * frx_moonSize() * hdr_moonStr;
	if(time < 0.58){
		ml *= l2_clampScale(0.54, 0.58, time);
	} else if(time > 0.92){
		ml *= l2_clampScale(0.96, 0.92, time);
	}
	return vec3(ml);
}

float l2_ao(frx_FragmentData fragData) {
#if AO_SHADING_MODE != AO_MODE_NONE
	float ao = fragData.ao ? _cvv_ao : 1.0;
	return hdr_gammaAdjust(min(1.0, ao + fragData.emissivity));
#else
	return 1.0;
#endif 
}

void main() {
	frx_FragmentData fragData = frx_FragmentData (
	texture2D(frxs_spriteAltas, _cvv_texcoord, _cv_getFlag(_CV_FLAG_UNMIPPED) * -4.0),
	_cvv_color,
	frx_matEmissive() ? 1.0 : 0.0,
	!frx_matDisableDiffuse(),
	!frx_matDisableAo(),
	_cvv_normal,
	_cvv_lightcoord
	);

	pbr_roughness = 1.0;
	pbr_metallic = 0.0;

	_cv_startFragment(fragData);

	vec4 a = fragData.spriteColor * fragData.vertexColor;
	float bloom = fragData.emissivity; // separate bloom from emissivity

	if(frx_isGui()){
#if DIFFUSE_SHADING_MODE != DIFFUSE_MODE_NONE
		if(fragData.diffuse){
			float diffuse = mix(_cvv_diffuse, 1, fragData.emissivity);
			vec3 shading = mix(vec3(0.5, 0.4, 0.8) * diffuse * diffuse, vec3(1.0), diffuse);
			a.rgb *= shading;
		}
#endif
	} else {
		a.rgb = hdr_gammaAdjust(a.rgb);
		vec3 albedo = a.rgb;
		vec3 f0 = mix(vec3(0.04), albedo, pbr_metallic);

		float ao = l2_ao(fragData);
		vec3 emissive = l2_emissiveLight(fragData.emissivity);
		a.rgb *= emissive;
		
		vec3 viewDir = pbrv_viewDir;

		vec3 normal = fragData.vertexNormal * frx_normalModelMatrix();

		vec3 specularAccu = vec3(0.0);

	#if HANDHELD_LIGHT_RADIUS != 0
		vec3 handHeldRadiance = pbr_handHeldRadiance();
		if(handHeldRadiance.x + handHeldRadiance.y + handHeldRadiance.z > 0) {
			vec3 handHeldDir = viewDir;
			a.rgb += pbr_lightCalc(albedo, f0, handHeldRadiance, handHeldDir, viewDir, normal, fragData.diffuse, false, specularAccu);
		}
	#endif

		vec3 blockRadiance = l2_blockLight(fragData.light.x);
		vec3 baseAmbientRadiance = l2_baseAmbient();
		vec3 ambientDir = normalize(vec3(0.1, 0.9, 0.1) + normal);

		a.rgb += pbr_lightCalc(albedo, f0, blockRadiance * ao, ambientDir, viewDir, normal, fragData.diffuse, false, specularAccu);
		a.rgb += pbr_lightCalc(albedo, f0, baseAmbientRadiance * ao, ambientDir, viewDir, normal, fragData.diffuse, true, specularAccu);

		if (frx_worldHasSkylight()) {
			if (fragData.light.y > 0.03125) {

				vec3 moonRadiance = pbr_moonRadiance(fragData.light.y, frx_worldTime(), frx_ambientIntensity());
				vec3 moonDir = pbr_moonDir(frx_worldTime());
				vec3 sunRadiance = pbr_sunRadiance(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), frx_rainGradient());
				vec3 sunDir = pbr_vanillaSunDir(frx_worldTime(), 0.0);
				vec3 skyRadiance = l2_skyAmbient(fragData.light.y, frx_worldTime(), frx_ambientIntensity());

				a.rgb += pbr_lightCalc(albedo, f0, moonRadiance * ao, moonDir, viewDir, normal, fragData.diffuse, false, specularAccu);
				a.rgb += pbr_lightCalc(albedo, f0, sunRadiance * ao, sunDir, viewDir, normal, fragData.diffuse, false, specularAccu);
				a.rgb += pbr_lightCalc(albedo, f0, skyRadiance * ao, ambientDir, viewDir, normal, fragData.diffuse, true, specularAccu);

			}

		} else {

			vec3 skylessRadiance = pbr_skylessRadiance();
			vec3 skylessDir = pbr_skylessDir();

			a.rgb += pbr_lightCalc(albedo, f0, skylessRadiance * ao, skylessDir, viewDir, normal, fragData.diffuse, false, specularAccu);

			if (frx_isSkyDarkened()) {

				vec3 skylessDarkenedDir = pbr_skylessDarkenedDir();
				a.rgb += pbr_lightCalc(albedo, f0, skylessRadiance * ao, skylessDarkenedDir, viewDir, normal, fragData.diffuse, false, specularAccu);
			}

		}

		// float skyAccess = smoothstep(0.89, 1.0, fragData.light.y);

		float specularLuminance = frx_luminance(specularAccu);
		float smoothness = (1-pbr_roughness);
		// a.a += specularLuminance;
		bloom += specularLuminance * pbr_specularBloomStr * smoothness * smoothness;

		a.rgb *= hdr_finalMult;
		a.rgb = pow(hdr_reinhardJodieTonemap(a.rgb), vec3(1.0 / hdr_gamma));
		// a.rgb = viewDir * 0.5 + 0.5;
	}

	// PERF: varyings better here?
	if (_cv_getFlag(_CV_FLAG_CUTOUT) == 1.0) {
		float t = _cv_getFlag(_CV_FLAG_TRANSLUCENT_CUTOUT) == 1.0 ? _CV_TRANSLUCENT_CUTOUT_THRESHOLD : 0.5;

		if (a.a < t) {
			discard;
		}
	}

	// PERF: varyings better here?
	if (_cv_getFlag(_CV_FLAG_FLASH_OVERLAY) == 1.0) {
		a = a * 0.25 + 0.75;
	} else if (_cv_getFlag(_CV_FLAG_HURT_OVERLAY) == 1.0) {
		a = vec4(0.25 + a.r * 0.75, a.g * 0.75, a.b * 0.75, a.a);
	}

	// TODO: need a separate fog pass?
	gl_FragData[TARGET_BASECOLOR] = _cv_fog(a);
	gl_FragDepth = gl_FragCoord.z;

#if TARGET_EMISSIVE > 0
	gl_FragData[TARGET_EMISSIVE] = vec4(bloom * a.a, 1.0, 0.0, 1.0);
#endif
}
