#include frex:shaders/api/header.glsl

#define POST_SHADER

#include lumi:shaders/common/compat.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl

/*******************************************************
 *  lumi:shaders/post/common/header.glsl
 *******************************************************/

uniform ivec2 frxu_size;
uniform int frxu_lod;

#ifndef USE_LEGACY_FREX_COMPAT
uniform mat4 frxu_frameProjectionMatrix;
#endif

#ifdef VERTEX_SHADER
out vec2 v_texcoord;
out vec3 v_up;

void basicFrameSetup()
{
	vec4 screen = frxu_frameProjectionMatrix * vec4(in_vertex.xy * frxu_size, 0.0, 1.0);
	gl_Position = vec4(screen.xy, 0.2, 1.0);
	v_texcoord  = in_uv;
	v_up		= frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);
}
#else
in vec2 v_texcoord;
in vec3 v_up;
#endif
