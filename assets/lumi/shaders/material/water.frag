#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/math.glsl
#include lumi:config.glsl
#include lumi:shaders/api/pbr_ext.glsl
#include lumi:shaders/lib/water.glsl

/**********************************************
	lumi:shaders/material/water.frag
***********************************************/

void frx_startFragment(inout frx_FragmentData fragData)
{
#if LUMI_PBR_API >= 6
	pbr_f0 = 0.02;
	pbr_roughness = 0.05;
	pbr_isWater = true;
	pbr_tangent = l2_tangent;
#endif
}
