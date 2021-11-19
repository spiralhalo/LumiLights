#include frex:shaders/api/header.glsl

#define POST_SHADER

#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl

/*******************************************************
 *  lumi:shaders/post/header.glsl
 *******************************************************/

uniform ivec2 frxu_size;
uniform int	frxu_lod;
uniform int	frxu_layer;
uniform mat4 frxu_frameProjectionMatrix;

#ifdef VERTEX_SHADER
#define lumi_vary out

out vec2 v_texcoord;
out vec2 v_invSize;

void basicFrameSetup()
{
	vec4 screen = frxu_frameProjectionMatrix * vec4(in_vertex.xy * frxu_size, 0.0, 1.0);
	gl_Position = vec4(screen.xy, 0.2, 1.0);
	v_texcoord  = in_uv;
	v_invSize = 1.0 / frxu_size;
}
#else
#define lumi_vary in

in vec2 v_texcoord;
in vec2 v_invSize;
#endif

#define ID_SOLID_LIGT 0
#define ID_SOLID_MATS 1
#define ID_SOLID_MISC 2
#define ID_TRANS_COLR 3
#define ID_TRANS_LIGT 4
#define ID_TRANS_MATS 5
#define ID_TRANS_MISC 6
#define ID_PARTS_COLR 7
#define ID_PARTS_LIGT 8
