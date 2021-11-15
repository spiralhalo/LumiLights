#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/hdr.vert
 *******************************************************/

out vec2 v_invSize;
out float v_blindness;

void main()
{
	basicFrameSetup();
	atmos_generateAtmosphereModel();

	v_invSize = 1.0 / frxu_size;

	// TODO: multiple instances found; make common?
	v_blindness = l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(frx_vanillaClearColor)) * float(frx_effectBlindness);
}
