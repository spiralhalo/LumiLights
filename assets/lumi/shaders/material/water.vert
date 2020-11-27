#include frex:shaders/api/vertex.glsl
#include lumi:shaders/api/pbr_vars.glsl

void frx_startVertex(inout frx_VertexData data) {
    frx_var0.xyz = data.vertex.xyz + frx_modelOriginWorldPos();
}
