#include frex:shaders/api/context.glsl
#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/sampler.glsl
#include lumi:shaders/context/global/lightsource.glsl
#include lumi:shaders/context/global/userconfig.glsl
#include lumi:shaders/context/forward/common.glsl
#include lumi:shaders/forward/varying.glsl
#include lumi:shaders/lib/taa_jitter.glsl

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

vec2 inv_size = 1.0 / vec2(frx_viewWidth(), frx_viewHeight());
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
            gl_Position.st += taa_jitter(inv_size) * gl_Position.w;
        #endif
    }

#ifdef VANILLA_LIGHTING
    pv_lightcoord = data.light;
    pv_ao = data.aoShade;
#endif

    pv_diffuse = p_diffuseGui(data.normal);
}
