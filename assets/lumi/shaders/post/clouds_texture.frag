#include lumi:shaders/context/post/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/clouds_texture.frag              *
 *******************************************************/

void main()
{
    #ifdef CUSTOM_CLOUD_RENDERING
    if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
        float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33;
        vec2 cloudCoord = frx_cameraPos().xz + (v_texcoord * 2.0 - 1.0) * 128.0 + frx_renderSeconds();//(frx_worldDay() + frx_worldTime());
        cloudCoord *= 15.0;

        float cloudBase = l2_clampScale(-0.5 - rainFactor * 0.5, 1.0 - rainFactor, snoise(cloudCoord * 0.005));
        float cloud1 = cloudBase * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.015));
        float cloud2 = cloud1 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.04));
        float cloud3 = cloud2 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.1));

        float cloud = cloud1 * 0.5 + cloud2 * 0.75 + cloud3;
        cloud = l2_clampScale(0.1, 0.4, cloud);
        
        gl_FragData[0] = vec4(cloud, 0.0 ,0.0, 1.0);
    }
    #endif
}
