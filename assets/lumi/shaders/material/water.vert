#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include lumi:config.glsl
#include lumi:shaders/api/pbr_ext.glsl

/**********************************************
	lumi:shaders/material/water.vert
***********************************************/

const vec4 wavyWater_loParams = vec4(2.0, 0.5, 2.0, 0.03);
const vec4 wavyWater_hiParams = vec4(1.0, 1.0, 1.0, 0.05);

void frx_materialVertex() {
	pbrExt_tangentSetup(frx_vertexNormal);
	vec3 worldPos = frx_vertex.xyz + frx_modelToWorld.xyz;
	frx_var0.xyz = worldPos;
#ifdef LUMI_WavyWaterModel
	vec4 params = mix(wavyWater_loParams, wavyWater_hiParams, clamp((LUMI_WavyWaterIntensity - 1) * 0.1, 0.0, 1.5));
	frx_vertex.y += snoise(vec3(worldPos.x, frx_renderSeconds, worldPos.z) * params.xyz) * params.w;
#endif
}
