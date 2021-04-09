#include lumi:shaders/post/common/header.glsl

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

uniform sampler2D u_particles_color;
uniform sampler2D u_particles_depth;
uniform sampler2D u_light_particles;

uniform sampler2D u_glint;
uniform sampler2DArrayShadow u_shadow;

#include lumi:shaders/post/common/shading.glsl

vec4 ldr_shaded_particle(vec2 uv, sampler2D scolor, sampler2D sdepth, sampler2D slight, out float bloom_out)
{
    vec4 a = texture2D(scolor, uv);

    float depth     = texture2D(sdepth, uv).r;
    vec3  viewPos   = coords_view(uv, frx_inverseProjectionMatrix(), depth);
    vec3  normal    = normalize(-viewPos) * frx_normalModelMatrix();
    vec4  light     = texture2D(slight, uv);
    vec3  worldPos  = frx_cameraPos() + (frx_inverseViewMatrix() * vec4(viewPos, 1.0)).xyz;

    bloom_out = light.z;
    pbr_shading(a, bloom_out, viewPos, light.xyy, normal, 1.0, 0.0, 0.0, false, false);

    a.a = min(1.0, a.a);

    if (a.a != 0.0 && depth != 1.0) {
        a = fog(frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? light.y * frx_ambientIntensity() : 1.0, a, viewPos, worldPos, bloom_out);
    }

    return ldr_tonemap(a);
}

void main()
{
    tileJitter = tile_noise_1d(v_texcoord, frxu_size, 3);
    float bloom1;
    float bloom2;
    vec4 a1 = hdr_shaded_color(v_texcoord, u_translucent_color, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, u_misc_translucent, 1.0, true, 1.0, bloom1);
    vec4 a2 = ldr_shaded_particle(v_texcoord, u_particles_color, u_particles_depth, u_light_particles, bloom2);
    gl_FragData[0] = a1;
    gl_FragData[1] = a2;
    gl_FragData[2] = vec4(bloom1 + bloom2, 0.0, 0.0, 1.0);
}


