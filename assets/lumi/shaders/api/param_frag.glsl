/*******************************************************
 *  lumi:shaders/api/param_frag.glsl                     *
 *******************************************************/

#ifdef LUMI_PBRX
    #define LUMI_PBR_API 1
    float pbr_roughness = 1.0;
    float pbr_metallic = 0.0;
    vec3 pbr_f0 = vec3(-1.0);
#else
    float phong_specular = 0.0;
#endif
