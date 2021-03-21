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

const vec2 halton[4] = vec2[4](
    vec2(0.5, 0.3333333333333333),
    vec2(0.25, 0.6666666666666666),
    vec2(0.75, 0.1111111111111111),
    vec2(0.125, 0.4444444444444444)
    // vec2(0.625, 0.7777777777777777),
    // vec2(0.375, 0.2222222222222222),
    // vec2(0.875, 0.5555555555555556),
    // vec2(0.0625, 0.8888888888888888),
    // vec2(0.5625, 0.037037037037037035),
    // vec2(0.3125, 0.37037037037037035),
    // vec2(0.8125, 0.7037037037037037),
    // vec2(0.1875, 0.14814814814814814),
    // vec2(0.6875, 0.48148148148148145),
    // vec2(0.4375, 0.8148148148148147),
    // vec2(0.9375, 0.25925925925925924),
    // vec2(0.03125, 0.5925925925925926)
    );

void frx_writePipelineVertex(inout frx_VertexData data) {

    if (frx_modelOriginType() == MODEL_ORIGIN_SCREEN) {
        lightsource_setVars();
        vec4 viewCoord = gl_ModelViewMatrix * data.vertex;
        gl_Position = gl_ProjectionMatrix * viewCoord;
        l2_viewpos = viewCoord.xyz;
    } else {
        data.vertex += frx_modelToCamera();
        vec4 viewCoord = frx_viewMatrix() * data.vertex;
        gl_Position = frx_projectionMatrix() * viewCoord;
        l2_viewpos = viewCoord.xyz;

        #if ANTIALIASING == ANTIALIASING_TAA
            // This produces correct velocity
            vec4 cameraToLastCamera = vec4(frx_cameraPos() - frx_lastCameraPos(), 0.0);
            pv_prevPos = _cvu_matrix[_CV_MAT_CLEAN_VIEW_PROJ_LAST] * (data.vertex + cameraToLastCamera);
            pv_nextPos = _cvu_matrix[_CV_MAT_CLEAN_VIEW_PROJ] * data.vertex;
            // Require canvas feature: frame number
            gl_Position.st += halton[int(mod(frx_renderSeconds() * 60.0, 4.0))] * gl_Position.w / vec2(frx_viewWidth(), frx_viewHeight());
        #endif
    }

#ifdef VANILLA_LIGHTING
    pv_lightcoord = data.light;
    pv_ao = data.aoShade;
#endif

    pv_diffuse = p_diffuseGui(data.normal);
}
