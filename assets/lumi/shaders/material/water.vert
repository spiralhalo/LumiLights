#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include lumi:shaders/internal/material_varying.glsl
#include lumi:shaders/api/water_param.glsl

#ifndef LUMI_WavyWaterIntensity
    #define LUMI_WavyWaterIntensity 1
#endif
#define wavyWater_loParams vec4(2.0, 0.5, 2.0, 0.03)
#define wavyWater_hiParams vec4(1.0, 1.0, 1.0, 0.05)

void frx_startVertex(inout frx_VertexData data) {
    set_l2_tangent(data.normal);
    frx_var0.xyz = data.vertex.xyz + frx_modelOriginWorldPos();
    frx_var1.xyz = vec3(0.5, 3.0, -1.0) * (0.5 + 0.5 - data.normal * 0.5);
    #ifdef LUMI_WavyWaterModel
        vec4 params = mix(wavyWater_loParams, wavyWater_hiParams, clamp((LUMI_WavyWaterIntensity - 1) * 0.1, 0.0, 1.5));
        data.vertex.y += snoise(vec3(frx_var0.x, frx_renderSeconds(), frx_var0.z) * params.xyz) * params.w;
    #endif
}
