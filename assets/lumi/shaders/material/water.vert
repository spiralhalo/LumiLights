#include frex:shaders/api/vertex.glsl
#include lumi:shaders/api/pbr_vars.glsl

void frx_startVertex(inout frx_VertexData data) {
    pbr_roughness = 0.05;
}
