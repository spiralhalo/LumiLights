/*******************************
 *  lumi:config.glsl           *
 *******************************/

/* Tonemap mode
 * 0 = Default
 * 1 = Vibrant
 * 2 = Film 
 ****************/
#define TONEMAP_MODE 0

/* Comment out to disable PBR
 * Disabling PBR can increase performance on low end machines
 **************************************************************/
#define LUMI_PBR
// #define LUMI_PBR // this is example of commented out config

/* Debug mode
 * 0 = Disable
 * 1 = Render normals
 * 2 = Render view direction
 *****************************/
#define DEBUG_MODE 0

/* Uncomment to enable wavy water model
*****************************************/
// #define WATER_VERTEX_WAVY

/* Uncomment to enable sunlight bloom during sunrise and sunset
*****************************************************************/
// #define DRAMATIC_LIGHTS

/* Comment out to disable bloom on the sky
********************************************/
#define APPLY_SKYBLOOM
