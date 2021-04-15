#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include lumi:config.glsl
#include lumi:shaders/api/pbr_ext.glsl

#ifndef LUMI_WavyWaterIntensity
    #define LUMI_WavyWaterIntensity 1
#endif
const vec4 wavyWater_loParams = vec4(2.0, 0.5, 2.0, 0.03);
const vec4 wavyWater_hiParams = vec4(1.0, 1.0, 1.0, 0.05);

const float smol_waveSpeed = 1;
const float smol_scale = 1.5;
const float smol_amplitude = 0.01;
const float beeg_waveSpeed = 0.8;
const float beeg_scale = 6.0;
const float beeg_amplitude = 0.25;

void frx_startVertex(inout frx_VertexData data) {
    pbrExt_tangentSetup(data.normal);
    float waveSpeed = mix(smol_waveSpeed, beeg_waveSpeed, abs(data.normal.y));
    float scale = mix(smol_scale, beeg_scale, abs(data.normal.y));
    float amplitude = mix(smol_amplitude, beeg_amplitude, abs(data.normal.y));
    frx_var0.xyz = data.vertex.xyz + frx_modelOriginWorldPos();
    frx_var1.xyz = vec3(0.5, 3.0, -1.0) * (0.5 + 0.5 - data.normal * 0.5);
    frx_var2.xyz = vec3(waveSpeed, scale, amplitude);
    #ifdef LUMI_WavyWaterModel
        vec4 params = mix(wavyWater_loParams, wavyWater_hiParams, clamp((LUMI_WavyWaterIntensity - 1) * 0.1, 0.0, 1.5));
        data.vertex.y += snoise(vec3(frx_var0.x, frx_renderSeconds(), frx_var0.z) * params.xyz) * params.w;
    #endif
}
