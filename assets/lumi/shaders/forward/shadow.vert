#include frex:shaders/api/view.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/shadow_distort.glsl

/******************************************************
  lumi:shaders/forward/shadow.vert
******************************************************/
 
uniform int frxu_cascade;

void frx_writePipelineVertex(in frx_VertexData data) {
    // move to camera origin
    vec4 shadowVertex = data.vertex + frx_modelToCamera();
    gl_Position = distortedShadowPos(shadowVertex, frxu_cascade);
}
