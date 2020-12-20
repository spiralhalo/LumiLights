/*******************************************************
 *  lumi:shaders/internal/phong_shading.glsl           *
 *******************************************************
 *  Copyright (c) 2020 spiralhalo and Contributors.    *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

void phong_shading(inout vec4 a, inout bloom, float userBrightness) {
    a.rgb = hdr_gammaAdjust(a.rgb);

    float ao = l2_ao(fragData);
    // If diffuse is disabled (e.g. grass) then the normal points up by default
    vec3 diffuseNormal = fragData.diffuse?fragData.vertexNormal * frx_normalModelMatrix():vec3(0,1,0);
#if HANDHELD_LIGHT_RADIUS == 0
    vec3 held = vec3(0);
#else
    vec3 held = pbr_handHeldRadiance();
#endif
    vec3 block = l2_blockRadiance(fragData.light.x, userBrightness);
    vec3 sun = l2_sunLight(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), frx_rainGradient(), diffuseNormal);
    vec3 moon = l2_moonLight(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), diffuseNormal);
    vec3 skyAmbient = l2_skyAmbient(fragData.light.y, frx_worldTime(), frx_ambientIntensity());
    vec3 emissive = l2_emissiveRadiance(fragData.emissivity);
    vec3 skyless = l2_skylessLight(diffuseNormal, userBrightness);
    vec3 baseAmbient = l2_baseAmbient(userBrightness);

    vec3 light = baseAmbient + block + moon + skyAmbient + sun + skyless;
    light *= ao; // AO is supposed to be applied to ambient only, but things look better with AO on everything except for emissive light
    light += emissive;
    
    vec3 specular = vec3(0.0);
    if (ww_specular > 0) {
        vec3 specularNormal = fragData.vertexNormal * frx_normalModelMatrix();

        float skyAccess = smoothstep(0.89, 1.0, fragData.light.y);

        vec3 fragPos = frx_var0.xyz;
        vec3 cameraPos = frx_var1.xyz;
        vec3 sunDir = l2_vanillaSunDir(frx_worldTime(), 0);
        vec3 sun = l2_sunLight(fragData.light.y, frx_worldTime(), frx_ambientIntensity(), frx_rainGradient(), sunDir);

        float specularAmount = l2_specular(frx_worldTime(), specularNormal, fragPos, cameraPos, ww_specular);

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
