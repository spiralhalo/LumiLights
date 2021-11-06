#include frex:shaders/api/fragment.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/**********************************************
	lumi:shaders/material/glow.frag
***********************************************/

void frx_startFragment(inout frx_FragmentData fragData) {
	if (fragData.emissivity == 0.0) {
		//glowsquid
		fragData.emissivity = frx_luminance(fragData.spriteColor.rgb * 3.0);

		#ifdef VANILLA_LIGHTING
		fragData.emissivity *= fragData.light.x;
		fragData.light.x *= 0.5;
		#endif
	} else {
		//glowing text
		#ifdef VANILLA_LIGHTING
		float glow = step(0.93625, fragData.light.x);
		fragData.light.y *= (1.0 - glow * 0.5);
		fragData.emissivity = glow;
		#endif
	}
}
