#include frex:shaders/api/header.glsl

#define POST_SHADER

#include lumi:shaders/common/compat.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/common/lighting.glsl
#include lumi:shaders/common/userconfig.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl

/*******************************************************
 *  lumi:shaders/post/common/header.glsl               *
 *******************************************************/

uniform ivec2 frxu_size;
uniform int frxu_lod;
uniform mat4 frxu_frameProjectionMatrix;

#ifdef VERTEX_SHADER
out vec2 v_texcoord;
out vec3 v_up;
#else
in vec2 v_texcoord;
in vec3 v_up;
#endif
