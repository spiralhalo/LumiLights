#include frex:shaders/api/fragment.glsl
#include lumi:shaders/api/pbr_ext.glsl
#include forgetmenot:shaders/lib/api/fmn_pbr.glsl

/**********************************************
	lumi:shaders/material/water.frag
***********************************************/

void frx_materialFragment()
{
#if LUMI_PBR_API >= 8
	pbr_builtinWater = true;
#endif

#if FMN_PBR >= 1
    fmn_isWater = 1;
#endif
}
