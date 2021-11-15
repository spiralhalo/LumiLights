#include frex:shaders/api/material.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/lib/util.glsl

/******************************************************
	lumi:shaders/forward/shadow.vert
******************************************************/
 
uniform int frxu_cascade;

#ifndef NAME_TAG_SHADOW
out float v_managed;
#endif

void frx_pipelineVertex() {
#ifndef NAME_TAG_SHADOW
	// this approach might also exclude particles and diffuse-disabled entities
	v_managed = (frx_matDisableDiffuse == 1 && frx_modelOriginCamera) ? 0. : 1.;
#endif

	// move to camera origin
	vec4 shadowVertex = frx_vertex + frx_modelToCamera;

	gl_Position = frx_shadowViewProjectionMatrix(frxu_cascade) * shadowVertex;
}
