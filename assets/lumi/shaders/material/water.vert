#include frex:shaders/api/vertex.glsl
#include lumi:shaders/api/varying.glsl

void frx_startVertex(inout frx_VertexData data) {
	frx_var0.xyz = data.vertex.xyz;
	frx_var1.xyz = (gl_ModelViewMatrixInverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    wwv_specPower = 100.0;
}
