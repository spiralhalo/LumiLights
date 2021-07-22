#include frex:shaders/api/fragment.glsl
#include frex:shaders/lib/math.glsl

/**********************************************
	lumi:shaders/material/glowsquid.frag
***********************************************/

void frx_startFragment(inout frx_FragmentData fragData) {
	#ifdef VANILLA_LIGHTING
	fragData.light.x *= 0.5;
	#endif
	fragData.emissivity = frx_luminance(fragData.spriteColor.rgb * 3.0);
}
