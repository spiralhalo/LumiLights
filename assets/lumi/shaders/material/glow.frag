#include frex:shaders/api/fragment.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/**********************************************
	lumi:shaders/material/glow.frag
***********************************************/

void frx_materialFragment() {
	if (frx_fragEmissive == 0.0) {
		//glowsquid
		frx_fragEmissive = frx_luminance(frx_fragColor.rgb * 3.0);

		#ifdef VANILLA_LIGHTING
		frx_fragEmissive *= frx_fragLight.x;
		frx_fragLight.x *= 0.5;
		#endif
	} else {
		//glowing text
		#ifdef VANILLA_LIGHTING
		float glow = step(0.93625, frx_fragLight.x);
		frx_fragLight.y *= (1.0 - glow * 0.5);
		frx_fragEmissive = glow;
		#endif
	}
}
