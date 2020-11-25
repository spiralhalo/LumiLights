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
#include frex:shaders/api/player.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include canvas:shaders/internal/program.glsl
#include lumi:shaders/api/varying.glsl

#include canvas:apitarget

/******************************************************
  canvas:shaders/internal/material_main.frag
******************************************************/

#define M_PI 3.1415926535897932384626433832795

const float hdr_sunStr = 3;
const float hdr_moonStr = 0.4;
const float hdr_blockStr = 1.5;
const float hdr_skylessStr = 0.2;
const float hdr_baseMinStr = 0.0;
const float hdr_baseMaxStr = 0.25;
const float hdr_emissiveStr = 1;
const float hdr_relAmbient = 0.09;
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
	vec3 block = hdr_gammaAdjust(vec3(bl, bl*0.875, bl*0.75));
	
#if HANDHELD_LIGHT_RADIUS != 0
	vec4 held = frx_heldLight();
	if (held.w > 0.0) {
		float hl = l2_clampScale(held.w * HANDHELD_LIGHT_RADIUS, 0.0, gl_FogFragCoord);
		hl *= hl * hdr_blockStr;

		return block + hdr_gammaAdjust(held.rgb * hl);
	}
#endif

	return block;
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

vec3 l2_skylessLight(vec3 normal){
	if(frx_worldHasSkylight()){
		return vec3(0);
	} else {
		float yalign = dot(normal,vec3(0, 0.977358, 0.211593)); // a bit towards z for more interesting effect
		yalign = frx_isSkyDarkened()?abs(yalign):max(0,yalign);
		return yalign * hdr_skylessStr * l2_skylessLightColor() * l2_userBrightness();
	}
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

vec3 l2_vanillaSunDir(in float time, float zWobble){

	// wrap time to account for sunrise
	time -= (time >= 0.75) ? 1.0 : 0.0;

	// supposed offset of sunset/sunrise from 0/12000 daytime. might get better result with datamining?
	float sunHorizonDur = 0.04;

	// angle of sun in radians
	float angleRad = l2_clampScale(-sunHorizonDur, 0.5+sunHorizonDur, time) * M_PI;

	return normalize(vec3(cos(angleRad), sin(angleRad), zWobble));
}

vec3 l2_sunLight(float skyLight, in float time, float intensity, float rainGradient, vec3 diffuseNormal){

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

	// zWobble is added to make more interesting looking diffuse light
	// TODO: might be fun to use frx_worldDay() with sine wave for the zWobble to simulate annual sun position change
	sl *= max(0.0, dot(l2_vanillaSunDir(time, hdr_zWobbleDefault), diffuseNormal));
	return sl * l2_sunColor(time);
}

vec3 l2_moonLight(float skyLight, float time, float intensity, vec3 diffuseNormal){
	float ml = l2_skyLight(skyLight, intensity) * frx_moonSize() * hdr_moonStr;
    float aRad = l2_clampScale(0.56, 0.94, time) * M_PI;
	ml *= max(0.0, dot(vec3(cos(aRad), sin(aRad), 0), diffuseNormal));
	if(time < 0.58){
		ml *= l2_clampScale(0.54, 0.58, time);
	} else if(time > 0.92){
		ml *= l2_clampScale(0.96, 0.92, time);
	}
	return vec3(ml);
}

float l2_specular(float time, vec3 aNormal, vec3 aPos, vec3 cameraPos, float power)
{
    // calculate sun position (0 zWobble to make it look accurate with vanilla sun visuals)
    vec3 sunDir = l2_vanillaSunDir(time, 0);

    // obtain the direction of the camera
    vec3 viewDir = normalize(cameraPos - aPos);

    // calculate the specular light
    return pow(max(0.0, dot(reflect(-sunDir, aNormal), viewDir)),power);
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

	_cv_startFragment(fragData);

	vec4 a = fragData.spriteColor * fragData.vertexColor;

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

		// If diffuse is disabled (e.g. grass) then the normal points up by default
		float ao = l2_ao(fragData);
		vec3 diffuseNormal = fragData.diffuse?fragData.vertexNormal * frx_normalModelMatrix():vec3(0,1,0);
		vec3 block = l2_blockLight(fragData.light.x);
		vec3 sun = l2_sunLight(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), frx_rainGradient(), diffuseNormal);
		vec3 moon = l2_moonLight(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), diffuseNormal);
		vec3 skyAmbient = l2_skyAmbient(fragData.light.y, frx_worldTime(), frx_ambientIntensity());
		vec3 emissive = l2_emissiveLight(fragData.emissivity);
		vec3 nether = l2_skylessLight(diffuseNormal);

		vec3 light = block + moon + l2_baseAmbient() + skyAmbient + sun + nether;
		light *= ao; // AO is supposed to be applied to ambient only, but things look better with AO on everything except for emissive light
		light += emissive;
		
		vec3 specular = vec3(0.0);
		float specularAmount = 0;
		if (wwv_specPower > 0.01) {
			vec3 specularNormal = fragData.vertexNormal * frx_normalModelMatrix();

			float skyLight = l2_skyLight(fragData.light.y, frx_ambientIntensity());
			float skyAccess = smoothstep(0.89, 1.0, fragData.light.y);

			vec3 fragPos = frx_var0.xyz;
			vec3 cameraPos = frx_var1.xyz;

			specularAmount = l2_specular(frx_worldTime(), specularNormal, fragPos, cameraPos, wwv_specPower);
			specularAmount *= skyAccess * skyLight;

			specular = l2_sunColor(frx_worldTime()) * specularAmount;
		}

		a.rgb *= light;
		a.rgb += specular;
		a.a += specularAmount;

		a.rgb *= hdr_finalMult;
		a.rgb = pow(hdr_reinhardJodieTonemap(a.rgb), vec3(1.0 / hdr_gamma));
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
	gl_FragData[TARGET_EMISSIVE] = vec4(fragData.emissivity, 1.0, 0.0, 1.0);
#endif
}
