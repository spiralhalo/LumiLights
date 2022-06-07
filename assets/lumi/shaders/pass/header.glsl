#include frex:shaders/api/header.glsl

#define POST_SHADER

#include frex:shaders/api/world.glsl

// alpha stuff
#ifdef _alpha_frx_skyFlashStrength
	#define frx_skyFlashStrength _alpha_frx_skyFlashStrength
#elif !defined(frx_skyFlashStrength)
	#define frx_skyFlashStrength 0.0
#endif

#ifdef _alpha_frx_smoothedThunderGradient
	#define frx_smoothedThunderGradient _alpha_frx_smoothedThunderGradient
#elif !defined(frx_smoothedThunderGradient)
	#define frx_smoothedThunderGradient frx_thunderGradient
#endif

#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/pass/header.glsl
 *******************************************************/

uniform ivec2 frxu_size;
uniform int	frxu_lod;
uniform int	frxu_layer;
uniform mat4 frxu_frameProjectionMatrix;

#ifdef VERTEX_SHADER
#define l2_vary out

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
#define l2_vary in

in vec2 v_texcoord;
in vec2 v_invSize;
#endif

#define ID_SOLID_LIGT 0.
#define ID_TRANS_LIGT 1.
#define ID_PARTS_LIGT 2.

#define ID_SOLID_NORM 3.
#define ID_SOLID_MNORM 4.
#define ID_TRANS_NORM 5.
#define ID_TRANS_MNORM 6.

#define ID_TRANS_COLR 0.
#define ID_PARTS_COLR 1.

#define ID_SOLID_MATS 0.
#define ID_SOLID_MISC 1.
#define ID_TRANS_MATS 2.
#define ID_TRANS_MISC 3.

#define ID_OTHER_ALBEDO 0.
#define ID_OTHER_TRANS 1.
#define ID_OTHER_AFTER 2.
