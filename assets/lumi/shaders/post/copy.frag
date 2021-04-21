#include lumi:shaders/post/common/header.glsl

/******************************************************
  lumi:shaders/post/copy.frag
******************************************************/
uniform sampler2D u_input;

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

void main()
{
    fragColor[0] = texture(u_input, v_texcoord);
}
