#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/volumetric_cloud.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/post/clouds_texture.frag              *
 *******************************************************/

void main()
{
    #if CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
    if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
        gl_FragData[0] = generateCloudTexture(v_texcoord);
    }
    #endif
}
