/**
  This module defines RGB <-> HSV conversions.
*/
module gfm.image.hsv;

import std.algorithm,
       std.math;

import gfm.math.vector;

// RGB <-> HSV conversions.

/// Converts a RGB triplet to HSV.
/// Authors: Sam Hocevar 
/// See_also: $(WEB http://lolengine.net/blog/2013/01/13/fast-rgb-to-hsv)
vec3f rgb2hsv(vec3f rgb) pure nothrow
{
    float K = 0.0f;

    if (rgb.y < rgb.z)
    {
        swap(rgb.y, rgb.z);
        K = -1.0f;
    }

    if (rgb.x < rgb.y)
    {
        swap(rgb.x, rgb.y);
        K = -2.0f / 6.0f - K;
    }

    float chroma = rgb.x - (rgb.y < rgb.z ? rgb.y : rgb.z);
    float h = abs(K + (rgb.y - rgb.z) / (6.0f * chroma + 1e-20f));
    float s = chroma / (rgb.x + 1e-20f);
    float v = rgb.x;

    return vec3f(h, s, v);
}

/// Convert a HSV triplet to RGB.
/// Authors: Sam Hocevar.
/// See_also: $(WEB http://lolengine.net/blog/2013/01/13/fast-rgb-to-hsv).
vec3f hsv2rgb(vec3f hsv) pure nothrow
{
    float S = hsv.y;
    float H = hsv.x;
    float V = hsv.z;

    vec3f rgb;

    if ( S == 0.0 ) 
    {
        rgb.x = V;
        rgb.y = V;
        rgb.z = V;
    } 
    else 
    {        
        if (H >= 1.0) 
        {
            H = 0.0;
        } 
        else 
        {
            H = H * 6;
        }
        int I = cast(int)H;
        assert(I >= 0 && I < 6);
        float F = H - I;     /* fractional part */

        float M = V * (1 - S);
        float N = V * (1 - S * F);
        float K = V * (1 - S * (1 - F));

        if (I == 0) { rgb.x = V; rgb.y = K; rgb.z = M; }
        if (I == 1) { rgb.x = N; rgb.y = V; rgb.z = M; }
        if (I == 2) { rgb.x = M; rgb.y = V; rgb.z = K; }
        if (I == 3) { rgb.x = M; rgb.y = N; rgb.z = V; }
        if (I == 4) { rgb.x = K; rgb.y = M; rgb.z = V; }
        if (I == 5) { rgb.x = V; rgb.y = M; rgb.z = N; }
    }
    return rgb;
}
