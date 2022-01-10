#include lumi:shaders/pass/header.glsl

#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/taa.glsl
#include lumi:shaders/lib/taa_velocity.glsl

/******************************************************
 *	lumi:shaders/pass/taa.frag
 ******************************************************/

uniform sampler2D u_current;
uniform sampler2D u_history0;
uniform sampler2D u_depthCurrent;
uniform sampler2D u_depthHand;
uniform sampler2D u_debugText;

out vec4 fragColor;

void main()
{
#ifdef TAA_ENABLED
	#if TAA_DEBUG_RENDER != TAA_DEBUG_RENDER_OFF

	#if TAA_DEBUG_RENDER == TAA_DEBUG_RENDER_DEPTH
	fragColor = vec4(ldepth(texture(u_depthCurrent, v_texcoord).r));

	#elif TAA_DEBUG_RENDER == TAA_DEBUG_RENDER_FRAMES
	float d		= ldepth(texture(u_depthCurrent, v_texcoord).r);
	uint frames = frx_renderFrames % uint(frxu_size.x); 
	float on	= frames == uint(frxu_size.x * v_texcoord.x) ? 1.0 : 0.0;

	fragColor = vec4(on, 0.0, 0.25 + d * 0.5, 1.0);

	#else
	vec2 velocity = 0.5 + calcVelocity(u_depthCurrent, v_texcoord, v_invSize) * 50.0;
	fragColor = vec4(velocity, 0.0, 1.0);
	#endif

	#else // TAA_DEBUG_RENDER != TAA_DEBUG_RENDER_OFF
	// PROGRESS:
	// [o] velocity buffer works fine
	// [o] camera motion rejection (velocity reprojection) is decent
	// [o] ghosting reduction is decent
	// [o] terrain distortion is reduced by reducing feedback factor when camera moves

	float realCameraMove = length(frx_cameraPos - frx_lastCameraPos);

	#if ANTIALIASING == ANTIALIASING_TAA_BLURRY
	float cameraMove = 0.0;
	vec2 velocity    = vec2(0.0);
	#else
	float cameraMove = realCameraMove;
	vec2 velocity    = fastVelocity(u_depthCurrent, v_texcoord);
	#endif

	float depth		  = texture(u_depthCurrent, v_texcoord).r;
	float depthHand   = texture(u_depthHand, v_texcoord).r;
	float topMidDepth = texture(u_depthHand, vec2(0.5, 1.0)).r; // skip if hand render is disabled (F1)
	bool isHand		  = depthHand != 1.0 && topMidDepth == 1.0;

	bool skip = depth == 1. && frx_worldIsEnd == 1; // the end sky is noisy so don't apply TAA (note: true for vanilla)
		 skip = skip || (isHand && (abs(velocity.x) > v_invSize.x || abs(velocity.y) > v_invSize.y));

	if (skip) {
		fragColor = texture(u_current, v_texcoord);
	} else {
		fragColor = TAA(u_current, u_history0, u_depthCurrent, v_texcoord, velocity, v_invSize, cameraMove);
	}
	#endif
#else
	fragColor = texture(u_current, v_texcoord);
#endif

	#if TAA_DEBUG_RENDER != TAA_DEBUG_RENDER_OFF || defined(WATER_NOISE_DEBUG) || defined(WHITE_WORLD)
	const vec2 size = vec2(0.2 / 2.0, 0.06);
	vec2 debugTextCoord = vec2(clamp(v_texcoord.x, 0.5 - size.x, 0.5 + size.x), clamp(v_texcoord.y, 1.0 - size.y, 1.0));

	if (v_texcoord == debugTextCoord) {
		debugTextCoord.x = l2_clampScale(0.5 - size.x, 0.5 + size.x, v_texcoord.x);
		debugTextCoord.y = l2_clampScale(1.0, 1.0 - size.y, v_texcoord.y);

		fragColor = fragColor * 0.5 + texture(u_debugText, debugTextCoord) * 0.5;
	}
	#endif
}
