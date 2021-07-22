#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/common/bloom.glsl
#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/post/downsample.frag
******************************************************/
uniform sampler2D u_input;

out vec4 fragColor;

void main()
{
	fragColor = frx_sample13(u_input, v_texcoord, BLOOM_DOWNSAMPLE_DIST_VEC / frxu_size, max(0, frxu_lod - 1));
}
