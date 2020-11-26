vec3 _bump_tangentMove(vec3 normal)
{
    if(normal. y < 0.5 && normal.y > -0.5){
       // Side
       return (
           mat4(0,  0,  -1, 0,
                0,  1,  0,  0,
                1,  0,  0,  0,
                0,  0,  0,  1
                ) * vec4(normal, 0.0)).xyz;
    } else {
        return (normal.y > 0.5)
        // Top
        ? vec3(1, 0, 0)
        // Bottom
        : vec3(1, 0, 0);
    }
}

vec3 _bump_bitangentMove(vec3 normal, vec3 tangent)
{
    return cross(normal, tangent);
}

float _bump_height(float raw)
{
    return frx_smootherstep(0,1,raw);
}

vec3 bump_normal(sampler2D tex, vec3 normal, vec2 uvn, vec2 uvt, vec2 uvb)
{
    vec3 tangentMove = _bump_tangentMove(normal);
    vec3 bitangentMove = _bump_bitangentMove(normal, tangentMove);

    vec3 origin = _bump_height(frx_luminance(texture2D(tex, uvn, _cv_getFlag(_CV_FLAG_UNMIPPED) * -4.0).rgb))*normal;
    vec3 tangent = tangentMove + _bump_height(frx_luminance(texture2D(tex, uvt, _cv_getFlag(_CV_FLAG_UNMIPPED) * -4.0).rgb))*normal - origin;
    vec3 bitangent = bitangentMove + _bump_height(frx_luminance(texture2D(tex, uvb, _cv_getFlag(_CV_FLAG_UNMIPPED) * -4.0).rgb))*normal - origin;

    return normalize(cross(tangent, bitangent));
}
