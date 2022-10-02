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

const float REFLECTION_MAXIMUM_ROUGHNESS = REFLECTION_MAXIMUM_ROUGHNESS_RELATIVE / 10.0;

const float SSAO_VIEW_RADIUS = clamp(SSAO_RADIUS_F, 0.1, 2.0);
const float SSAO_INTENSITY	 = clamp(SSAO_INTENSITY_F, 1.0, 5.0);

const float BLOOM_SCALE = clamp(BLOOM_SCALE_F, 0.1, 2.0);
const float BLOOM_INTENSITY = clamp(BLOOM_INTENSITY_F, 0.1, 1.0);
