#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/func/flat_cloud.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/clouds.vert					  *
 *******************************************************/

#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
out mat4 v_cloud_rotator;
#endif

out float v_blindness;

void main()
{
	basicFrameSetup();
	atmos_generateAtmosphereModel();

#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
	v_cloud_rotator = computeCloudRotator();
#endif

	// TODO: multiple instances found; make common?
	v_blindness = frx_playerHasEffect(FRX_EFFECT_BLINDNESS)
				? l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(frx_vanillaClearColor()))
				: 0.0;
}
