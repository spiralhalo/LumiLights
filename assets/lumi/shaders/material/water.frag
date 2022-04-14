#include frex:shaders/api/fragment.glsl
#include lumi:shaders/api/pbr_ext.glsl

/**********************************************
	lumi:shaders/material/water.frag
***********************************************/

void frx_materialFragment()
{
#if LUMI_PBR_API >= 8
	pbr_builtinWater = true;
#endif
}
