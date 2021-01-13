#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/fast_gaussian_blur.glsl
#include lumi:shaders/lib/godrays.glsl

/******************************************************
  lumi:shaders/pipeline/post/composite.frag
******************************************************/

uniform sampler2D u_hdr_solid;
uniform sampler2D u_hdr_solid_swap;
uniform sampler2D u_solid_depth;
uniform sampler2D u_hdr_translucent;
uniform sampler2D u_hdr_translucent_swap;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_clouds;
uniform sampler2D u_clouds_depth;

varying vec3 v_godray_color;
varying vec2 v_skylightpos;
varying float v_godray_intensity;
varying float v_aspect_adjuster;

// arbitrary chosen depth threshold
#define blurDepthThreshold 0.001
void main()
{
    vec4 solid = texture2D(u_hdr_solid, v_texcoord);
    float solid_roughness = texture2D(u_hdr_solid_swap, v_texcoord).a;
    vec4 solid_swap = blur13withDepth(u_hdr_solid_swap, u_solid_depth, blurDepthThreshold, v_texcoord, frxu_size, vec2(solid_roughness));
    if (solid.a > 0.01) {
        solid = ldr_tonemap(solid + solid_swap);
    }
    float depth_solid = texture2D(u_solid_depth, v_texcoord).r;
    
    vec4 translucent = texture2D(u_hdr_translucent, v_texcoord);
    float translucent_roughness = texture2D(u_hdr_translucent_swap, v_texcoord).a;
    vec4 translucent_swap = blur13withDepth(u_hdr_translucent_swap, u_translucent_depth, blurDepthThreshold, v_texcoord, frxu_size, vec2(translucent_roughness));
    translucent = ldr_tonemap(translucent + translucent_swap * step(0.1, translucent.a));
    float depth_translucent = texture2D(u_translucent_depth, v_texcoord).r;
 
    vec4 c;

    float depth;
    float clouds_depth = texture2D(u_clouds_depth, v_texcoord).r;
    if (clouds_depth <= depth_solid) {
        vec4 clouds = blur13(u_clouds, v_texcoord, frxu_size, vec2(1.0, 0.0));
        clouds.rgb = max(clouds.rgb * 1.4, v_skycolor);
        c.rgb = clouds.rgb * clouds.a + solid.rgb * max(0.0, 1.0 - clouds.a);
        depth = clouds_depth;
    } else {
        c.rgb = solid.rgb;
        depth = depth_solid;
    }

    if (depth < depth_translucent) {
        c.rgb = c.rgb;
    } else {
        c.rgb = translucent.rgb + c.rgb * max(0.0, 1.0 - translucent.a);
    }

    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        vec2 diff = abs(v_texcoord - v_skylightpos);
        diff.x *= v_aspect_adjuster;
        float rainFactor = 1.0 - frx_rainGradient();
        float godlightfactor = frx_smootherstep(0.6, 0.0, length(diff)) * v_godray_intensity * rainFactor;
        float godhack = depth_solid == 1.0 ? 0.5 : 1.0;
        if (godlightfactor > 0.0) {
            vec3 godlight = v_godray_color * godrays(1.0, 0.8, 0.99, 0.016, 50, u_solid_depth, u_clouds_depth, v_skylightpos, v_texcoord);
            c.rgb += godlightfactor * godlight * godhack;
        }
    }
    
    c.a = 1.0; // frx_luminance(c.rgb); // FXAA 3 would need this
    gl_FragData[0] = c;
}


