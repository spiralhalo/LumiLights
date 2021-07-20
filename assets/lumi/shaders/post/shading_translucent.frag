#include lumi:shaders/post/common/header.glsl

#include lumi:shaders/lib/translucent_layering.glsl

/*******************************************************
 *  lumi:shaders/post/shading_translucent.frag         *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_translucent_color;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_light_translucent;
uniform sampler2D u_normal_translucent;
uniform sampler2D u_material_translucent;
uniform sampler2D u_misc_translucent;

uniform sampler2D u_albedo_translucent;
uniform sampler2D u_alpha_translucent;
uniform sampler2D u_solid_depth;
uniform sampler2D u_light_solid;

uniform sampler2D u_particles_color;
uniform sampler2D u_particles_depth;
uniform sampler2D u_light_particles;

/* More samplers in /common/shading.glsl */

out vec4[3] fragColor;

#include lumi:shaders/post/common/shading.glsl

vec4 ldr_shaded_particle(vec2 uv, sampler2D scolor, sampler2D sdepth, sampler2D slight, out float bloom_out)
{
    vec4 a = texture(scolor, uv);
    if (a.a == 0.) return vec4(0.);

    float depth     = texture(sdepth, uv).r;
    vec3  viewPos   = coords_view(uv, frx_inverseProjectionMatrix(), depth);
    vec3  normal    = normalize(-viewPos) * frx_normalModelMatrix();
    vec4  light     = texture(slight, uv);
    vec3  worldPos  = frx_cameraPos() + (frx_inverseViewMatrix() * vec4(viewPos, 1.0)).xyz;

    bloom_out = light.z;
    pbr_shading(a, bloom_out, viewPos, light.xyy, normal, 1.0, 0.0, 0.0, false, false);

    a.a = min(1.0, a.a);

    if (a.a != 0.0 && depth != 1.0) {
        a = fog(frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? light.y * frx_ambientIntensity() : 1.0, a, viewPos, worldPos, bloom_out);
    }

    return ldr_tonemap(a);
}

vec4 advancedTranslucentShading(out float bloom_out) {
    vec4 light = texture(u_light_translucent, v_texcoord);

    if (light.x == 0.0) {
    // fake TAA that just makes things blurry
    // #ifdef TAA_ENABLED
    //     vec2 taaJitter = taa_jitter(v_invSize);
    // #else
    //     vec2 taaJitter = vec2(0.0);
    // #endif
        vec4 color = texture(u_translucent_color, v_texcoord);

        color.rgb = hdr_fromGamma(color.rgb);

        return unmanaged(color, bloom_out, true);
    }

    vec3 normal =  2.0 * texture(u_normal_translucent, v_texcoord).xyz - 1.0;

    vec4 frontAlbedo = vec4(texture(u_albedo_translucent, v_texcoord).rgb, texture(u_alpha_translucent, v_texcoord).r);

    vec4 frontColor = hdr_shaded_color(
        v_texcoord, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, u_misc_translucent,
        frontAlbedo, vec3(0.0), 1.0, true, true, 1.0, bloom_out);

    vec4 backColor = texture(u_translucent_color, v_texcoord);

    // reverse forward gl_blend with foreground layer (lossy if clipping)
    vec3 unblend = frontAlbedo.rgb * frontAlbedo.a;
#if TRANSLUCENT_LAYERING == TRANSLUCENT_LAYERING_FANCY
    float luminosity2 = calcLuminosity(normal, light.xy, frontAlbedo.a);

    unblend *= luminosity2 * luminosity2;
#endif
    backColor.rgb = max(vec3(0.0), backColor.rgb - unblend);
    // backColor.rgb /= (frontAlbedo.a < 1.0) ? (1.0 - frontAlbedo.a) : 1.0;

#if TRANSLUCENT_LAYERING == TRANSLUCENT_LAYERING_FAST
    // fake shading for back color
    vec2 fakeLight = texture(u_light_solid, v_texcoord).xy;
    fakeLight = fakeLight * 0.25 + texture(u_light_translucent, v_texcoord).xy * 0.75;
    float luminosity = hdr_fromGammaf(max(lightmapRemap(fakeLight.x), lightmapRemap(fakeLight.y) * atmosv_celestIntensity));
    luminosity = luminosity * (1.0 - BASE_AMBIENT_STR) + BASE_AMBIENT_STR;
    backColor.rgb = backColor.rgb * luminosity * 0.5;
#endif

    float finalAlpha = max(frontColor.a, backColor.a);
    float excess = sqrt(finalAlpha - frontColor.a); //hacks

    // gelatin material (tentative name)
    bool isWater = bit_unpack(texture(u_misc_translucent, v_texcoord).z, 7) == 1.;

    if (isWater && !frx_viewFlag(FRX_CAMERA_IN_WATER)) {
        float solidDepth = ldepth(texture(u_solid_depth, v_texcoord).r);
        float transDepth = ldepth(texture(u_translucent_depth, v_texcoord).r);
        float gelatinOpacity = l2_clampScale(0.0, 0.1, solidDepth - transDepth);
        backColor.rgb = mix(backColor.rgb, frontColor.rgb, gelatinOpacity);
        finalAlpha += gelatinOpacity * (1.0 - finalAlpha);
    }

    // blend front and back
    frontColor.rgb = backColor.rgb * (1.0 - frontColor.a) + frontColor.rgb * frontColor.a * (1.0 - excess);
    frontColor.a = finalAlpha;

    return frontColor;
}

void main()
{
    tileJitter = getRandomFloat(u_blue_noise, v_texcoord, frxu_size);

    float bloom1;
    float bloom2;

    vec4 a1 = advancedTranslucentShading(bloom1);
    vec4 a2 = ldr_shaded_particle(v_texcoord, u_particles_color, u_particles_depth, u_light_particles, bloom2);

    fragColor[0] = a1;
    fragColor[1] = a2;
    fragColor[2] = vec4(bloom1 + bloom2, 0.0, 0.0, 1.0);
}


