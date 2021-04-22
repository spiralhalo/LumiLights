#include frex:shaders/api/context.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/compat.glsl
#include lumi:shaders/common/lightsource.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/api/pbr_ext.glsl
#include lumi:shaders/lib/taa_jitter.glsl

/*******************************************************
 *  lumi:shaders/forward/main.vert                    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

out vec2 pv_lightcoord;
out float pv_ao;
out float pv_diffuse;

// Grondag's vanilla diffuse but different
float p_diffuseGui(vec3 normal) {
    float light = 0.5
    + 0.3 * clamp(dot(normal.xyz, vec3(0.96104145, 0.078606814, 0.2593495)), 0.0, 1.0)
    + 0.5 * clamp(dot(normal.xyz, vec3(0.26765957, 0.95667744, -0.100838766)), 0.0, 1.0);
    return min(light, 1.0);
}

vec2 inv_size = 1.0 / vec2(frx_viewWidth(), frx_viewHeight());
void frx_writePipelineVertex(inout frx_VertexData data) {

    if (frx_modelOriginType() == MODEL_ORIGIN_SCREEN) {
        atmos_generateAtmosphereModel();
        gl_Position = frx_guiViewProjectionMatrix() * data.vertex;

        #ifdef TAA_ENABLED
            float fragZ = gl_Position.z / gl_Position.w;
            if (fragZ > 0.6) { // hack to include only hand
                gl_Position.st += taa_jitter(inv_size) * gl_Position.w;
            }
        #endif
    } else {
        data.vertex += frx_modelToCamera();
        gl_Position = frx_viewProjectionMatrix() * data.vertex;

        #ifdef TAA_ENABLED
            gl_Position.st += taa_jitter(inv_size) * gl_Position.w;
        #endif
    }

#ifdef VANILLA_LIGHTING
    pv_lightcoord = data.light;
    pv_ao = data.aoShade;
#endif

    pv_diffuse = p_diffuseGui(data.normal);
}
