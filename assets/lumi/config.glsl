/*******************************
 *  lumi:config.glsl           *
 *******************************/

/*******************************
 *  SYSTEM -DO NOT EDIT-       *
 *******************************/

#include lumi:lighting_config
#include respackopts:config_supplier
#ifndef respackopts_loaded

#define LUMI_Tonemap_Default 0
#define LUMI_Tonemap_Vibrant 1
#define LUMI_Tonemap_Film 2

#define LUMI_DebugMode_Disabled 0
#define LUMI_DebugMode_Normal 1
#define LUMI_DebugMode_ViewDir 2

#define LUMI_LightingMode_Dramatic 0
#define LUMI_LightingMode_Neutral 1

/*******************************
 * vv CONFIGURATIONS START vv  *
 *******************************/

/* NOTE: These configurations are ignored if Respackopts is present. */

/* Comment out to disable PBR
 * Disabling PBR can increase performance on low end machines
   ("Comment out" means adding double slash at the beginning)
 **************************************************************/
#define LUMI_PBR
// #define LUMI_PBR /* this is example of commented out variable. */

/* Comment out to disable bump generation
 ******************************************/
#define LUMI_GenerateBump

/* How blue the day ambient in the overworld is. Range: 0 ... 10 Default: 0
*****************************************************************************/
#define LUMI_DayAmbientBlue 0

/* Uncomment to enable wavy water model
   ("Uncomment" means removing double slash at the beginning)
***************************************************************/
// #define LUMI_WavyWaterModel

/* Intensity of the wavy water model. Range: 1 ... 15 Default: 1
*******************************************************************/
#define LUMI_WavyWaterIntensity 1

/* Uncomment to enable sunlight bloom during sunrise and sunset
*****************************************************************/
// #define LUMI_ApplyDramaticBloom

/* Comment out to disable bloom on the sky
********************************************/
#define LUMI_ApplySkyBloom

/* Intensity of the sky bloom. Range: 0 ... 10 Default: 5
************************************************************/
#define LUMI_SkyBloomIntensity 5

/* Lighting mode
 * 0 = Dramatic: morning bloom and warm indoor lights
 * 1 = Neutral: neutral lighting
 * Note: these options may change in future versions.
 ******************************************************/
#define LUMI_LightingMode 0

/* Intensity of the dramatic bloom. Range: 0 ... 10 Default: 5
*****************************************************************/
#define LUMI_DramaticLighting_DramaticBloomIntensity 5

/* True darkness options
 * Uncomment to toggle.
******************************************************/
// #define LUMI_TrueDarkness_DisableOverworldAmbient
// #define LUMI_TrueDarkness_DisableMoonlight
// #define LUMI_TrueDarkness_NetherTrueDarkness
// #define LUMI_TrueDarkness_TheEndTrueDarkness

/* Tonemap mode
 * 0 = Default
 * 1 = Vibrant
 * 2 = Film 
 ****************/
#define LUMI_Tonemap 0

/* Debug mode
 * 0 = Disable
 * 1 = Render normals
 * 2 = Render view direction
 *****************************/
#define LUMI_DebugMode 0


/*******************************
 * ^^ CONFIGURATIONS END ^^    *
 *******************************/




/*******************************
 *  SYSTEM -DO NOT EDIT-       *
 *******************************/

#endif
