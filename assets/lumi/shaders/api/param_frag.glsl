#include lumi:shaders/context/forward/common.glsl
// load the contexts as soon as the params are requested

/*******************************************************
 *  lumi:shaders/api/param_frag.glsl                     *
 *******************************************************/

#define LUMI_PBR_API 1
float pbr_roughness = 1.0;
float pbr_metallic = 0.0;
float pbr_f0 = -1.0;
float phong_specular = 0.0;
