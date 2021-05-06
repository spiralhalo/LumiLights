#include frex:shaders/api/material.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/common/compat.glsl
#include lumi:shaders/lib/util.glsl

/******************************************************
    lumi:shaders/forward/shadow.vert
******************************************************/
 
uniform int frxu_cascade;

vert_out float v_managed;

void frx_writePipelineVertex(in frx_VertexData data) {
    // this approach might also exclude particles
    // currently particles don't cast shadow so it shouldn't be a problem
    v_managed = (frx_matDisableDiffuse() && data.normal.y == 1.) ? 0. : 1.;
    // move to camera origin
    vec4 shadowVertex = data.vertex + frx_modelToCamera();
	gl_Position = frx_shadowViewProjectionMatrix(frxu_cascade) * shadowVertex;
}
