#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/forward.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/prog/glintify.glsl
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

uniform sampler2D u_glint;

in float pv_diffuse;
in float pv_ortho;

out vec4[7] fragColor;

void frx_pipelineFragment()
{
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

	if (frx_isGui && !frx_isHand) {
		float diffuse = mix(pv_diffuse, 1, frx_fragEmissive);
		// diffuse = frx_isGui ? diffuse : min(1.0, 1.5 - diffuse);
		diffuse = frx_fragEnableDiffuse ? diffuse : 1.0;
		frx_fragColor.rgb  *= diffuse;

		#if GLINT_MODE == GLINT_MODE_GLINT_SHADER
		frx_fragColor.rgb += noise_glint(frx_normalizeMappedUV(frx_texcoord), frx_matGlint);
		#else
		frx_fragColor.rgb += texture_glint(u_glint, frx_normalizeMappedUV(frx_texcoord), frx_matGlint);
		#endif
	} else {
		if (pbr_isWater) {
			/* WATER RECOLOR */
			#if WATER_COLOR == WATER_COLOR_NO_TEXTURE
			frx_fragColor.rgb  = frx_vertexColor.rgb;
			frx_fragColor.a   *= 0.6;

			#elif WATER_COLOR == WATER_COLOR_NO_COLOR
			frx_fragColor.rgb = vec3(0.0);
			frx_fragColor.a   *= 0.6;

			#elif WATER_COLOR == WATER_COLOR_NATURAL_BLUE
			frx_fragColor.a   *= 0.6;
			#endif
		}

		bool doTBN = true;

		if (frx_fragRoughness == 0.0) frx_fragRoughness = 1.0; // TODO: fix assumption?

		#if LUMI_PBR_API == 7
		pbrExt_resolveProperties();
		doTBN = pbrExt_doTBN;
		#endif

		// TODO: TBN multiply
		if (doTBN && frx_fragNormal.z == 1.0) {
			frx_fragNormal = frx_vertexNormal;
		}

		#ifdef VANILLA_AO_ENABLED
		float ao = frx_fragEnableAo ? frx_fragLight.z : 1.0;
		frx_fragLight.xy = max(vec2(0.03125), frx_fragLight.xy * ao);
		#endif

		float roughness = max(0.01, frx_fragRoughness);
		float disableAo = frx_fragEnableAo ? 0.0 : 1.0;

		// put water flag last because it makes the material buffer looks blue :D easier to debug
		float bitFlags = bit_pack(frx_matFlash, frx_matHurt, frx_matGlint, disableAo, 0., 0., 0., pbr_isWater ? 1. : 0.);

		vec3 vertexNormal = frx_vertexNormal * 0.5 + 0.5;
		vec3 fragNormal = frx_fragNormal * 0.5 + 0.5;

		// PERF: view normal, more useful than world normal
		fragColor[1] = vec4(frx_fragLight.xy, frx_fragEmissive, 1.0);
		fragColor[2] = vec4(vertexNormal, 1.0);
		fragColor[3] = vec4(fragNormal, 1.0);
		fragColor[4] = vec4(roughness, pbr_metallic, frx_fragReflectance, 1.0);
		fragColor[5] = vec4(frx_normalizeMappedUV(frx_texcoord), bitFlags, 1.0);
	}

	// Advanced translucency 3.0
	if (frx_renderTargetTranslucent) {
		frx_fragColor.a *= frx_fragColor.a;
	}

	gl_FragDepth = gl_FragCoord.z;
	fragColor[0] = frx_fragColor;
}
