#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/taa.glsl
#include lumi:shaders/lib/taa_velocity.glsl

/******************************************************
 *	lumi:shaders/post/taa.frag
 ******************************************************/

uniform sampler2D u_current;
uniform sampler2D u_history0;
uniform sampler2D u_depthCurrent;
uniform sampler2D u_depthHand;
uniform sampler2D u_debugText;

in vec2 v_invSize;

out vec4 fragColor;

void main()
{
#if defined(TAA_ENABLED) && TAA_DEBUG_RENDER != TAA_DEBUG_RENDER_OFF
	#if TAA_DEBUG_RENDER == TAA_DEBUG_RENDER_DEPTH
		fragColor = vec4(ldepth(texture(u_depthCurrent, v_texcoord).r));
	#elif TAA_DEBUG_RENDER == TAA_DEBUG_RENDER_FRAMES
		float d = ldepth(texture(u_depthCurrent, v_texcoord).r);
		uint frames = frx_renderFrames() % uint(frxu_size.x); 
		float on = frames == uint(frxu_size.x * v_texcoord.x) ? 1.0 : 0.0;
		fragColor = vec4(on, 0.0, 0.25 + d * 0.5, 1.0);
	#else
		vec2 velocity = 0.5 + calcVelocity(u_depthCurrent, v_texcoord, v_invSize) * 50.0;
		fragColor = vec4(velocity, 0.0, 1.0);
	#endif
	
	vec2 coord = vec2(clamp(v_texcoord.x, 0.35, 0.65), clamp(v_texcoord.y, 0.92, 1.0));

	if (v_texcoord == coord) {
		coord -= vec2(0.35, 0.92);
		coord *= vec2(1.0/0.3, -1.0/0.08);
		fragColor = texture(u_debugText, coord);
	}
#else

	// PROGRESS:
	// [o] velocity buffer works fine
	// [o] camera motion rejection (velocity reprojection) is decent
	// [o] ghosting reduction is decent
	// [o] terrain distortion is reduced by reducing feedback factor when camera moves

	#ifdef TAA_ENABLED
		float realCameraMove = length(frx_cameraPos() - frx_lastCameraPos());
		#if ANTIALIASING == ANTIALIASING_TAA_BLURRY
			float cameraMove = 0.0;
			vec2 velocity = vec2(0.0);
		#else
			float cameraMove = realCameraMove;
			vec2 velocity = fastVelocity(u_depthCurrent, v_texcoord);
		#endif

		float depth = texture(u_depthCurrent, v_texcoord).r;
		float depthHand = texture(u_depthHand, v_texcoord).r;
		float topMidDepth = texture(u_depthHand, vec2(0.5, 1.0)).r; // skip if hand render is disabled (F1)
		bool isHand = depthHand != 1.0 && topMidDepth == 1.0;

		bool skip = depth == 1. && frx_worldFlag(FRX_WORLD_IS_END); // the end sky is noisy so don't apply TAA (note: true for vanilla)

		skip = skip || (isHand && (abs(velocity.x) > v_invSize.x || abs(velocity.y) > v_invSize.y));

		if (skip) {
			fragColor = texture(u_current, v_texcoord);
		} else {
			fragColor = TAA(u_current, u_history0, u_depthCurrent, v_texcoord, velocity, v_invSize, cameraMove);
		}
	#else
		fragColor = texture(u_current, v_texcoord);
	#endif
#endif
}
