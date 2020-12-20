/*******************************************************
 *  Lumi Lights - Shader pack for Canvas               *
 *******************************************************
 *  Copyright (c) 2020 spiralhalo and Contributors.    *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#include canvas:shaders/internal/header.glsl
#include canvas:shaders/internal/varying.glsl
#include canvas:shaders/internal/diffuse.glsl
#include canvas:shaders/internal/flags.glsl
#include canvas:shaders/internal/fog.glsl
#include canvas:shaders/internal/program.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/camera.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include lumi:config.glsl
#include lumi:shaders/api/pbr_frag.glsl
#include lumi:shaders/api/context_bump.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/internal/varying.glsl
#include lumi:shaders/internal/main_frag.glsl
#include lumi:shaders/internal/lightsource.glsl
#include lumi:shaders/internal/tonemap.glsl
#include lumi:shaders/internal/pbr_shading.glsl
#include lumi:shaders/internal/phong_shading.glsl
#include lumi:shaders/internal/debug_shading.glsl
#include lumi:shaders/internal/skybloom.glsl

#include canvas:apitarget

/******************************************************
  canvas:shaders/internal/material_main.frag
******************************************************/

void _cv_startFragment(inout frx_FragmentData data) {
	int cv_programId = _cv_fragmentProgramId();
#include canvas:startfragment
}

void main() {
#ifndef PROGRAM_BY_UNIFORM
	if (_cv_programDiscard()) {
		discard;
	}
#endif

	frx_FragmentData fragData = frx_FragmentData (
	texture2D(frxs_spriteAltas, _cvv_texcoord, _cv_getFlag(_CV_FLAG_UNMIPPED) * -4.0),
	_cvv_color,
	frx_matEmissive() ? 1.0 : 0.0,
	!frx_matDisableDiffuse(),
	!frx_matDisableAo(),
	_cvv_normal,
	_cvv_lightcoord
	);

#ifdef LUMI_PBR
	pbr_roughness = 1.0;
	pbr_metallic = 0.0;
	pbr_f0 = vec3(-1.0);
#else
	ww_specular = 0.0;
#endif

	_cv_startFragment(fragData);

	vec4 a = clamp(fragData.spriteColor * fragData.vertexColor, 0.0, 1.0);
	float bloom = fragData.emissivity; // separate bloom from emissivity
	bool translucent = _cv_getFlag(_CV_FLAG_CUTOUT) == 0.0 && a.a < 0.99;

	if(frx_isGui()){
#if DIFFUSE_SHADING_MODE != DIFFUSE_MODE_NONE
		if(fragData.diffuse){
			float diffuse = mix(_cvv_diffuse, 1, fragData.emissivity);
			vec3 shading = mix(vec3(0.5, 0.4, 0.8) * diffuse * diffuse, vec3(1.0), diffuse);
			a.rgb *= shading;
		}
#endif
	} else {
#if DEBUG_MODE != DEBUG_DISABLED
		debug_shading(fragData, a);
#else
		float userBrightness;
		float brightnessBase = texture2D(frxs_lightmap, vec2(0.03125, 0.03125)).r;
		if(frx_worldHasSkylight()){
			userBrightness = smoothstep(0.053, 0.135, brightnessBase);
		} else {
			// simplified for both nether and the end
			userBrightness = smoothstep(0.15, 0.63, brightnessBase);
			// if(frx_isWorldTheNether()){
			// 	userBrightness = smoothstep(0.15/*0.207 no true darkness in nether*/, 0.577, brightnessBase);
			// } else if (frx_isWorldTheEnd(){
			// 	userBrightness = smoothstep(0.18/*0.271 no true darkness in the end*/, 0.685, brightnessBase);
			// }
		}
	#ifdef LUMI_PBR
		pbr_shading(fragData, a, bloom, userBrightness, translucent);
	#else
		phong_shading(fragData, a, bloom, userBrightness, translucent);
	#endif
#endif
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
	translucent = translucent && a.a < 0.99;
	gl_FragData[TARGET_EMISSIVE] = vec4(bloom * a.a, 1.0, 0.0, translucent ? step(hdr_skyBloom, bloom) : 1.0);
#endif
}
