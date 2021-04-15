/*******************************************************
 *  lumi:shaders/api/pbr_ext.glsl                      *
 *******************************************************/

#define LUMI_PBRX
#define LUMI_PBR_API 3

#ifdef VERTEX_SHADER

out vec3 l2_tangent;

const mat4 _pbrExt_rotm = mat4(
0,  0, -1,  0,
0,  1,  0,  0,
1,  0,  0,  0,
0,  0,  0,  1 );

void pbrExt_tangentSetup(vec3 normal)
{
    vec3 aaNormal = vec3(normal.x + 0.01, 0, normal.z + 0.01);
        aaNormal = normalize(aaNormal);
    l2_tangent = (_pbrExt_rotm * vec4(aaNormal, 0.0)).xyz;
}

#else

in vec3 l2_tangent;

float pbr_roughness = 1.0;
float pbr_metallic = 0.0;
float pbr_f0 = -1.0;
vec3  pbr_normalMicro = vec3(99., 99., 99.);

#endif
