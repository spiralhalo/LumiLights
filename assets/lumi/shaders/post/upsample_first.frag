#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/common/bloom.glsl
#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/post/upsample_first.frag
******************************************************/
uniform sampler2D u_input;

void main()
{
    gl_FragData[0] = texture2DLod(u_input, v_texcoord, frxu_lod);
}
