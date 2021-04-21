#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/common/bloom.glsl
#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/post/downsample.frag
******************************************************/
uniform sampler2D u_input;

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

void main()
{
    fragColor[0] = frx_sample13(u_input, v_texcoord, BLOOM_DOWNSAMPLE_DIST_VEC / frxu_size, max(0, frxu_lod - 1));
}
