#include lumi:experimental_config
#include lumi:aesthetics_config
#include lumi:performance_config
#include lumi:clouds_config
#include lumi:gameplay_config
#include lumi:fog_config

/*******************************************************
 *  lumi:shaders/common/userconfig.glsl                *
 *******************************************************
 *  One context for "pure" userconfigs defines.        *
 *  No const allowed here.                             *
 *******************************************************/

#if ANTIALIASING == ANTIALIASING_TAA || ANTIALIASING == ANTIALIASING_TAA_BLURRY
    #define TAA_ENABLED
#endif

#if TONE_PROFILE == TONE_PROFILE_AUTO_EXPOSURE || TONE_PROFILE == TONE_PROFILE_FIXED_EXPOSURE
    #define HIGH_CONTRAST_ENABLED
#endif

#if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_VANILLA_AND_SSAO || AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_PURE_SSAO
    #define SSAO_ENABLED
#endif

#if TONE_PROFILE == TONE_PROFILE_AUTO_EXPOSURE
#define DEF_NIGHT_SKY_MULTIPLIER 0.15
#else
#define DEF_NIGHT_SKY_MULTIPLIER 1.0
#endif

const float USER_GODRAYS_INTENSITY = GODRAYS_INTENSITY * 0.1;
const float VOLUMETRIC_FOG_SOFTNESS = VOLUMETRIC_FOG_SOFTNESS_RELATIVE / 20.;
