#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/common/bloom.glsl
#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/post/upsample.frag
******************************************************/
uniform sampler2D u_input;
uniform sampler2D u_prior;

out vec4 fragColor;

void main()
{
    vec4 prior = frx_sampleTent(u_prior, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, frxu_lod + 1);
    fragColor = textureLod(u_input, v_texcoord, frxu_lod) + prior;
}
