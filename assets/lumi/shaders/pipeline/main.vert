#include frex:shaders/api/context.glsl
#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/sampler.glsl
#include lumi:shaders/internal/context.glsl
#include lumi:shaders/internal/varying.glsl
#include lumi:shaders/internal/main_vert.glsl

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

const mat4 _tRotm = mat4(
0,  0, -1,  0,
0,  1,  0,  0,
1,  0,  0,  0,
0,  0,  0,  1 );

vec3 _tangent(vec3 normal)
{
    vec3 aaNormal = vec3(normal.x + 0.01, 0, normal.z + 0.01);
        aaNormal = normalize(aaNormal);
    return (_tRotm * vec4(aaNormal, 0.0)).xyz;
}

void frx_startPipelineVertex(inout frx_VertexData data) {
	vec4 view = gl_ModelViewMatrix * data.vertex;
	gl_ClipVertex = view;
	gl_FogFragCoord = length(view.xyz);
    l2_viewPos = view.xyz;
    l2_tangent = _tangent(data.vertexNormal);
}

void frx_endPipelineVertex(inout frx_VertexData data) {
	gl_Position = data.vertex;
}
