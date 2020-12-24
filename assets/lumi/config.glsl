/*******************************
 *  lumi:config.glsl           *
 *******************************/

/*******************************
 *  SYSTEM -DO NOT EDIT-       *
 *******************************/

#include respackopts:config_supplier
#ifndef LUMI_UseConfig

#define LUMI_Tonemap_Default 0
#define LUMI_Tonemap_Vibrant 1
#define LUMI_Tonemap_Film 2

#define LUMI_DebugMode_Disabled 0
#define LUMI_DebugMode_Normal 1
#define LUMI_DebugMode_ViewDir 2

/*******************************
 * vv CONFIGURATIONS START vv  *
 *******************************/

/* Tonemap mode
 * 0 = Default
 * 1 = Vibrant
 * 2 = Film 
 ****************/
#define LUMI_Tonemap 0

/* Comment out to disable PBR
 * Disabling PBR can increase performance on low end machines
   ("Comment out" means adding double slash at the beginning)
 **************************************************************/
#define LUMI_PBR
// #define LUMI_PBR /* this is example of commented out variable. */

/* Debug mode
 * 0 = Disable
 * 1 = Render normals
 * 2 = Render view direction
 *****************************/
#define LUMI_DebugMode 0

/* Uncomment to enable wavy water model
   ("Uncomment" means removing double slash at the beginning)
***************************************************************/
// #define LUMI_WavyWaterModel

/* Uncomment to enable sunlight bloom during sunrise and sunset
*****************************************************************/
// #define LUMI_ApplyDramaticBloom

/* Comment out to disable bloom on the sky
********************************************/
#define LUMI_ApplySkyBloom



/*******************************
 * ^^ CONFIGURATIONS END ^^    *
 *******************************/




/*******************************
 *  SYSTEM -DO NOT EDIT-       *
 *******************************/

#endif
