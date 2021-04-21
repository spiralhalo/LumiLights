#include lumi:shaders/post/common/header.glsl

/******************************************************
  lumi:shaders/post/copy_array.frag
******************************************************/
uniform sampler2DArray u_input;

#ifndef USE_LEGACY_FREX_COMPAT
out vec4[1] fragColor;
#endif

void main()
{
    fragColor[0] = textureArray(u_input, vec3(v_texcoord, frxu_layer));
}
