#include lumi:shaders/post/common/header.glsl

/******************************************************
  lumi:shaders/post/reflection_halfcopy.frag
******************************************************/
uniform sampler2D u_input;

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

void main()
{
#ifdef HALF_REFLECTION_RESOLUTION
    fragColor[0] = texture(u_input, v_texcoord * 0.5);
#else
    discard;
#endif
}
