/*******************************
 *  lumi:config.glsl           *
 *******************************/

/*******************************
 *  SYSTEM -DO NOT EDIT-       *
 *******************************/

#include respackopts:config_supplier
#ifndef respackopts_loaded

/*******************************
 * vv CONFIGURATIONS START vv  *
 *******************************/

/* NOTE: These configurations are ignored if Respackopts is present. */

/* Uncomment to enable textureless water
   ("Uncomment" means removing double slash at the beginning)
***************************************************************/
// #define LUMI_NoWaterTexture

/* Comment out to disable wavy water model
***************************************************************/
#define LUMI_WavyWaterModel

/* Intensity of the wavy water model. Range: 1 ... 15 Default: 7
*******************************************************************/
#define LUMI_WavyWaterIntensity 7

/*******************************
 * ^^ CONFIGURATIONS END ^^    *
 *******************************/




/*******************************
 *  SYSTEM -DO NOT EDIT-       *
 *******************************/

#endif
