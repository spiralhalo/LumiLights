/*******************************************************
 *  lumi:shaders/internal/lightsource.glsl             *
 *******************************************************
 *  Copyright (c) 2020 spiralhalo and Contributors.    *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#if LUMI_Tonemap == LUMI_Tonemap_Film
	#define toneAdjust(x) (x*1)
#else
	#define toneAdjust(x) x
#endif

#ifdef LUMI_PBRX
const float hdr_sunStr = 5;
const float hdr_moonStr = 0.4;
const float hdr_blockMinStr = 2;
const float hdr_blockMaxStr = 3;
const float hdr_handHeldStr = 1.5;
const float hdr_skylessStr = 0.1;
const float hdr_baseMinStr = 0.01;
const float hdr_baseMaxStr = 0.8;
const float hdr_emissiveStr = 1;
const float hdr_relAmbient = toneAdjust(0.2);
const float hdr_dramaticStr = 1.0;
const float hdr_dramaticMagicNumber = 6.0;
#else
const float hdr_sunStr = 1.8;
const float hdr_moonStr = 0.18;
const float hdr_blockMinStr = 1.0;
const float hdr_blockMaxStr = 1.4;
const float hdr_handHeldStr = 0.9;
const float hdr_skylessStr = 0.05;
const float hdr_baseMinStr = 0.0;
const float hdr_baseMaxStr = 0.25;
const float hdr_emissiveStr = 1;
const float hdr_relAmbient = toneAdjust(0.09);
const float hdr_dramaticStr = 0.6;
const float hdr_dramaticMagicNumber = 3.5;
#endif
const float hdr_skylessRelStr = 0.5;
const float hdr_nightAmbientMult = 2.0;
const float hdr_zWobbleDefault = 0.1;

const vec3 blockColor = vec3(1.0, 0.875, 0.75);
const vec3 dramaticBlockColor = vec3(1.0, 0.7, 0.4);

#if LUMI_LightingMode == LUMI_LightingMode_Dramatic
const vec3 preSunColor = vec3(1.0, 1.0, 1.0);
#else
#if LUMI_Tonemap == LUMI_Tonemap_Vibrant
const vec3 preSunColor = vec3(1.0, 1.0, 1.0);
#else
const vec3 preSunColor = vec3(1.0, 1.0, 0.8);
#endif
#endif
const vec3 preSunriseColor = vec3(1.0, 0.8, 0.4);
const vec3 preSunsetColor = vec3(1.0, 0.6, 0.4);

const vec3 nvColor = vec3(0.63, 0.55, 0.64);
// const vec3 nvColorPurple = vec3(0.6, 0.5, 0.7);

const vec3 preMiddayAmbient = vec3(0.8550322);
const vec3 preDayAmbient = vec3(0.6, 0.9, 1.0);
#if LUMI_LightingMode == LUMI_LightingMode_Dramatic
// const vec3 preSunriseAmbient = vec3(0.5, 0.3, 0.1);
// const vec3 preSunsetAmbient = vec3(0.5, 0.2, 0.0);
const vec3 preNightAmbient = vec3(0.74, 0.4, 1.0);
#else
// const vec3 preSunriseAmbient = vec3(1.0, 0.8, 0.4);
// const vec3 preSunsetAmbient = vec3(1.0, 0.6, 0.2);
const vec3 preNightAmbient = vec3(0.5, 0.5, 1.0);
#endif

/*  BLOCK LIGHT
 *******************************************************/

vec3 l2_blockRadiance(float blockLight, float userBrightness) {
#if LUMI_LightingMode == LUMI_LightingMode_Dramatic
	float dist = (1.001 - min(l2_clampScale(0.03125, 0.95, blockLight), 0.93)) * 15;
	float bl = hdr_dramaticMagicNumber / (dist * dist);
	if (bl <= 0.01 * hdr_dramaticMagicNumber) {
		bl *= l2_clampScale(0.0045 * hdr_dramaticMagicNumber, 0.01 * hdr_dramaticMagicNumber, bl);
	}
	return bl * hdr_gammaAdjust(dramaticBlockColor) * mix(hdr_blockMinStr, hdr_blockMaxStr, userBrightness);
#else
	float bl = l2_clampScale(0.03125, 1.0, blockLight);
	bl *= bl * mix(hdr_blockMinStr, hdr_blockMaxStr, userBrightness);
	return hdr_gammaAdjust(bl * blockColor);
#endif
}

/*  HELD LIGHT
 *******************************************************/

#if HANDHELD_LIGHT_RADIUS != 0
vec3 l2_handHeldRadiance() {
#if LUMI_LightingMode == LUMI_LightingMode_Dramatic
	vec4 held = frx_heldLight();
	float dist = (1.001 - l2_clampScale(held.w * HANDHELD_LIGHT_RADIUS, 0.0, gl_FogFragCoord)) * 15;
	float hl = hdr_dramaticMagicNumber / (dist * dist);
	if (hl <= 0.01 * hdr_dramaticMagicNumber) {
		hl *= l2_clampScale(0.0045 * hdr_dramaticMagicNumber, 0.01 * hdr_dramaticMagicNumber, hl);
	}
	vec3 heldColor = held.rgb;
	if (heldColor == blockColor) {
		heldColor = dramaticBlockColor;
	}
	return hl * hdr_gammaAdjust(heldColor) * hdr_handHeldStr;
#else
	vec4 held = frx_heldLight();
	float hl = l2_clampScale(held.w * HANDHELD_LIGHT_RADIUS, 0.0, gl_FogFragCoord);
	hl *= hl * hdr_handHeldStr;
	return hdr_gammaAdjust(held.rgb * hl);
#endif
}
#endif

/*  EMISSIVE LIGHT
 *******************************************************/

vec3 l2_emissiveRadiance(float emissivity) {
	return vec3(hdr_gammaAdjust(emissivity) * hdr_emissiveStr);
}

/*  SKY AMBIENT LIGHT
 *******************************************************/

float l2_skyLight(float skyLight, float intensity) {
	float sl = l2_clampScale(0.03125, 1.0, skyLight);
	return hdr_gammaAdjust(sl) * intensity;
}

vec3 l2_ambientColor(float time) {
	vec3 ambientColor;
	if (time > 0.94) {
		#ifdef LUMI_TrueDarkness_DisableMoonlight
		ambientColor = mix(hdr_gammaAdjust(0.0), hdr_gammaAdjust(preDayAmbient) * hdr_sunStr, l2_clampScale(0.94, 0.98, time));
		#else
		ambientColor = mix(hdr_gammaAdjust(preNightAmbient) * hdr_moonStr * hdr_nightAmbientMult, hdr_gammaAdjust(preDayAmbient) * hdr_sunStr, l2_clampScale(0.94, 0.98, time));
		#endif
	} else if(time > 0.52 ){
		#ifdef LUMI_TrueDarkness_DisableMoonlight
		ambientColor = mix(hdr_gammaAdjust(preDayAmbient) * hdr_sunStr, vec3(0.0), l2_clampScale(0.52, 0.56, time));
		#else
		ambientColor = mix(hdr_gammaAdjust(preDayAmbient) * hdr_sunStr, hdr_gammaAdjust(preNightAmbient) * hdr_moonStr * hdr_nightAmbientMult, l2_clampScale(0.52, 0.56, time));
		#endif
	} else if(time > 0.25) {
		ambientColor = mix(hdr_gammaAdjust(preMiddayAmbient) * hdr_sunStr, hdr_gammaAdjust(preDayAmbient) * hdr_sunStr, l2_clampScale(0.25, 0.375, time));
	} else if(time >= 0.02) {
		ambientColor = mix(hdr_gammaAdjust(preMiddayAmbient) * hdr_sunStr, hdr_gammaAdjust(preDayAmbient) * hdr_sunStr, l2_clampScale(0.25, 0.125, time));
	} else {
		ambientColor = hdr_gammaAdjust(preDayAmbient) * hdr_sunStr;
	}
	return ambientColor * hdr_relAmbient;
}

vec3 l2_skyAmbient(float skyLight, float time, float intensity) {
	float sl = l2_skyLight(skyLight, intensity);
#if LUMI_LightingMode == LUMI_LightingMode_Dramatic
	sl = smoothstep(0.1, 0.9, sl);
#endif
	float sa = sl * 2.5;
	return sa * l2_ambientColor(time);
}

/*  SKYLESS LIGHT
 *******************************************************/

vec3 l2_skylessLightColor() {
	return hdr_gammaAdjust(vec3(1.0));
}

vec3 l2_dimensionColor() {
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

vec3 l2_skylessDarkenedDir() {
	return vec3(0, -0.977358, 0.211593);
}

vec3 l2_skylessDir() {
	return vec3(0, 0.977358, 0.211593);
}

vec3 l2_skylessRadiance(float userBrightness) {
	#ifdef LUMI_TrueDarkness_NetherTrueDarkness
	if (frx_isSkyDarkened()) {
		return vec3(0.0);
	}
	#endif
	#ifdef LUMI_TrueDarkness_TheEndTrueDarkness
	if (!frx_isSkyDarkened()) {
		return vec3(0.0);
	}
	#endif
	if (frx_worldHasSkylight()) {
		return vec3(0);
	} else {
		return ( frx_isSkyDarkened() ? 0.5 : 1.0 )
			* hdr_skylessStr
			* l2_skylessLightColor()
			* userBrightness;
	}
}

/*  BASE AMBIENT LIGHT
 *******************************************************/

vec3 l2_baseAmbient(float userBrightness){
	if (frx_playerHasNightVision()) {
		//userBrightness is maxed out by night vision so it's useless here
		return hdr_gammaAdjust(nvColor) * hdr_blockMaxStr;
	} else {
		if (frx_worldHasSkylight()) {
			#ifdef LUMI_TrueDarkness_DisableOverworldAmbient
			return vec3(0.0);
			#else
			return vec3(0.1) * mix(hdr_baseMinStr, hdr_baseMaxStr, userBrightness);
			#endif
		} else {
			#ifdef LUMI_TrueDarkness_NetherTrueDarkness
			if(frx_isSkyDarkened()){
				return vec3(0.0);
			}
			#endif
			#ifdef LUMI_TrueDarkness_TheEndTrueDarkness
			if(!frx_isSkyDarkened()){
				return vec3(0.0);
			}
			#endif
			return l2_dimensionColor() * hdr_skylessRelStr * mix(hdr_baseMinStr, hdr_baseMaxStr, userBrightness);
		}
	}
}

/*  SUN LIGHT
 *******************************************************/

vec3 l2_sunColor(float time){
	vec3 sunColor;
	if(time > 0.94){
		sunColor = mix(hdr_gammaAdjust(preSunriseColor), vec3(0), l2_clampScale(0.96, 0.94, time));
	} else if(time > 0.5){
		sunColor = mix(hdr_gammaAdjust(preSunsetColor), vec3(0), l2_clampScale(0.54, 0.56, time));
	} else if(time > 0.48){
		sunColor = mix(hdr_gammaAdjust(preSunColor), hdr_gammaAdjust(preSunsetColor), l2_clampScale(0.48, 0.5, time));
	} else if(time < 0.02){
		sunColor = mix(hdr_gammaAdjust(preSunColor), hdr_gammaAdjust(preSunriseColor), l2_clampScale(0.02, 0, time));
	} else {
		sunColor = hdr_gammaAdjust(preSunColor);
	}
	return sunColor * hdr_sunStr;
}

float l2_sunHorizonScale(float time){
	if(time > 0.94){
		return frx_smootherstep(0.94, 0.96, time);
	} else if(time > 0.5){
		return frx_smootherstep(0.56, 0.54, time);
	} else if(time > 0.48){
		return frx_smootherstep(0.48, 0.5, time);
	} else if(time < 0.02){
		return frx_smootherstep(0.02, 0, time);
	} else {
		return 0.0;
	}
}

vec3 l2_vanillaSunDir(in float time, float zWobble){

	// wrap time to account for sunrise
	time -= (time >= 0.75) ? 1.0 : 0.0;

	// supposed offset of sunset/sunrise from 0/12000 daytime. might get better result with datamining?
	float sunHorizonDur = 0.04;

	// angle of sun in radians
	float angleRad = l2_clampScale(-sunHorizonDur, 0.5+sunHorizonDur, time) * PI;

	return normalize(vec3(cos(angleRad), sin(angleRad), zWobble));
}

vec3 l2_sunRadiance(float skyLight, in float time, float intensity, float rainGradient){

	// wrap time to account for sunrise
	float customTime = (time >= 0.75) ? (time - 1.0) : time;

    float customIntensity = (customTime >= 0.25) ? l2_clampScale(0.56, 0.52, customTime) : l2_clampScale(-0.06, -0.02, customTime);

	customIntensity *= mix(1.0, 0.0, rainGradient);

	float sl = l2_skyLight(skyLight, max(customIntensity, intensity));

	// direct sun light doesn't reach into dark spot as much as sky ambient
#if LUMI_LightingMode == LUMI_LightingMode_Dramatic
	sl = frx_smootherstep(0.7, 0.97, sl);
#else
	sl = frx_smootherstep(0.5, 0.97, sl);
#endif

#if LUMI_LightingMode == LUMI_LightingMode_SystemUnused
	return sl * l2_sunColor(time) * (0.5 - 0.5 * dot(frx_cameraView(), vec3(0.0, 1.0, 0.0)));
#else
	return sl * l2_sunColor(time);
#endif
}

/*  MOON LIGHT
 *******************************************************/

vec3 l2_moonDir(float time){
    float aRad = l2_clampScale(0.56, 0.94, time) * PI;
	return normalize(vec3(cos(aRad), sin(aRad), 0));
}

vec3 l2_moonRadiance(float skyLight, float time, float intensity){
	#ifdef LUMI_TrueDarkness_DisableMoonlight
	return vec3(0.0);
	#else
	float ml = l2_skyLight(skyLight, intensity) * frx_moonSize() * hdr_moonStr;
	if(time < 0.58){
		ml *= l2_clampScale(0.54, 0.58, time);
	} else if(time > 0.92){
		ml *= l2_clampScale(0.96, 0.92, time);
	}
	return vec3(ml);
	#endif
}
