#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include lumi:shaders/api/water_param.glsl

void frx_startVertex(inout frx_VertexData data) {
    frx_var0.xyz = data.vertex.xyz + frx_modelOriginWorldPos();
#ifdef LUMI_WavyWaterModel
    float amplitude = 0.03;
    data.vertex.y += snoise(vec3(frx_var0.x * 2.0, frx_renderSeconds() * 0.5, frx_var0.z * 2.0)) * amplitude;
#endif
}
