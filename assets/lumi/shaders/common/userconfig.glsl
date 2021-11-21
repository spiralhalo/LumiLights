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
#include lumi:ssao_config
#include lumi:water_config

/*******************************************************
 *  lumi:shaders/common/userconfig.glsl
 *******************************************************/

#if ANTIALIASING == ANTIALIASING_TAA || ANTIALIASING == ANTIALIASING_TAA_BLURRY
	#define TAA_ENABLED
#endif

#if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA_AND_SSAO || AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_PURE_SSAO
	#define SSAO_ENABLED
#endif

#if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA || AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA_AND_SSAO
	#define VANILLA_AO_ENABLED
#endif

const float HORIZON_BLEND = clamp(HORIZON_BLEND_RELATIVE * 0.1, 0.0, 1.0);
