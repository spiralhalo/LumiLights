#include lumi:shaders/context/post/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/cellular2x2.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/clouds_texture.frag              *
 *******************************************************/

#define wnoise2(a) cellular2x2(a).x

void main()
{
    #if CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
    if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
        float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33; // TODO: optimize
        vec2 cloudCoord = frx_cameraPos().xz + (v_texcoord * 2.0 - 1.0) * 256.0 + (frx_worldDay() + frx_worldTime()) * 800.0;
        cloudCoord *= 2.0;

        float cloudBase = l2_clampScale(-0.3, 1.0 - rainFactor, snoise(cloudCoord * 0.005));
        float cloud1 = cloudBase * l2_clampScale(-1.0, 1.0, wnoise2(cloudCoord * 0.015));
        float cloud2 = cloud1 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.04));
        float cloud3 = cloud2 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.1));

        float cloud = cloud1 * 0.5 + cloud2 * 0.75 + cloud3;
        cloud = l2_clampScale(0.1, 1.0, cloud);
        
        gl_FragData[0] = vec4(cloud, 0.0 ,0.0, 1.0);
    }
    #endif
}
