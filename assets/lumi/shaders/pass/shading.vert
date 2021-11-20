#include lumi:shaders/pass/header.glsl

#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/lib/rectangle.glsl
#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/prog/shading.glsl
#include lumi:shaders/prog/sky.glsl

/*******************************************************
 *  lumi:shaders/pass/shading.vert
 *******************************************************/

out float v_blindness;

void main()
{
	basicFrameSetup();
	atmos_generateAtmosphereModel();
	celestSetup();
	skySetup();
	shadingSetup();

	// TODO: multiple instances found; make common?
	v_blindness = l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(frx_vanillaClearColor)) * float(frx_effectBlindness);
}
