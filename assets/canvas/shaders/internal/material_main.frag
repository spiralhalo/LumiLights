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

#include canvas:apitarget

/******************************************************
  canvas:shaders/internal/material_main.frag
******************************************************/

#define M_2PI 6.283185307179586476925286766559

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

vec3 l2_skyAmbient(float skyLight, float time, float intensity){
	float sa = l2_clampScale(0.03125, 1.0, skyLight) * intensity * 0.6;
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
	return sa * ambientColor;
}

vec3 l2_baseAmbient(){
	return vec3(l2_max3(texture2D(frxs_lightmap, vec2(0.03125, 0.03125)).rgb) );
}

vec3 l2_sunLight(float skyLight, float time, float intensity, vec3 normal){
	float sl = l2_clampScale(0.03125, 1.0, skyLight) * intensity * 1.5;
    float aRad = time * M_2PI;
	sl = min(1.15, sl * dot(normalize(vec3(cos(aRad), sin(aRad), 0.5)), normal));
	vec3 sunColor = vec3(1.0);
	vec3 sunriseColor = vec3(1.0, 0.8, 0.4);
	vec3 sunsetColor = vec3(1.0, 0.6, 0.4);
	if(time > 0.94){
		sl *= l2_clampScale(0.94, 1.0, time);
		sunColor = sunriseColor;
	} else if(time > 0.5){
		sl *= l2_clampScale(0.56, 0.5, time);
		sunColor = sunsetColor;
	} else if(time > 0.48){
		sunColor = mix(sunColor, sunsetColor, l2_clampScale(0.48, 0.5, time));
	} else if(time < 0.02){
		sunColor = mix(sunColor, sunriseColor, l2_clampScale(0.02, 0, time));
	}
	return sl * sunColor;
}

vec3 l2_moonLight(float skyLight, float time, float intensity, vec3 normal){
	float ml = l2_clampScale(0.03125, 1.0, skyLight) * intensity * frx_moonSize()*0.8;
    float aRad = (time - 0.5) * M_2PI;
	ml *= dot(vec3(cos(aRad), sin(aRad), 0), normal);
	if(time < 0.56){
		ml *= l2_clampScale(0.5, 0.56, time);
	} else if(time > 0.94){
		ml *= l2_clampScale(1.0, 0.94, time);
	}
	return vec3(ml);
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

	vec3 normal = fragData.vertexNormal*frx_normalModelMatrix();
	vec3 block = l2_blockLight(fragData.light.x);
	vec3 sun = l2_sunLight(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), normal);
	vec3 moon = l2_moonLight(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), normal);
	vec3 skyAmbient = l2_skyAmbient(fragData.light.y, frx_worldTime(), frx_ambientIntensity());

	vec3 light = max(min(vec3(1,1,1), block+moon+l2_baseAmbient()+skyAmbient), sun);

	a *= vec4(light, 1.0);

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
