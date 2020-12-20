/*******************************************************
 *  lumi:shaders/internal/phong_shading.glsl           *
 *******************************************************
 *  Copyright (c) 2020 spiralhalo and Contributors.    *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

float ww_specular;

float l2_specular(float time, vec3 aNormal, vec3 viewDir, float power)
{
    // calculate sun position (0 zWobble to make it look accurate with vanilla sun visuals)
    vec3 sunDir = l2_vanillaSunDir(time, 0);

    // calculate the specular light
    return pow(max(0.0, dot(reflect(-sunDir, aNormal), viewDir)), power);
}

void phong_shading(inout vec4 a, inout bloom, float userBrightness) {
    a.rgb = hdr_gammaAdjust(a.rgb);

    float ao = l2_ao(fragData);
    // If diffuse is disabled (e.g. grass) then the normal points up by default
    vec3 diffuseNormal = fragData.diffuse?fragData.vertexNormal * frx_normalModelMatrix():vec3(0,1,0);
    vec3 sunDot = max(0.0, dot(l2_vanillaSunDir(time, hdr_zWobbleDefault), diffuseNormal));
    vec3 moonDot = max(0.0, dot(pbr_moonDir(frx_worldTime());, diffuseNormal));
#if HANDHELD_LIGHT_RADIUS == 0
    vec3 held = vec3(0);
#else
    vec3 held = l2_handHeldRadiance();
#endif
    vec3 block = l2_blockRadiance(fragData.light.x, userBrightness);
    vec3 sun = l2_sunRadiance(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), frx_rainGradient(), diffuseNormal) * sunDot;
    vec3 moon = l2_moonRadiance(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), diffuseNormal) * moonDot;
    vec3 skyAmbient = l2_skyAmbient(fragData.light.y, frx_worldTime(), frx_ambientIntensity());
    vec3 emissive = l2_emissiveRadiance(fragData.emissivity);
    vec3 skyless = l2_skylessRadiance(diffuseNormal, userBrightness);
    vec3 baseAmbient = l2_baseAmbient(userBrightness);

    vec3 light = baseAmbient + held + block + moon + skyAmbient + sun + skyless;
    light *= ao; // AO is supposed to be applied to ambient only, but things look better with AO on everything except for emissive light
    light += emissive;
    
    vec3 specular = vec3(0.0);
    if (ww_specular > 0) {
        vec3 specularNormal = fragData.vertexNormal * frx_normalModelMatrix();

        float skyAccess = smoothstep(0.89, 1.0, fragData.light.y);

        vec3 sunDir = l2_vanillaSunDir(frx_worldTime(), 0);
        vec3 viewDir = normalize(-l2_viewPos) * frx_normalModelMatrix() * gl_NormalMatrix;
        vec3 sun = l2_sunRadiance(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), frx_rainGradient(), sunDir);

        float specularAmount = l2_specular(frx_worldTime(), specularNormal, viewDir, ww_specular);

        specular = sun * specularAmount * skyAccess;

        float specularLuminance = frx_luminance(specular);
        a.a += specularLuminance;
        bloom += specularLuminance;
    }

    a.rgb *= light;
    a.rgb += specular;

    a.rgb *= hdr_finalMult;
    tonemap(a);
}
