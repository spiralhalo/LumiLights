#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/lightsource.glsl

/*******************************************************
 *  lumi:shaders/pipeline/post/godrays.vert            *
 *******************************************************/

varying vec3 v_godray_color;
varying vec2 v_skylightpos;
varying float v_godray_intensity;
varying float v_aspect_adjuster;

attribute vec2 in_uv;
const vec3 day_sky = vec3(0.52, 0.69, 1.0);
const vec3 day_fog = vec3(0.75, 0.84375, 1.0);

vec3 calc_sky_color()
{
    vec3 skyColor;
    if (frx_isWorldTheOverworld()) {
        vec3 clear = frx_vanillaClearColor();
        float distanceToFog = distance(normalize(clear), normalize(day_fog));
        skyColor = mix(clear, day_sky, l2_clampScale(0.1, 0.05, distanceToFog));
    } else skyColor = frx_vanillaClearColor();
    vec3 grayScale = vec3(frx_luminance(skyColor));
    skyColor = mix(skyColor, grayScale, frx_playerFlag(FRX_PLAYER_EYE_IN_WATER) ? 1.0 : 0.0);
    return skyColor;
}

void main()
{
    vec4 screen = gl_ProjectionMatrix * vec4(gl_Vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_skycolor = calc_sky_color();
    v_up = frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);

    float moonFactor = frx_worldFlag(FRX_WORLD_IS_MOONLIT) ? frx_moonSize() : 1.0;
    float blindnessFactor = frx_playerHasEffect(FRX_EFFECT_BLINDNESS) ? 0.0 : 1.0;
    vec4 skylight_clip = frx_projectionMatrix() * vec4(frx_normalModelMatrix() * frx_skyLightVector() * 1000, 1.0);
    v_skylightpos = (skylight_clip.xy / skylight_clip.w) * 0.5 + 0.5;
    v_godray_intensity = frx_smootherstep(0.0, 0.1, dot(frx_skyLightVector(), frx_cameraView())) * frx_skyLightStrength() * moonFactor * blindnessFactor;
    v_aspect_adjuster = float(frxu_size.x)/float(frxu_size.y);
    v_godray_color = frx_worldFlag(FRX_WORLD_IS_MOONLIT) ? vec3(0.5) : ldr_sunColor(frx_worldTime());
}
