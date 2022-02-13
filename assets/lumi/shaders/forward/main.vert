#include frex:shaders/api/context.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/common/compat.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/api/pbr_ext.glsl
#include lumi:shaders/lib/taa_jitter.glsl

/*******************************************************
 *  lumi:shaders/forward/main.vert
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

out float pv_diffuse;

#ifdef WATER_NOISE_DEBUG
out vec3 pv_vertex;
#endif

// Grondag's vanilla diffuse but different
float p_diffuseGui(vec3 normal) {
	// disable diffuse for front facing GUI item
	if (normal.z == 1.0) return 1.;

	float light = 0.5
				+ 0.3 * clamp(dot(normal.xyz, vec3(0.96104145, 0.078606814, 0.2593495)), 0.0, 1.0)
				+ 0.5 * clamp(dot(normal.xyz, vec3(0.26765957, 0.95667744, -0.100838766)), 0.0, 1.0);

	return min(light, 1.0);
}

vec2 inv_size = 1.0 / vec2(frx_viewWidth, frx_viewHeight);
void frx_pipelineVertex() {

	if (frx_modelOriginScreen) {
		#ifdef WATER_NOISE_DEBUG
		pv_vertex = frx_vertex.xyz;
		#endif

		gl_Position = frx_guiViewProjectionMatrix * frx_vertex;

		#ifdef TAA_ENABLED
		if (frx_isHand) {
			gl_Position.st += taaJitter(inv_size, frx_renderFrames) * gl_Position.w;
		}
		#endif
	} else {
		frx_vertex += frx_modelToCamera;

		#ifdef WATER_NOISE_DEBUG
		pv_vertex = frx_vertex.xyz + frx_cameraPos;
		#endif

		#ifdef TAA_ENABLED
		#ifdef SHADOW_MAP_PRESENT
		gl_Position = frx_viewProjectionMatrix * frx_vertex;
		#else
		/* make every pixel slightly farther from camera so vanilla renders (round entity shadow, block outline) don't
		clip into jittered faces.

		side effect: they render slightly above managed faces, depending on strength.

		strength is bigger when the screen is smaller. the multiplier is brute forced to get the smallest amount of
		both clipping and side effect at reasonable angles. note: the strength should be leaning towards 1.0 when
		directly facing the eye (view normal z = 1.0) but we want to reduce compute by using a constant.*/
		float correctionStrength = 1.0 + max(inv_size.x, inv_size.y) * 7.0;
		gl_Position = frx_projectionMatrix * vec4((frx_viewMatrix * frx_vertex).xyz * correctionStrength, 1.0);
		#endif

		gl_Position.st += taaJitter(inv_size, frx_renderFrames) * gl_Position.w;
		#else
		gl_Position = frx_viewProjectionMatrix * frx_vertex;
		#endif
	}

	pv_diffuse = p_diffuseGui(frx_vertexNormal);
}
