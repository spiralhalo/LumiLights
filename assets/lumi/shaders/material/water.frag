#include frex:shaders/api/fragment.glsl
#include lumi:shaders/api/pbr_ext.glsl

/**********************************************
	lumi:shaders/material/water.frag
***********************************************/

void frx_materialFragment()
{
#if LUMI_PBR_API >= 6
	pbr_f0 = 0.02;
	pbr_roughness = 0.05;
	pbr_isWater = true;
#endif
}
