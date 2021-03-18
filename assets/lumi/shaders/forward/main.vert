#include frex:shaders/api/context.glsl
#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/sampler.glsl
#include lumi:shaders/context/global/lightsource.glsl
#include lumi:shaders/context/global/experimental.glsl
#include lumi:shaders/context/forward/common.glsl
#include lumi:shaders/forward/varying.glsl

/*******************************************************
 *  lumi:shaders/forward/main.vert                    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

// Grondag's vanilla diffuse
float p_diffuseGui(vec3 normal) {
    normal = normalize(gl_NormalMatrix * normal);
    float light = 0.4
    + 0.6 * clamp(dot(normal.xyz, vec3(-0.96104145, -0.078606814, -0.2593495)), 0.0, 1.0)
    + 0.6 * clamp(dot(normal.xyz, vec3(-0.26765957, -0.95667744, 0.100838766)), 0.0, 1.0);
    return min(light, 1.0);
}

// vec2 jitter(float n) {
//     return vec2(fract(sin(n) * 43758.5453123), fract(sin(n + 1.0) * 43758.5453123));
// }

vec2 weylSequence(int n) {
	return fract(vec2(n * 12664745, n*9560333) / exp2(24.0));
}

void frx_writePipelineVertex(inout frx_VertexData data) {

    if (frx_modelOriginType() == MODEL_ORIGIN_SCREEN) {
        lightsource_setVars();
        vec4 viewCoord = gl_ModelViewMatrix * data.vertex;
        gl_FogFragCoord = length(viewCoord.xyz);
        gl_Position = gl_ProjectionMatrix * viewCoord;
        l2_viewpos = viewCoord.xyz;
    } else {
        data.vertex += frx_modelToCamera();
        vec4 viewCoord = frx_viewMatrix() * data.vertex;
        gl_FogFragCoord = length(viewCoord.xyz);
        gl_Position = frx_projectionMatrix() * viewCoord;
        gl_Position.st += weylSequence(int(mod(frx_renderSeconds() * 60.0, 4.0))) * gl_Position.w / vec2(frx_viewWidth(), frx_viewHeight());
        l2_viewpos = viewCoord.xyz;
    }

#ifdef VANILLA_LIGHTING
    pv_lightcoord = data.light;
    pv_ao = data.aoShade;
#endif

    pv_diffuse = p_diffuseGui(data.normal);
}
