#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/api/pbr_ext.glsl

/**********************************************
	lumi:shaders/material/water.vert
***********************************************/

void frx_materialVertex() {
	pbrExt_tangentSetup(frx_vertexNormal);
	vec3 worldPos = frx_vertex.xyz + frx_modelToWorld.xyz;
	frx_var0.xyz = worldPos;
}
