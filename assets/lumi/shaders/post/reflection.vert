#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/lib/celest_adapter.glsl
#include lumi:shaders/func/flat_cloud.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/reflection.vert
 *******************************************************/

#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
out mat4 v_cloud_rotator;
#endif

out vec2 v_invSize;
out float v_blindness;
out vec3 v_celest1;
out vec3 v_celest2;
out vec3 v_celest3;

void main()
{
	basicFrameSetup();
	atmos_generateAtmosphereModel();

#ifdef REFLECT_SUN
	Rect theCelest = celestSetup();

	v_celest1 = theCelest.bottomLeft;
	v_celest2 = theCelest.bottomRight;
	v_celest3 = theCelest.topLeft;
#endif

#if defined(HALF_REFLECTION_RESOLUTION) && REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
	gl_Position.xy -= (gl_Position.xy - vec2(-1., -1.)) * .5;
#endif

#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
	v_cloud_rotator = computeCloudRotator();
#endif

	v_invSize = 1.0 / frxu_size;

	// TODO: multiple instances found; make common?
	v_blindness = frx_playerHasEffect(FRX_EFFECT_BLINDNESS)
				? l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(frx_vanillaClearColor()))
				: 0.0;
}
