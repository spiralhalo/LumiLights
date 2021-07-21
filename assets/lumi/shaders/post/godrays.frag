#include lumi:shaders/post/common/header.glsl

#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/func/tile_noise.glsl
#include lumi:shaders/func/volumetrics.glsl
#include lumi:shaders/lib/godrays.glsl

/*******************************************************
 *  lumi:shaders/post/godrays.frag                     *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_color;
uniform sampler2D u_depth;
uniform sampler2D u_depth_translucent;

uniform sampler2D u_exposure;
uniform sampler2DArrayShadow u_shadow;

uniform sampler2D u_blue_noise;

in float v_godray_intensity;
in vec2 v_invSize;
in vec2 v_skylightpos;

out vec4 fragColor;

void main() {

    float min_depth = texture(u_depth, v_texcoord).r;
    float depth_translucent = texture(u_depth_translucent, v_texcoord).r;

    vec4 c = texture(u_color, v_texcoord);
    float ec = texture(u_exposure, vec2(0.5)).r;

    if (v_godray_intensity > 0.0) {
        vec4 worldPos = frx_inverseViewProjectionMatrix() * vec4(v_texcoord * 2.0 - 1.0, min_depth * 2.0 - 1.0, 1.0);

        worldPos.xyz /= worldPos.w;

        float tileJitter = getRandomFloat(u_blue_noise, v_texcoord, frxu_size);

        vec4 godBeam;
        bool ssFallback = false;

    #ifndef SHADOW_MAP_PRESENT
        ssFallback = !frx_viewFlag(FRX_CAMERA_IN_WATER);
    #endif

        float exposure =  mix(0.5, 0.05, ec);

        if (ssFallback) {
            float scatter = smoothstep(-1.0, 0.5, dot(normalize(worldPos.xyz), frx_skyLightVector()));

            scatter *= max(0.0, dot(frx_cameraView(), frx_skyLightVector()));

            // note: kinda buggy, flickers in some scenes
            godBeam.a = godrays(16, u_depth, tileJitter, v_skylightpos, v_texcoord, frxu_size) * exposure * scatter;
            godBeam.rgb = atmos_hdrCelestialRadiance();
        } else {
            godBeam = celestialLightRays(u_shadow, worldPos.xyz, exposure, tileJitter, depth_translucent, min_depth);
        }

        godBeam = ldr_tonemap(godBeam) * v_godray_intensity;

        c.rgb = c.rgb + godBeam.rgb * godBeam.a;

        // TODO: remove
        // vec2 diff = abs(v_texcoord - v_skylightpos);
        // diff.x *= v_aspect_adjuster;
        // float rainFactor = 1.0 - frx_rainGradient();
        // float godlightfactor = frx_smootherstep(frx_worldFlag(FRX_WORLD_IS_MOONLIT) ? 0.3 : 0.6, 0.0, length(diff)) * v_godray_intensity * rainFactor;
        // float godhack = depth_solid == 1.0 ? 0.5 : 1.0;
        // if (godlightfactor > 0.0) {
        //     vec3 godlight = v_godray_color * godrays(4, u_solid_depth, u_clouds, u_blue_noise, v_skylightpos, v_texcoord, frxu_size);
        //     c += godlightfactor * godlight * godhack;
        // }
    }

#ifdef EXPOSURE_DEBUG
    if (abs(v_texcoord.x - ec) < v_invSize.x * 10.0 && abs(v_texcoord.y - 0.5) < v_invSize.x * 2.0 ) {
        c.g += 1.0;
    }
#endif

    fragColor = c;
}
