#include lumi:shaders/pass/header.glsl

#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/lib/rectangle.glsl
#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/prog/sky.glsl

/*******************************************************
 *  lumi:shaders/pass/shading.vert
 *******************************************************/

out vec2 v_invSize;
out float v_blindness;

out float pbrv_coneInner;
out float pbrv_coneOuter;
out vec3  pbrv_flashLightView;

void main()
{
	basicFrameSetup();
	atmos_generateAtmosphereModel();
	celestSetup();
	skySetup();

	v_invSize = 1.0 / frxu_size;

	// TODO: multiple instances found; make common?
	v_blindness = l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(frx_vanillaClearColor)) * float(frx_effectBlindness);

	// const vec3 view_CV	= vec3(0.0, 0.0, -1.0); //camera view in view space
	// float cAngle		= asin(frx_cameraView.y);
	// float hlAngle		= clamp(HANDHELD_LIGHT_ANGLE, -45, 45) * PI / 180.0;
	// pbrv_flashLightView = (l2_rotationMatrix(vec3(1.0, 0.0, 0.0), l2_clampScale(abs(hlAngle), 0.0, abs(cAngle)) * hlAngle) * vec4(-view_CV, 0.0)).xyz;
	// pbrv_flashLightView = normalize(pbrv_flashLightView * frx_normalModelMatrix);

	pbrv_flashLightView = -frx_cameraView;
	pbrv_coneInner = clamp(frx_heldLightInnerRadius, 0.0, PI) / PI;
	pbrv_coneOuter = max(pbrv_coneInner, clamp(frx_heldLightOuterRadius, 0.0, PI) / PI);
}
