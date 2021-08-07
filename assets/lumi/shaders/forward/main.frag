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
#include lumi:shaders/lib/translucent_layering.glsl
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

in vec2 pv_lightcoord;
in float pv_ao;
in float pv_diffuse;
in float pv_ortho;

out vec4[8] fragColor;

frx_FragmentData frx_createPipelineFragment()
{
#ifdef VANILLA_LIGHTING
	return frx_FragmentData (
		texture(frxs_baseColor, frx_texcoord, frx_matUnmippedFactor() * -4.0),
		frx_color,
		frx_matEmissive() ? 1.0 : 0.0,
		!frx_matDisableDiffuse(),
		!frx_matDisableAo(),
		frx_normal,
		pv_lightcoord,
		pv_ao
	);
#else
	return frx_FragmentData (
		texture(frxs_baseColor, frx_texcoord, frx_matUnmippedFactor() * -4.0),
		frx_color,
		frx_matEmissive() ? 1.0 : 0.0,
		!frx_matDisableDiffuse(),
		!frx_matDisableAo(),
		frx_normal
	);
#endif
}

void frx_writePipelineFragment(in frx_FragmentData fragData)
{
	vec4 a = fragData.spriteColor * fragData.vertexColor;
	
	// cutout_zero by default. remove if causing unwanted consequences.
	if (fragData.spriteColor.a == 0.0) {
		discard;
	}

	if (pbr_f0 < 0.0) {
		pbr_f0 = 1./256. + frx_luminance(a.rgb) * 0.04;
	}

	// Vanilla AO never make sense for anything other than terrain
	if (frx_modelOriginType() != MODEL_ORIGIN_REGION) {
		fragData.ao = false;
	}

	bool maybeGUI = frx_modelOriginType() == MODEL_ORIGIN_SCREEN && pv_ortho == 1.;

	if (maybeGUI) {

		float diffuse = mix(pv_diffuse, 1, fragData.emissivity);
		// diffuse = frx_isGui() ? diffuse : min(1.0, 1.5 - diffuse);
		diffuse = fragData.diffuse ? diffuse : 1.0;
		a.rgb *= diffuse;
		#if GLINT_MODE == GLINT_MODE_GLINT_SHADER
			a.rgb += noise_glint(frx_normalizeMappedUV(frx_texcoord), frx_matGlint());
		#else
			a.rgb += texture_glint(u_glint, frx_normalizeMappedUV(frx_texcoord), frx_matGlint());
		#endif

	} else {

		if (pbr_isWater) {
			/* WATER RECOLOR */
		#if WATER_COLOR == WATER_COLOR_NO_TEXTURE
			a.rgb = fragData.vertexColor.rgb;
			a.rb *= fragData.vertexColor.rb;
			float blue = fragData.vertexColor.b * fragData.vertexColor.b;
			a.rgb += blue * 0.25;
			a.rgb *= (1.0 - 0.5 * blue);
			fragData.spriteColor.a = 0.3;
		#elif WATER_COLOR == WATER_COLOR_NO_COLOR
			a.rgb = vec3(0.0);
			fragData.spriteColor.a = 0.2;
		#else
			a.rb *= fragData.vertexColor.rb;
			float blue = fragData.vertexColor.b * fragData.vertexColor.b;
			a.rgb += blue * 0.25;
			a.rgb *= (1.0 - 0.5 * blue);
			a.a *= 0.6;
		#endif
		}

		bool maybeHand = frx_modelOriginType() == MODEL_ORIGIN_SCREEN;
		bool isParticle = (frx_renderTarget() == TARGET_PARTICLES);

		vec3 normal = fragData.vertexNormal;

		if (pbr_normalMicro.x > 90.) {
			pbr_normalMicro = normal;
			pbr_tangent = vec3(0.);
		}

		float bloom = fragData.emissivity * a.a;
		float ao = fragData.ao ? (1.0 - fragData.aoShade) * a.a : 0.0;
		float normalizedBloom = (bloom - ao) * 0.5 + 0.5;

		vec3 packedNormal;

		if (maybeHand) {
			packedNormal = normal * frx_normalModelMatrix();
			packedNormal = 0.5 + 0.5 * packedNormal;
			pbr_normalMicro = pbr_normalMicro * frx_normalModelMatrix();
		} else {
			packedNormal = packNormal(normal, pbr_tangent);
		}

		pbr_normalMicro = pbr_normalMicro * 0.5 + 0.5;

		//pad with 0.01 to prevent conflation with unmanaged draw
		// NB: diffuse is forced true for hand
		float roughness = (fragData.diffuse || maybeHand) ? 0.01 + clamp(pbr_roughness, 0.0, 1.0) * 0.98 : 1.0;

		// put water flag last because it makes the material buffer looks blue :D easier to debug
		float bitFlags = bit_pack(frx_matFlash() ? 1. : 0., frx_matHurt() ? 1. : 0., frx_matGlint(), 0., 0., 0., 0., pbr_isWater ? 1. : 0.);

		// PERF: view normal, more useful than world normal
		fragColor[1] = vec4(fragData.light.xy, (isParticle || maybeHand) ? bloom : normalizedBloom, 1.0);
		fragColor[2] = vec4(packedNormal, 1.0);
		fragColor[3] = vec4(pbr_normalMicro, 1.0);
		fragColor[4] = vec4(roughness, pbr_metallic, pbr_f0, 1.0);
		fragColor[5] = vec4(frx_normalizeMappedUV(frx_texcoord), bitFlags, 1.0);

		if (frx_renderTarget() == TARGET_TRANSLUCENT || frx_renderTarget() == TARGET_ENTITY) {
			fragColor[6] = vec4(a.rgb, 1.0);
			fragColor[7] = vec4(a.a, 0.0, 0.0, 1.0);

		#if TRANSLUCENT_LAYERING == TRANSLUCENT_LAYERING_FANCY
			// apply semi-real diffuse in forward
			a.rgb *= calcLuminosity(normal, fragData.light, a.a);
		#endif
		}
	}

	gl_FragDepth = gl_FragCoord.z;
	fragColor[0] = a;
}
