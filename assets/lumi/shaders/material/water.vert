#include frex:shaders/api/vertex.glsl

void frx_startVertex(inout frx_VertexData data) {
    frx_var0.xyz = data.vertex.xyz + frx_modelOriginWorldPos();
}
