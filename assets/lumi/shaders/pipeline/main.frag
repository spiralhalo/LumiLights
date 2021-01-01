// Borrowing them for now
#include canvas:shaders/pipeline/fog.glsl

#include frex:shaders/api/world.glsl
#include frex:shaders/api/camera.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include lumi:shaders/internal/context.glsl
#include lumi:shaders/api/pbr_frag.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/internal/varying.glsl
#include lumi:shaders/internal/main_frag.glsl
#include lumi:shaders/internal/lightsource.glsl
#include lumi:shaders/internal/tonemap.glsl
#include lumi:shaders/internal/pbr_shading.glsl
#include lumi:shaders/internal/phong_shading.glsl
#include lumi:shaders/internal/debug_shading.glsl
#include lumi:shaders/internal/skybloom.glsl

/*******************************************************
 *  lumi:shaders/pipeline/main.frag                    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#define hdr_finalMult 1

float l2_ao(frx_FragmentData fragData) {
    #if AO_SHADING_MODE != AO_MODE_NONE
    #if LUMI_LightingMode == LUMI_LightingMode_SystemUnused
        float aoInv = 1.0 - (fragData.ao ? _cvv_ao : 1.0);
        return 1.0 - 0.8 * smoothstep(0.0, 0.3, aoInv * (0.5 + 0.5 * abs((_cvv_normal * frx_normalModelMatrix()).y)));
    #else
        float ao = fragData.ao ? _cvv_ao : 1.0;
        return hdr_gammaAdjustf(min(1.0, ao + fragData.emissivity));
    #endif
    #else
        return 1.0;
    #endif
}

void frx_startPipelineFragment(inout frx_FragmentData fragData)
{
    vec4 a = clamp(fragData.spriteColor * fragData.vertexColor, 0.0, 1.0);
    float bloom = fragData.emissivity; // separate bloom from emissivity
    bool translucent = _cv_getFlag(_CV_FLAG_CUTOUT) == 0.0 && a.a < 0.99;
    if(frx_isGui()){
        #if DIFFUSE_SHADING_MODE != DIFFUSE_MODE_NONE
            if(fragData.diffuse){
                float diffuse = mix(_cvv_diffuse, 1, fragData.emissivity);
                vec3 shading = mix(vec3(0.5, 0.4, 0.8) * diffuse * diffuse, vec3(1.0), diffuse);
                a.rgb *= shading;
            }
        #endif
    } else {
        #if LUMI_DebugMode != LUMI_DebugMode_Disabled
            debug_shading(fragData, a);
        #else
            float userBrightness;
            float brightnessBase = texture2D(frxs_lightmap, vec2(0.03125, 0.03125)).r;
            if(frx_worldHasSkylight()){
                userBrightness = smoothstep(0.053, 0.135, brightnessBase);
            } else {
                // simplified for both nether and the end
                userBrightness = smoothstep(0.15, 0.63, brightnessBase);
                // if(frx_isWorldTheNether()){
                //  userBrightness = smoothstep(0.15/*0.207 no true darkness in nether*/, 0.577, brightnessBase);
                // } else if (frx_isWorldTheEnd(){
                //  userBrightness = smoothstep(0.18/*0.271 no true darkness in the end*/, 0.685, brightnessBase);
                // }
            }
            #ifdef LUMI_PBRX
                pbr_shading(fragData, a, bloom, userBrightness, translucent);
            #else
                phong_shading(fragData, a, bloom, userBrightness, translucent);
            #endif
            a.rgb *= hdr_finalMult;
            tonemap(a);
        #endif
    }

    if (frx_matFlash()) {
        a = a * 0.25 + 0.75;
    } else if (frx_matHurt()) {
        a = vec4(0.25 + a.r * 0.75, a.g * 0.75, a.b * 0.75, a.a);
    }

    // TODO: need a separate fog pass?
	gl_FragData[TARGET_BASECOLOR] = _cp_fog(a);
	gl_FragDepth = gl_FragCoord.z;

    #if TARGET_EMISSIVE > 0
        translucent = translucent && a.a < 0.99;
        gl_FragData[TARGET_EMISSIVE] = vec4(bloom * a.a, 1.0, 0.0, translucent ? step(l2_skyBloom(), bloom) : 1.0);
    #endif

    // Try resetting here
    #ifdef LUMI_PBRX
        pbr_roughness = 1.0;
        pbr_metallic = 0.0;
        pbr_f0 = vec3(-1.0);
    #else
        ww_specular = 0.0;
    #endif
}
