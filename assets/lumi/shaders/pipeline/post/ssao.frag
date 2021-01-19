#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/lib/ssao.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl

uniform sampler2D u_normal;
uniform sampler2D u_depth;

const float RADIUS = 1.0;
const float BIAS = 0.5;
const float INTENSITY = 5.0;

void main()
{
    float random = v_texcoord.x*v_texcoord.y;
    float ssao = calc_ssao(
        u_normal, u_depth, frx_normalModelMatrix(), frx_inverseProjectionMatrix(), frx_inverseViewProjectionMatrix(), frxu_size, 4.0,
        v_texcoord, RADIUS, BIAS, INTENSITY);
    gl_FragData[0] = vec4(ssao, 0.0, 0.0, 1.0);
}
