#include lumi:shaders/post/common/header.glsl

#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/ssao.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/ssao.vert
 *******************************************************/

out vec2 v_invSize;

#ifdef SSAO_ENABLED
out mat2 v_deltaRotator;

const int DIRECTIONS = clamp(SSAO_NUM_DIRECTIONS, 1, 10);
#endif

void main()
{
#ifdef SSAO_ENABLED
	v_deltaRotator = calcDeltaRotator(DIRECTIONS);
#endif

	v_invSize = 1.0 / frxu_size;
	basicFrameSetup();
}
