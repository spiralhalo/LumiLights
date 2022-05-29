#include lumi:shaders/pass/header.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/taa.glsl
#include lumi:shaders/lib/taa_jitter.glsl

/******************************************************
 *	lumi:shaders/pass/taa.frag
 ******************************************************/

uniform sampler2D u_current;
uniform sampler2D u_history0;
uniform sampler2D u_depthCurrent;
uniform sampler2D u_depthHand;
uniform sampler2D u_debugText;

out vec4 fragColor;

#define FEEDBACK_MAX 0.9
#define FEEDBACK_MIN 0.1

vec4 clipAABB(vec3 colorMin, vec3 colorMax, vec4 currentColor, vec4 previousColor)
{
	vec3 p_clip = 0.5 * (colorMax + colorMin);
	vec3 e_clip = 0.5 * (colorMax - colorMin);
	vec4 v_clip = previousColor - vec4(p_clip, currentColor.a);
	vec3 v_unit = v_clip.rgb / e_clip;
	vec3 a_unit = abs(v_unit);
	float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

	if (ma_unit > 1.0) {
		return vec4(p_clip, currentColor.a) + v_clip / ma_unit;
	} else {
		return previousColor;// point inside aabb
	}
}

vec3 calcPrevNdc(vec3 currentNdc) {
	vec4 temp = frx_inverseViewProjectionMatrix * vec4(currentNdc, 1.0);
	vec3 currentPos = temp.xyz / temp.w;

	// transform current camera-space pos -> world-space pos (assumed static) -> previous camera-space pos
	vec3 prevPos = (currentPos + frx_cameraPos) - frx_lastCameraPos;

	temp = frx_lastViewProjectionMatrix * vec4(prevPos, 1.0);
	return temp.xyz / temp.w;
}

vec2 calcPrevUv(sampler2D depthBuffer, vec2 currentUv) {
	vec2 ndcJitter	   = taaJitter(v_invSize, frx_renderFrames);
	vec2 prevNdcJitter = taaJitter(v_invSize, frx_renderFrames - 1u);

	float depth = texture(depthBuffer, currentUv).r;
	vec2 prevUv = (calcPrevNdc(vec3(currentUv * 2.0 - 1.0 - ndcJitter, depth * 2.0 - 1.0)).xy + prevNdcJitter) * 0.5 + 0.5;

	if (prevUv != clamp(prevUv, 0.0, 1.0)) return currentUv; // out of bounds
	return prevUv;
}

float velocityWeight(sampler2D depthBuffer, vec2 currentUv) {
	float depth = texture(depthBuffer, currentUv).r;
	vec2 prevUv = calcPrevNdc(vec3(currentUv * 2.0 - 1.0, depth * 2.0 - 1.0)).xy * 0.5 + 0.5;
	return min(1.0, length((currentUv - prevUv) * frxu_size));
}

// based on INSIDE's TAA and https://github.com/ziacko/Temporal-AA
vec4 taa()
{
	const vec2 box[] = vec2[](
		vec2(-1, -1),
		vec2( 0, -1),
		vec2( 1, -1),
		vec2(-1,  0),
		vec2( 1,  0),
		vec2(-1,  1),
		vec2( 0,  1),
		vec2( 1,  1)
	);

	const vec2 plus[] = vec2[](
		vec2(-1, 0),
		vec2(0, -1),
		vec2(1, 0),
		vec2(0, 1)
	);

	vec2 prevCoord	  = calcPrevUv(u_depthCurrent, v_texcoord);
	vec4 currentColor = texture(u_current, v_texcoord);
	vec4 historyColor = texture(u_history0, prevCoord);

	vec3 minColor0 = currentColor.rgb;
	vec3 maxColor0 = currentColor.rgb;
	for(int i = 0; i < 8; i++) {
		vec3 sampled = texture(u_current, v_texcoord + box[i] * v_invSize).rgb;
		minColor0 = min(minColor0, sampled);
		maxColor0 = max(maxColor0, sampled);
	}

	vec3 minColor1 = currentColor.rgb;
	vec3 maxColor1 = currentColor.rgb;
	for(int i = 0; i < 4; i++) {
		vec3 sampled = texture(u_current, v_texcoord + plus[i] * v_invSize).rgb;
		minColor1 = min(minColor1, sampled);
		maxColor1 = max(maxColor1, sampled);
	}

	vec3 mixedMin = mix(minColor0, minColor1, 0.5);
	vec3 mixedMax = mix(maxColor0, maxColor1, 0.5);

	float feedback = mix(FEEDBACK_MAX, FEEDBACK_MIN, velocityWeight(u_depthCurrent, v_texcoord));
	vec4 clippedHistoryColor = clipAABB(mixedMin, mixedMax, currentColor, historyColor);

	return mix(currentColor, clippedHistoryColor, feedback);
}

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

	if (min(v_texcoord.x, v_texcoord.y) >= 0.75) {
		fragColor = texture(u_current, v_texcoord * 4.0 - 3.0);
	} else {
		fragColor = vec4(velocityWeight(u_depthCurrent, v_texcoord));
	}

#endif

#else // TAA_DEBUG_RENDER != TAA_DEBUG_RENDER_OFF

	vec2 prevCoord = calcPrevUv(u_depthCurrent, v_texcoord);
	vec2 velocity = v_texcoord - prevCoord;

	float depth		  = texture(u_depthCurrent, v_texcoord).r;
	float depthHand   = texture(u_depthHand, v_texcoord).r;
	float topMidDepth = texture(u_depthHand, vec2(0.5, 1.0)).r; // skip if hand render is disabled (F1)
	bool  isHand	  = depthHand != 1.0 && topMidDepth == 1.0;

	bool skip = depth == 1. && frx_worldIsEnd == 1; // the end sky is noisy so don't apply TAA (note: true for vanilla)
		 skip = skip || (isHand && (abs(velocity.x) > v_invSize.x || abs(velocity.y) > v_invSize.y));

	if (skip) {
		fragColor = texture(u_current, v_texcoord);
	} else {
		fragColor = taa();
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
