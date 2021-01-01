/*******************************************************
 *  lumi:shaders/api/param_frag.glsl                     *
 *******************************************************/

#define LUMI_PBR_API 1
float pbr_roughness = 1.0;
float pbr_metallic = 0.0;
vec3 pbr_f0 = vec3(-1.0);
float phong_specular = 0.0;
#define LUMI_PARAM_LOADED
