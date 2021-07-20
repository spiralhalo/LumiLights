#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/atmosphere.glsl

/*******************************************************
 *  lumi:shaders/post/godrays.vert            *
 *******************************************************/

uniform sampler2D u_color;

out float v_godray_intensity;
out float v_exposure;
out vec2 v_invSize;

void main()
{
    vec4 screen = frxu_frameProjectionMatrix * vec4(in_vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_up = frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);
    v_invSize = 1. / frxu_size;

    atmos_generateAtmosphereModel();

    float dimensionFactor = frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? 1.0 : 0.0;
    float blindnessFactor = frx_playerHasEffect(FRX_EFFECT_BLINDNESS) ? 0.0 : 1.0;
    float notInVoidFactor = l2_clampScale(-1.0, 0.0, frx_cameraPos().y);
    float notInFluidFactor = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? (frx_viewFlag(FRX_CAMERA_IN_WATER) ? 1.0 : 0.0) : 1.0;
    // float brightnessFactor = 1.0 - 0.3 * frx_viewBrightness(); // adjust because godrays are added after tonemap

    v_godray_intensity = 1.0
        * atmosv_celestIntensity
        * dimensionFactor
        * blindnessFactor
        * notInVoidFactor
        * notInFluidFactor
        // * brightnessFactor
        * USER_GODRAYS_INTENSITY;

    v_exposure = 0.0;

    bool doCalcExposure = v_godray_intensity > 0. && !frx_viewFlag(FRX_CAMERA_IN_FLUID);

    // TODO: calc exposure at the end with temporal smoothing to let it stabilize itself
    if (doCalcExposure) {
        int x = 0;
        for (int i = 0; i < 100; i ++) {
            for (int j = 0; j < 100; j ++) {
                x ++;
                vec2 coord = vec2(i, j) / 100.;

                // scale down in center (fovea)
                // coord -= 0.5;

                // vec2 scaling = 0.25 + smoothstep(0.0, 0.5, abs(coord)) * 0.75; // more scaling down the closer to center

                // coord *= scaling;
                // coord += 0.5;

                v_exposure += frx_luminance(texture(u_color, coord).xyz);
            }
        }

        v_exposure /= float(x);

        // a bunch of magic based on experiment
        v_exposure = smoothstep(0.0, 0.5, v_exposure);
        // v_exposure = pow(v_exposure, 0.5);
    }
}
