#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/common/bloom.glsl
#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/post/upsample.frag
******************************************************/
uniform sampler2D u_input;
uniform sampler2D u_prior;

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

void main()
{
    vec4 prior = frx_sampleTent(u_prior, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, frxu_lod + 1);
    fragColor[0] = textureLod(u_input, v_texcoord, frxu_lod) + prior;
}
