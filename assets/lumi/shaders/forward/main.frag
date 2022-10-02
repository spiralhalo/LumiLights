#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/api/pbr_ext.glsl
#include lumi:shaders/common/forward.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/prog/overlay.glsl
#include lumi:shaders/prog/shading.glsl
#include lumi:shaders/prog/water.glsl
#include lumi:shaders/lib/bitpack.glsl
#include lumi:shaders/lib/pack_normal.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/forward/main.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_tex_glint;
uniform sampler2D u_tex_nature;

in float pv_diffuse;
in vec3 pv_vertex;

out vec4[7] fragColor;

void frx_pipelineFragment()
{
#ifdef DISABLE_ENTITIES
	if (frx_modelOriginCamera && !frx_renderTargetParticles) discard;
#endif

	// no pitch black material allowed
	frx_fragColor = max(frx_fragColor, vec4(0.004, 0.004, 0.004, 0.0));

	// cutout_zero by default. remove if causing unwanted consequences.
	if (frx_fragColor.a == 0.0) {
		discard;
	}

	// Vanilla AO never make sense for anything other than terrain
	if (!frx_modelOriginRegion) {
		frx_fragEnableAo = false;
	}

	#ifdef WHITE_WORLD
	frx_fragColor.rgb = vec3(1.0);
	#endif

	if (frx_isGui && !frx_isHand) {
		float diffuse = mix(pv_diffuse, 1, frx_fragEmissive);
		// diffuse = frx_isGui ? diffuse : min(1.0, 1.5 - diffuse);
		diffuse = frx_fragEnableDiffuse ? diffuse : 1.0;
		frx_fragColor.rgb *= diffuse;
		frx_fragColor.rgb += autoGlint(u_tex_glint, frx_normalizeMappedUV(frx_texcoord), frx_matGlint);
	} else {
		#if LUMI_PBR_API >= 7
		pbrExt_resolveProperties();
		#else // safeguard
		bool pbrExt_doTBN = true;
		bool pbr_isWater = false;
		bool pbr_builtinWater = false;
		#endif

		if (pbr_builtinWater) {
			pbr_isWater = true;
			frx_fragReflectance = 0.02;
			frx_fragRoughness = 0.05;

			/* WATER RECOLOR */
			// alpha=0.7 is the hard lower limit for outdoors water for better surface objects reflection potential
			#if WATER_COLOR == WATER_COLOR_NO_TEXTURE
			frx_fragColor = vec4(frx_vertexColor.rgb * 0.49, 0.7);

			#elif WATER_COLOR == WATER_COLOR_NATURAL_BLUE
			frx_fragColor.rgb *= mix(1.0, 0.49, frx_smoothedEyeBrightness.y);
			frx_fragColor.a = mix(frx_fragColor.a, 0.7, frx_smoothedEyeBrightness.y);

			#elif WATER_COLOR == WATER_COLOR_NO_COLOR
			frx_fragColor.rgb = vec3(0.075, 0.1, 0.125);
			// ironically, lower sky light (usually) means more block light to reflect making it more visible without alpha
			frx_fragColor.a = mix(0.3, 0.7, frx_smoothedEyeBrightness.y);

			#endif

			#ifdef WATER_WAVES
			frx_fragNormal = sampleWaterNormal(u_tex_nature, pv_vertex + frx_cameraPos, abs(frx_vertexNormal));
			#endif
		}

		#ifdef WATER_NOISE_DEBUG
		float wtrNs = sampleWaterNoise(u_tex_nature, pv_vertex + frx_cameraPos, vec2(0.0), abs(frx_vertexNormal));
		frx_fragColor.rgba += vec4(wtrNs * wtrNs * wtrNs);
		#endif

		if (frx_fragRoughness == 0.0) frx_fragRoughness = 1.0; // TODO: fix assumption?

		if (pbrExt_doTBN) {
			vec3 bitangent = cross(frx_vertexNormal, frx_vertexTangent.xyz) * frx_vertexTangent.w;
			mat3 TBN = mat3(frx_vertexTangent.xyz, bitangent, frx_vertexNormal);
			frx_fragNormal = TBN * frx_fragNormal;
		}

		// reduce noise caused by micro normal in faraway blocks
		float farBlend = l2_clampScale(16.0 * 1.0, 16.0 * 4.0, length(pv_vertex));
		frx_fragNormal = normalize(mix(frx_fragNormal, frx_vertexNormal, farBlend));
		
		#ifndef VANILLA_AO_ENABLED
		frx_fragEnableAo = false;
		#endif

		float ao = (frx_fragEnableAo && frx_modelOriginRegion) ? frx_fragLight.z : 1.0;

		float roughness = max(0.01, frx_fragRoughness); // TODO: use white clear color and stop doing this
		roughness = max(0.01, roughness - roughness * 0.6 * frx_smoothedRainGradient * l2_clampScale(0.9, 0.93, frx_fragLight.y));
		float disableDiffuse = 1.0 - float(frx_fragEnableDiffuse);

		// put water flag last because it makes the material buffer looks blue :D easier to debug
		float bitFlags = bit_pack(frx_matFlash, frx_matHurt, frx_matGlint, 0., disableDiffuse, 0., 0., float(pbr_isWater));

		// PERF: view normal, more useful than world normal
		fragColor[1] = vec4(frx_fragLight.xy, frx_fragEmissive, 1.0);
		fragColor[2] = vec4(frx_vertexNormal, 1.0);
		fragColor[3] = vec4(frx_fragNormal, 1.0);
		fragColor[4] = vec4(roughness, frx_fragReflectance, ao, 1.0);
		fragColor[5] = vec4(frx_normalizeMappedUV(frx_texcoord), bitFlags, 1.0);
	}

	// Advanced translucency 4.0
	if (frx_renderTargetTranslucent || frx_renderTargetEntity) {
		frx_fragColor.rgb *= fastLight(frx_fragLight.xy, frx_vertexNormal);
	}

	fragColor[0] = frx_fragColor;
}
