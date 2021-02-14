#include frex:shaders/api/view.glsl
#include lumi:shaders/lib/util.glsl

/******************************************************
  lumi:shaders/forward/shadow.vert
******************************************************/

void frx_writePipelineVertex(in frx_VertexData data) {
    // move to camera origin
    vec4 shadowVertex = data.vertex + frx_modelToCamera();
    gl_ClipVertex = frx_shadowViewMatrix() * shadowVertex;
    gl_Position = frx_shadowViewProjectionMatrix() * shadowVertex;
}
