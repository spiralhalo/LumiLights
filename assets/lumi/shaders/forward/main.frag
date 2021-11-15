#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/api/pbr_ext.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/func/glintify2.glsl
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

	if (pbr_f0 < 0.0) {
		pbr_f0 = 1./256. + frx_luminance(frx_fragColor.rgb) * 0.04;
	}

	// Vanilla AO never make sense for anything other than terrain
	if (!frx_modelOriginRegion) {
		frx_fragEnableAo = false;
	}

	bool maybeGUI = frx_modelOriginScreen && pv_ortho == 1.;

	if (maybeGUI) {

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
			frx_fragColor.rb  *= frx_vertexColor.rb;
			float blue = frx_vertexColor.b * frx_vertexColor.b;
			frx_fragColor.rgb += blue * 0.25;
			frx_fragColor.rgb *= (1.0 - 0.5 * blue);
			frx_spriteColor.a = 0.3; //TODO: broken; fix

			#elif WATER_COLOR == WATER_COLOR_NO_COLOR
			frx_fragColor.rgb = vec3(0.0);
			frx_spriteColor.a = 0.2; //TODO: broken; fix

			#elif WATER_COLOR == WATER_COLOR_NATURAL_BLUE
			frx_fragColor.rb  *= frx_vertexColor.rb;
			float blue = frx_vertexColor.b * frx_vertexColor.b;
			frx_fragColor.rgb += blue * 0.25;
			frx_fragColor.rgb *= (1.0 - 0.5 * blue);
			frx_fragColor.a   *= 0.77;
			#endif
		}

		bool maybeHand  = frx_modelOriginScreen;
		bool isParticle = frx_renderTargetParticles;

		vec3 normal = frx_vertexNormal;

		if (pbr_normalMicro.x > 90.) {
			pbr_normalMicro = normal;
		} else {
			pbr_tangent = vec3(0.);
		}

		float bloom   = frx_fragEmissive * frx_fragColor.a;
		float ao	  = frx_fragEnableAo ? (1.0 - frx_fragLight.z) * frx_fragColor.a : 0.0;
		float bloomAo = (bloom - ao) * 0.5 + 0.5;

		vec3 packedNormal;

		if (maybeHand) {
			packedNormal = normal * _cv_aDirtyHackModelMatrix;
			packedNormal = 0.5 + 0.5 * packedNormal;
			pbr_normalMicro = pbr_normalMicro * _cv_aDirtyHackModelMatrix;
		} else {
			packedNormal = packNormal(normal, pbr_tangent);
		}

		pbr_normalMicro = pbr_normalMicro * 0.5 + 0.5;

		//pad with 0.01 to prevent conflation with unmanaged draw
		// NB: diffuse is forced true for hand
		float roughness = (frx_fragEnableDiffuse || maybeHand) ? 0.01 + clamp(pbr_roughness, 0.0, 1.0) * 0.98 : 1.0;

		float disableAo = frx_fragEnableAo ? 0.0 : 1.0;
		// put water flag last because it makes the material buffer looks blue :D easier to debug
		float bitFlags = bit_pack(frx_matFlash, frx_matHurt, frx_matGlint, disableAo, 0., 0., 0., pbr_isWater ? 1. : 0.);

		// PERF: view normal, more useful than world normal
		fragColor[1] = vec4(frx_fragLight.xy, (isParticle || maybeHand) ? bloom : bloomAo, 1.0);
		fragColor[2] = vec4(packedNormal, 1.0);
		fragColor[3] = vec4(pbr_normalMicro, 1.0);
		fragColor[4] = vec4(roughness, pbr_metallic, pbr_f0, 1.0);
		fragColor[5] = vec4(frx_normalizeMappedUV(frx_texcoord), bitFlags, 1.0);
	}

	// Advanced translucency 2.2
	if (frx_renderTargetTranslucent) {
		fragColor[6] = vec4(packVec2(frx_fragColor.rg), packVec2(frx_fragColor.ba), 0.0, 1.0);
		frx_fragColor.a = pow(min(frx_fragColor.a, 1.0), 10.0);
	}

	gl_FragDepth = gl_FragCoord.z;
	fragColor[0] = frx_fragColor;
}
