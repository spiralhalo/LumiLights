#include frex:shaders/api/context.glsl
#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/sampler.glsl
#include lumi:shaders/internal/context.glsl
#include lumi:shaders/pipeline/varying.glsl

/*******************************************************
 *  lumi:shaders/pipeline/main.vert                    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

// Might not need these anymore in favor of frex texcoords conversion
// #ifdef LUMI_BUMP
// float bump_resolution;
// vec2 uvN;
// vec2 uvT;
// vec2 uvB;

// void startBump() {
//     bump_resolution = 1.0;
// }

// void setupBump(frx_VertexData data) {
//     float bumpSample = 0.015625 * bump_resolution;

//     uvN = data.spriteUV;
//     uvT = data.spriteUV + vec2(bumpSample, 0);
//     uvB = data.spriteUV - vec2(0, bumpSample);
//     bump_topRightUv = vec2(1.0, 0.0) + vec2(-bumpSample, bumpSample);
// }

// void endBump(vec4 spriteBounds) {
//     uvN = spriteBounds.xy + uvN * spriteBounds.zw;
//     uvT = spriteBounds.xy + uvT * spriteBounds.zw;
//     uvB = spriteBounds.xy + uvB * spriteBounds.zw;
//     bump_topRightUv = spriteBounds.xy + bump_topRightUv * spriteBounds.zw;
// }
// #endif

// Grondag's vanilla diffuse
float p_diffuseGui(vec3 normal) {
	normal = normalize(gl_NormalMatrix * normal);
	float light = 0.4
	+ 0.6 * clamp(dot(normal.xyz, vec3(-0.96104145, -0.078606814, -0.2593495)), 0.0, 1.0)
	+ 0.6 * clamp(dot(normal.xyz, vec3(-0.26765957, -0.95667744, 0.100838766)), 0.0, 1.0);
	return min(light, 1.0);
}

void frx_writePipelineVertex(inout frx_VertexData data) {

	if (frx_modelOriginType() == MODEL_ORIGIN_SCREEN) {
		vec4 viewCoord = gl_ModelViewMatrix * data.vertex;
		gl_ClipVertex = viewCoord;
		gl_FogFragCoord = length(viewCoord.xyz);
		gl_Position = gl_ProjectionMatrix * viewCoord;
    	l2_viewpos = viewCoord.xyz;
	} else {
		data.vertex += frx_modelToCamera();
		vec4 viewCoord = frx_viewMatrix() * data.vertex;
		gl_ClipVertex = viewCoord;
		gl_FogFragCoord = length(viewCoord.xyz);
		gl_Position = frx_projectionMatrix() * viewCoord;
    	l2_viewpos = viewCoord.xyz;
	}

	frx_texcoord = frx_mapNormalizedUV(data.spriteUV);
	pv_color = data.color;
	pv_normal = data.normal;

#ifdef VANILLA_LIGHTING
	pv_lightcoord = data.light;
	pv_ao = data.aoShade;
#endif

	pv_diffuse = p_diffuseGui(data.normal);
}
