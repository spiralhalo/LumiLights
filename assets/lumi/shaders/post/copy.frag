#include lumi:shaders/post/common/header.glsl

/******************************************************
  lumi:shaders/post/copy.frag
******************************************************/
uniform sampler2D u_input;

#ifndef USE_LEGACY_FREX_COMPAT
out vec4[1] fragColor;
#endif

void main()
{
    fragColor[0] = texture(u_input, v_texcoord);
}
