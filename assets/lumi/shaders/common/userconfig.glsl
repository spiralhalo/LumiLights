#include lumi:experimental_config
#include lumi:aesthetics_config
#include lumi:performance_config
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

const float USER_GODRAYS_INTENSITY = GODRAYS_INTENSITY * 0.1;
