#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/common/bloom.glsl
#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/post/upsample_first.frag
******************************************************/
uniform sampler2D u_input;

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

void main()
{
    fragColor[0] = textureLod(u_input, v_texcoord, frxu_lod);
}
