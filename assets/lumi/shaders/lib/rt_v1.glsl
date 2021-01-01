#include lumi:shaders/lib/coords.glsl

/*******************************************************
 *  lumi:shaders/lib/rt_v1.glsl                        *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

vec2 rt_refine(inout vec3 ray, inout float current_ray_length, inout vec3 ray_view, in float init_ray_length)
{
    vec2 current_uv;
    vec3 current_view;
    while (current_ray_length > init_ray_length) {
        current_uv = coords_uv(ray_view);
        current_view = coords_view(current_uv);
        ray *= 0.5;
        current_ray_length *= 0.5;
        if (ray_view.z > current_view.z) ray_view += ray;
        else ray_view -= ray;
    }
    return current_uv;
}

vec3 rt_march(vec2 start_uv, float init_ray_length, float max_ray_length,
              mat4 projection, mat4 inv_projection, mat4 view, mat4 inv_view,
              sampler2D color_map, sampler2D depth_map, sampler2D normal_map)
{
    vec3 ray_view = coords_view(start_uv, inv_projection, depth_map);
    vec3 unit_march = reflect(normalize(ray_view), normal(start_uv, normal_map));

    vec3 ray = unit_march * init_ray_length;
    float current_ray_length = init_ray_length;
    vec2 current_uv;
    vec3 current_view;
    float delta_z;
    float hitbox_z;
    bool backface;
    // int steps = 0;
    while (current_ray_length < max_ray_length) {
        ray_view += ray;
        current_uv = coords_uv(ray_view);
        current_view = coords_view(current_uv);
        delta_z = current_view.z - ray_view.z;
        hitbox_z = current_ray_length;
        backface = dot(unit_march, normal(current_uv)) > 0;
        if (delta_z > 0 && delta_z < hitbox_z && !backface) {
            return vec3(rt_refine(ray, current_ray_length, ray_view, init_ray_length), 1.0);
        }
        // if (steps > constantSteps) {
        ray *= 2;
        current_ray_length *= 2;
        // }
        // steps ++;
    }
    // Sky reflection
    // if (sky(current_uv) && ray_view.z < 0) return current_uv;
    return vec3(0.0);
}
