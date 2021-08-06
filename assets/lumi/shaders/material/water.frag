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

const float stretch = 1.2;

void frx_startFragment(inout frx_FragmentData fragData)
{
#ifdef LUMI_PBRX
	/* PBR PARAMS */
	pbr_f0 = 0.02;
	pbr_roughness = 0.05;
	pbr_isWater = true;
#endif
}
