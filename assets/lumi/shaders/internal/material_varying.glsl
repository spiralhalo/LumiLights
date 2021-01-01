/***********************************************************
 *  lumi:shaders/internal/material_varying.glsl                     *
 ***********************************************************/

varying vec3 l2_tangent;

#ifdef VERTEX_SHADER
const mat4 _tRotm = mat4(
0,  0, -1,  0,
0,  1,  0,  0,
1,  0,  0,  0,
0,  0,  0,  1 );

void set_l2_tangent(vec3 normal)
{
    vec3 aaNormal = vec3(normal.x + 0.01, 0, normal.z + 0.01);
        aaNormal = normalize(aaNormal);
    l2_tangent = (_tRotm * vec4(aaNormal, 0.0)).xyz;
}
#endif
