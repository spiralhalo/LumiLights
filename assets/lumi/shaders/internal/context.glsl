#include lumi:config.glsl

/*******************************************************
 *  lumi:shaders/internal/context.glsl                 *
 *******************************************************
 *  This routine bridges between internal user config  *
 *  variables and externalized context variables.      *
 *******************************************************/

#ifdef LUMI_PBR
	#define LUMI_PBRX
#endif
#ifdef LUMI_GenerateBump
#include lumi:shaders/api/context_bump.glsl
#endif
