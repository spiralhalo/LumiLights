#include lumi:shaders/pass/header.glsl

#include lumi:shaders/lib/bitpack.glsl

/******************************************************
  lumi:shaders/pass/ao0.frag
******************************************************/

uniform sampler2DArray u_gbuffer_main_etc;

layout(location = 0) out vec4 rawMatCopy;

void main()
{
	rawMatCopy = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_SOLID_MATS));
}
