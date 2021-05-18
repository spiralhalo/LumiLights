#include lumi:shaders/post/common/header.glsl

/******************************************************
  lumi:shaders/post/reflection_halfcopy.frag
******************************************************/
uniform sampler2D u_input;

out vec4 fragColor;

void main()
{
#ifdef HALF_REFLECTION_RESOLUTION
    fragColor = texture(u_input, v_texcoord * 0.5);
#else
    discard;
#endif
}
