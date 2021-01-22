#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/fast_gaussian_blur.glsl
#include lumi:shaders/lib/godrays.glsl
#include lumi:shaders/context/global/lighting.glsl

/******************************************************
  lumi:shaders/pipeline/post/composite.frag
******************************************************/

uniform sampler2D u_combine_solid;
uniform sampler2D u_solid_depth;
uniform sampler2D u_combine_translucent;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_clouds;
uniform sampler2D u_clouds_depth;
uniform sampler2D u_weather;
uniform sampler2D u_weather_depth;

varying vec3 v_godray_color;
varying vec2 v_skylightpos;
varying float v_godray_intensity;
varying float v_aspect_adjuster;

#define NUM_LAYERS 4

vec4 color_layers[NUM_LAYERS];
float depth_layers[NUM_LAYERS];
int active_layers = 0;

void try_insert(vec4 color, float depth)
{
    if (color.a == 0.0) {
        return;
    }

    color_layers[active_layers] = color;
    depth_layers[active_layers] = depth;

    int target = active_layers++;
    int probe = target - 1;

    while (target > 0 && depth_layers[target] > depth_layers[probe]) {
        float probeDepth = depth_layers[probe];
        depth_layers[probe] = depth_layers[target];
        depth_layers[target] = probeDepth;

        vec4 probeColor = color_layers[probe];
        color_layers[probe] = color_layers[target];
        color_layers[target] = probeColor;

        target = probe--;
    }
}

vec3 blend(vec3 dst, vec4 src)
{
    return (dst * (1.0 - src.a)) + src.rgb;
}

// arbitrary chosen depth threshold
#define blurDepthThreshold 0.01
void main()
{
    float brightnessMult = mix(1.0, BRIGHT_FINAL_MULT, frx_viewBrightness());

    float depth_solid = texture2D(u_solid_depth, v_texcoord).r;
    vec4 solid = texture2D(u_combine_solid, v_texcoord);
    solid.rgb = ldr_tonemap3(solid.rgb * brightnessMult);
    
    float depth_translucent = texture2D(u_translucent_depth, v_texcoord).r;
    vec4 translucent = texture2D(u_combine_translucent, v_texcoord);
    translucent.rgb = ldr_tonemap3(translucent.rgb * brightnessMult);

    float depth_clouds = texture2D(u_clouds_depth, v_texcoord).r;
    vec4 clouds = blur13(u_clouds, v_texcoord, frxu_size, vec2(1.0, 1.0));
    clouds.rgb = ldr_tonemap3(hdr_gammaAdjust(clouds.rgb) * brightnessMult);

    float depth_weather = texture2D(u_weather_depth, v_texcoord).r;
    vec4 weather = texture2D(u_weather, v_texcoord);
    weather.rgb = ldr_tonemap3(hdr_gammaAdjust(weather.rgb) * brightnessMult);

    color_layers[0] = vec4(solid. rgb, 1.0);
    depth_layers[0] = depth_solid;
    active_layers = 1;

    try_insert(translucent, depth_translucent);
    try_insert(clouds, depth_clouds);
    try_insert(weather, depth_weather);
    
    vec3 c = color_layers[0].rgb;

    for (int i = 1; i < active_layers; ++i) {
        c = blend(c, color_layers[i]);
    }

    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        vec2 diff = abs(v_texcoord - v_skylightpos);
        diff.x *= v_aspect_adjuster;
        float rainFactor = 1.0 - frx_rainGradient();
        float godlightfactor = frx_smootherstep(0.6, 0.0, length(diff)) * v_godray_intensity * rainFactor;
        float godhack = depth_solid == 1.0 ? 0.5 : 1.0;
        if (godlightfactor > 0.0) {
            vec3 godlight = v_godray_color * godrays(1.0, 0.8, 0.99, 0.016, 50, u_solid_depth, u_clouds_depth, v_skylightpos, v_texcoord);
            c += godlightfactor * godlight * godhack;
        }
    }
    
    gl_FragData[0] = vec4(c, 1.0); //frx_luminance(c.rgb)); // FXAA 3 would need this
}


