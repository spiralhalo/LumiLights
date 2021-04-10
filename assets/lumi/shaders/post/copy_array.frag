#include lumi:shaders/post/common/header.glsl

/******************************************************
  lumi:shaders/post/copy_array.frag
******************************************************/
uniform sampler2DArray u_input;

out vec4 fragColor;

void main()
{
    fragColor = textureArray(u_input, vec3(v_texcoord, frxu_layer));
}
