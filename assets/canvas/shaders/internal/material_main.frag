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
#include frex:shaders/lib/noise/noise3d.glsl
#include canvas:shaders/internal/program.glsl

#include canvas:apitarget

/******************************************************
  canvas:shaders/internal/material_main.frag
******************************************************/

#define M_2PI 6.283185307179586476925286766559
#define M_PI 3.1415926535897932384626433832795

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
	bl *= bl * 0.85;
	return vec3(bl, bl*0.875, bl*0.75);
}

vec3 l2_ambientColor(float time){
	vec3 ambientColor = vec3(0.6, 0.9, 1);
	vec3 sunriseAmbient = vec3(1.0, 0.8, 0.4);
	vec3 sunsetAmbient = vec3(1.0, 0.6, 0.2);
	vec3 nightAmbient = vec3(0.2, 0.2, 0.6);
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
	float sa = l2_clampScale(0.03125, 1.0, skyLight) * intensity * 2;
	return sa * l2_ambientColor(time);
}

vec3 l2_baseAmbient(){
	return vec3(l2_max3(texture2D(frxs_lightmap, vec2(0.03125, 0.03125)).rgb) );
}

vec3 l2_sunColor(float time){
	vec3 sunColor = vec3(1.0);
	vec3 sunriseColor = vec3(1.0, 0.8, 0.4);
	vec3 sunsetColor = vec3(1.0, 0.6, 0.4);
	if(time > 0.94){
		sunColor = sunriseColor;
	} else if(time > 0.5){
		sunColor = sunsetColor;
	} else if(time > 0.48){
		sunColor = mix(sunColor, sunsetColor, l2_clampScale(0.48, 0.5, time));
	} else if(time < 0.02){
		sunColor = mix(sunColor, sunriseColor, l2_clampScale(0.02, 0, time));
	}
	return sunColor;
}

vec3 l2_vanillaSunDir(float time, float zWobble){

	// wrap time to account  for sunrise
	time -= time >= 0.75?1:0;

	// supposed offset of sunset/sunrise from 0/12000 daytime. might get better result with datamining?
	float sunHorizonDur = 0.04;

	// angle of sun in radians
	float angleRad = l2_clampScale(-sunHorizonDur, 0.5+sunHorizonDur, time) * M_PI;

	return normalize(vec3(cos(angleRad), sin(angleRad), zWobble));
}

vec3 l2_sunLight(float skyLight, float time, float intensity, vec3 normalForLightCalc){
	float sl = l2_clampScale(0.03125, 1.0, skyLight) * intensity * 2;

	// zWobble is added to make more interesting looking diffuse light
	// TODO: might be fun to use frx_worldDay() with sine wave for the zWobble to simulate annual sun position change
	sl *= max(0.0, dot(l2_vanillaSunDir(time, 0.5), normalForLightCalc));

	if(time > 0.94){
		sl *= l2_clampScale(0.94, 1.0, time);
	} else if(time > 0.56){
		sl *= l2_clampScale(0.56, 0.5, time);
	}
	return sl * l2_sunColor(time);
}

vec3 l2_moonLight(float skyLight, float time, float intensity, vec3 normalForLightCalc){
	float ml = l2_clampScale(0.03125, 1.0, skyLight) * intensity * frx_moonSize()*0.8;
    float aRad = (time - 0.5) * M_2PI;
	ml *= max(0.0, dot(vec3(cos(aRad), sin(aRad), 0), normalForLightCalc));
	if(time < 0.56){
		ml *= l2_clampScale(0.5, 0.56, time);
	} else if(time > 0.94){
		ml *= l2_clampScale(1.0, 0.94, time);
	}
	return vec3(ml);
}

float l2_noise(vec3 aPos, float renderTime, float scale, float amplitude)
{
	float invScale = 1/scale;
    return (snoise(vec3(aPos.x*invScale, aPos.z*invScale, renderTime)) * 0.5+0.5) * amplitude;
}

float l2_specular(float time, vec3 aNormal, vec3 aPos, vec3 cameraPos, float luminance)
{
    // calculate sun position (0 zWobble to make it look accurate with vanilla sun visuals)
    vec3 sunDir = l2_vanillaSunDir(time, 0);

    // obtain the direction of the camera
    vec3 viewDir = normalize(cameraPos - aPos);

    // this code is adapted from GlossyGoodness
	// TODO: simplify?
    float power = pow(luminance,1.5) * 20;

    // calculate the specular light
    return pow(max(0.0, dot(reflect(-sunDir, aNormal), viewDir)),power);
}

// prefix ww to separate water effects from the rest of the shader

varying vec3 wwv_aPos;
varying vec3 wwv_cameraPos;

bool ww_waterTest(in frx_FragmentData fragData) {

	// check that vertex color is more blueish than other colors
	// vertex color is otherwise used by grass and leaves, so false positive should be minimum
	bool vertexBlue = fragData.vertexColor.b > fragData.vertexColor.g * 0.8 && fragData.vertexColor.b > fragData.vertexColor.r;

	// check for transparency similar to water
	// TODO: find out exact water texture transparency unless different resource pack can have different transparency
	bool waterTransparent = fragData.spriteColor.a < 0.9;

	// rule out particles and grass which may have non-white vertex color but usually have diffuse disabled
	bool diffuse = fragData.diffuse;
	
	return vertexBlue && waterTransparent && diffuse;
}

void ww_waterPipeline(inout vec4 a, in frx_FragmentData fragData) {
	// make default water texture shinier. purely optional
	a.rgb *= fragData.spriteColor.rgb;

	// adjust base alpha
	a.a = 0.6;

	vec3 surfaceNormal = fragData.vertexNormal*frx_normalModelMatrix();

	// apply simplex noise to the normal to create fake wavyness
	// check for up-facing water only. this *might* cause artifacts
	// TODO: make smoother check to remove artifacts. possibly by noiseAmp *= smoothstep(0.9, 0.95, surfaceNormal.y)
	if(abs(surfaceNormal.y) > 0.9) {
		// water wavyness parameter
		float timeScale = 2; 		// speed
		float noiseScale = 4; 		// wavelength
		float noiseAmp = 0.03125 * noiseScale;// * timeScale; // amplitude

		// inferred parameter
		float renderTime = frx_renderSeconds() * 0.5 * timeScale;
		float microSample = 0.01 * noiseScale;

		// base noise
		float noise = l2_noise(wwv_aPos, renderTime, noiseScale, noiseAmp);

		// normal recalculation
		vec3 noiseOrigin = vec3(0, noise, 0);
		vec3 noiseTangent = vec3(microSample, l2_noise(wwv_aPos + vec3(microSample,0,0), renderTime, noiseScale, noiseAmp), 0) - noiseOrigin;
		vec3 noiseBitangent = vec3(0, l2_noise(wwv_aPos + vec3(0,0,microSample), renderTime, noiseScale, noiseAmp), microSample) - noiseOrigin;

		// noisy normal
		surfaceNormal = normalize(cross(noiseBitangent, noiseTangent));
		// a.rgb = surfaceNormal;
	}

	float sunLight = l2_clampScale(0.03125, 1.0, fragData.light.y) * frx_ambientIntensity();

	// mix with ambient color before adding specular light
	a.rgb = mix (a.rgb, a.rgb*l2_ambientColor(frx_worldTime()), sunLight);

	// add specular light
	float specular = l2_specular(frx_worldTime(), surfaceNormal, wwv_aPos, wwv_cameraPos, 0.4); // magic number 0.4 (specular factor)
	a.rgb += l2_sunColor(frx_worldTime()) * sunLight * specular;

	// extra shiny
	a.a += pow(specular,20) * 0.5  * sunLight;

	// apply brightness factor
	a.rgb *= min(1,l2_baseAmbient().x+max(fragData.light.x,sunLight));
}

vec3 hdr_reinhardTonemap(in vec3 hdrColor){
	return hdrColor / (hdrColor + vec3(1.0));
}

#if AO_SHADING_MODE != AO_MODE_NONE
vec4 ao(float light){
	float ao = min(1,_cvv_ao+light*0.25);
	return vec4(ao, ao, ao, 1.0);
}
#endif

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

    const float gamma = 2.2;
	a.rgb = pow(a.rgb, vec3(gamma));

	if(ww_waterTest(fragData)){
		ww_waterPipeline(a, fragData);
	} else {
		// If diffuse is disabled (e.g. grass) then the normal points up by default
		vec3 normalForLightCalc = fragData.diffuse?fragData.vertexNormal*frx_normalModelMatrix():vec3(0,1,0);
		vec3 block = l2_blockLight(fragData.light.x);
		vec3 sun = l2_sunLight(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), normalForLightCalc);
		vec3 moon = l2_moonLight(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), normalForLightCalc);
		vec3 skyAmbient = l2_skyAmbient(fragData.light.y, frx_worldTime(), frx_ambientIntensity());

		vec3 light = block+moon+l2_baseAmbient()+skyAmbient+sun;

		a *= vec4(light, 1.0);
	}

	a.rgb = pow(hdr_reinhardTonemap(a.rgb), vec3(1.0 / gamma));

	// a.rgb = l2_what(a.rgb);
	
#if AO_SHADING_MODE != AO_MODE_NONE
	a *= fragData.ao?vec4(_cvv_ao,_cvv_ao,_cvv_ao,1):vec4(1);
#endif

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
	gl_FragData[TARGET_EMISSIVE] = vec4(fragData.emissivity, 0.0, 0.0, 1.0);
#endif
}
