#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/atmosphere.glsl

/*******************************************************
 *  lumi:shaders/post/godrays.vert            *
 *******************************************************/

out vec3 v_godray_color;
out vec2 v_skylightpos;
out float v_godray_intensity;
out float v_aspect_adjuster;
out vec2 v_invSize;

void main()
{
    vec4 screen = frxu_frameProjectionMatrix * vec4(in_vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_up = frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);
    v_invSize = 1. / frxu_size;

    atmos_generateAtmosphereModel();

    float VDotSL = dot(frx_skyLightVector(), frx_cameraView());
    bool isMoonGodray = frx_worldFlag(FRX_WORLD_IS_MOONLIT) ? VDotSL >= 0. : VDotSL < 0.;
    float moonFactor = isMoonGodray ? frx_moonSize() * 0.5 : 1.;
    float dimensionFactor = frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? 1.0 : 0.0;
    float blindnessFactor = frx_playerHasEffect(FRX_EFFECT_BLINDNESS) ? 0.0 : 1.0;
    float cameraViewFactor = frx_smootherstep(0.0, 0.1, abs(VDotSL));
    float notInVoidFactor = l2_clampScale(-1.0, 0.0, frx_cameraPos().y);
    v_godray_intensity = cameraViewFactor
        * moonFactor
        * dimensionFactor
        * blindnessFactor
        * notInVoidFactor
        * USER_GODRAYS_INTENSITY
        * 0.5;

    if (frx_viewFlag(FRX_CAMERA_IN_WATER)) {
        #ifdef WATER_CAUSTICS
            v_godray_intensity = 0.0;
        #else
            v_godray_intensity *= 0.5;
        #endif
    }
    
    #if SKY_MODE == SKY_MODE_LUMI
        vec3 skyLightVector = frx_skyLightVector();
    #else
        // Remove zenith angle tilt until Canvas implements it on vanilla celestial object
        vec3 skyLightVector = normalize(vec3(frx_skyLightVector().xy, 0.0));
    #endif
    vec4 skylight_clip = frx_projectionMatrix() * vec4(frx_normalModelMatrix() * skyLightVector * 1000, 1.0);
    v_skylightpos = (skylight_clip.xy / skylight_clip.w) * 0.5 + 0.5;
    v_aspect_adjuster = float(frxu_size.x)/float(frxu_size.y);
    v_godray_color = frx_worldFlag(FRX_WORLD_IS_MOONLIT) ? vec3(0.5) : ldr_tonemap3(atmos_hdrCelestialRadiance());
}
