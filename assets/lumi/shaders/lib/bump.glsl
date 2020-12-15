const mat4 _bump_tRotm = mat4(
0,  0, -1,  0,
0,  1,  0,  0,
1,  0,  0,  0,
0,  0,  0,  1 );

vec3 _bump_tangentMove(vec3 normal)
{
    vec3 aaNormal = vec3(normal.x + 0.01, 0, normal.z + 0.01);
        aaNormal = normalize(aaNormal);
    return (_bump_tRotm * vec4(aaNormal, 0.0)).xyz;
}

vec3 _bump_bitangentMove(vec3 normal, vec3 tangent)
{
    return cross(normal, tangent);
}

float _bump_height(float raw)
{
    return frx_smootherstep(0, 1, pow(raw, 1 + raw * raw));
}

vec3 bump_normal(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb)
{
    vec3 tangentMove = _bump_tangentMove(normal);
    vec3 bitangentMove = _bump_bitangentMove(normal, tangentMove);

    vec4 texel     = texture2D(tex, uvn, _cv_getFlag(_CV_FLAG_UNMIPPED) * -4.0);
    vec3 origin    = _bump_height(frx_luminance(texel.rgb)) * normal;

         texel     = texture2D(tex, uvt, _cv_getFlag(_CV_FLAG_UNMIPPED) * -4.0);
    vec3 tangent   = tangentMove + _bump_height(frx_luminance(texel.rgb)) * normal - origin;
    
         texel     = texture2D(tex, uvb, _cv_getFlag(_CV_FLAG_UNMIPPED) * -4.0);
    vec3 bitangent = bitangentMove + _bump_height(frx_luminance(texel.rgb)) * normal - origin;

    return normalize(cross(tangent, bitangent));
}
