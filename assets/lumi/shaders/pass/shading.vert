#include lumi:shaders/pass/header.glsl

#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/lib/rectangle.glsl
#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/prog/fog.glsl
#include lumi:shaders/prog/shading.glsl
#include lumi:shaders/prog/sky.glsl

/*******************************************************
 *  lumi:shaders/pass/shading.vert
 *******************************************************/

void main()
{
	basicFrameSetup();
	atmos_generateAtmosphereModel();
	celestSetup();
	skySetup();
	shadingSetup();
	fogVarsSetup();
}
