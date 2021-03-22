#include lumi:experimental_config
#include lumi:clouds_config

/*******************************************************
 *  lumi:shaders/context/global/userconfig.glsl        *
 *******************************************************
 *  One context for "pure" userconfigs defines.        *
 *  No const allowed here.                             *
 *******************************************************/

 #if ANTIALIASING == ANTIALIASING_TAA || ANTIALIASING == ANTIALIASING_TAA_BLURRY || ANTIALIASING == ANTIALIASING_TAA_DEBUG
    #define TAA_ENABLED
#endif
