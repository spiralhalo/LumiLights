#include lumi:aesthetics_config
#include lumi:sky_config
#include lumi:clouds_config
#include lumi:debug_config
#include lumi:effects_config
#include lumi:experimental_config
#include lumi:fog_config
#include lumi:lighting_config
#include lumi:reflection_config
#include lumi:shadow_config
#include lumi:water_config

/*******************************************************
 *  lumi:shaders/common/userconfig.glsl
 *******************************************************/

#if ANTIALIASING == ANTIALIASING_TAA
	#define TAA_ENABLED
#endif

// #if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA_AND_SSAO || AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_PURE_SSAO
	// #define SSAO_ENABLED
// #endif

// #if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA || AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA_AND_SSAO
#define VANILLA_AO_ENABLED
// #endif

const float HORIZON_BLEND = clamp(HORIZON_BLEND_RELATIVE * 0.1, 0.0, 1.0);

const float REFLECTION_MAXIMUM_ROUGHNESS = REFLECTION_MAXIMUM_ROUGHNESS_RELATIVE / 10.0;

const float SSAO_VIEW_RADIUS = float(clamp(SSAO_RADIUS_INT, 1, 20)) / 10.;
const float SSAO_INTENSITY	 = float(clamp(SSAO_INTENSITY_INT, 4, 20)) / 4.;
