#include lumi:aesthetics_config
#include lumi:sky_config
#include lumi:clouds_config
#include lumi:debug_config
#include lumi:experimental_config
#include lumi:fog_config
#include lumi:gameplay_config
#include lumi:performance_config
#include lumi:shadow_config
#include lumi:ssao_config

/*******************************************************
 *  lumi:shaders/common/userconfig.glsl
 *******************************************************
 *  One context for "pure" userconfigs defines.
 *  No const allowed here.
 *******************************************************/

#if ANTIALIASING == ANTIALIASING_TAA || ANTIALIASING == ANTIALIASING_TAA_BLURRY
	#define TAA_ENABLED
#endif

#if TONE_PROFILE == TONE_PROFILE_HIGH_CONTRAST
	#define HIGH_CONTRAST_ENABLED
#endif

#if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA_AND_SSAO || AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_PURE_SSAO
	#define SSAO_ENABLED
#endif

#if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA || AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA_AND_SSAO
	#define VANILLA_AO_ENABLED
#endif

const float USER_GODRAYS_INTENSITY = LIGHTRAYS_INTENSITY * 0.1;

#if SKY_REFLECTION_PROFILE != SKY_REFLECTION_PROFILE_MINIMUM
	#define REFLECT_SUN
#endif

#if SKY_REFLECTION_PROFILE == SKY_REFLECTION_PROFILE_FANCY
	#define REFLECT_CLOUDS
#endif
