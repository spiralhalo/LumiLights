#include frex:shaders/api/fragment.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/**********************************************
	lumi:shaders/material/warmth.frag
***********************************************/

void frx_materialFragment() {
#ifndef DEPTH_PASS
	float min_ = min( min(frx_sampleColor.r, frx_sampleColor.g), frx_sampleColor.b );
	float max_ = max( max(frx_sampleColor.r, frx_sampleColor.g), frx_sampleColor.b );
	float s = max_ > 0 ? (max_ - min_) / max_ : 0;
	float e = frx_luminance(frx_sampleColor.rgb);
	bool red = (frx_sampleColor.r > 0.5 || (frx_sampleColor.r - frx_sampleColor.b) > 0.3) && s > 0.6;
	bool yellow = (frx_sampleColor.r + frx_sampleColor.g - frx_sampleColor.b) > 0.5 && s > 0.5 && e > 0.5;
	bool lit = e >  0.8 || yellow || red;
	frx_fragEmissive = lit ? 1.0 : 0.0;
#endif
}
