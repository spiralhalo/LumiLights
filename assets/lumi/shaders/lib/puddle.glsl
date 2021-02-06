/*******************************************************
 *  lumi:shaders/lib/puddle.glsl                       *
 *******************************************************
 *  Copyright (c) 2021 spiralhalo                      *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

void ww_puddle_pbr(inout vec4 a, inout float roughness, in float light_y, inout vec3 normal, in vec3 worldPos) {
    float rainExposure = smoothstep(0.88, 0.94, light_y) * frx_rainGradient() * smoothstep(0.3, 1.0, normal.y);
    if (rainExposure == 0.0 || frx_modelOriginType() != MODEL_ORIGIN_REGION) return;
    float wet = rainExposure * (0.5 + 0.5 * snoise(0.1 * worldPos.xz));
    float puddly = smoothstep(0.7, 0.8, wet);
    wet = 0.5 * frx_rainGradient() + 0.5 * smoothstep(0.1, 0.7, wet);
    roughness = min(roughness, 1.0 - 0.9 * (wet * 0.5 + 0.5 * puddly));
    a.rgb *= 1.0 - 0.3 * wet;
    vec3 mov = vec3(0.0, frx_renderSeconds() * 6.0, 0.0);
    vec2 jitter = vec2(snoise(worldPos.xyz * 4.0 + mov), snoise(worldPos.zyx * 4.0 + mov));
    normal.xz += jitter * frx_rainGradient() * 0.05;
    normal = normalize(normal);
}

void ww_puddle_phong(inout vec4 a, inout float specPower, in float light_y, in vec3 normal, in vec3 worldPos) {
    if (frx_modelOriginType() != MODEL_ORIGIN_REGION) return;
    float wet = (light_y >= 0.9 ? 1.0 : 0.0)
                   * (0.5 + 0.5 * snoise(0.2 * worldPos.xz))
                   * smoothstep(0.0, 1.0, normal.y)
                   * frx_rainGradient();
    wet = smoothstep(0.0, 0.5, wet);
    specPower = max(specPower, 200 * wet);
    a.rgb *= 1.0 - 0.2 * wet;
}
