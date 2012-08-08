module gfm.color.cie;

import gfm.math.smallvector;

// See: http://www.brucelindbloom.com

// A spectrum color holds energy values from 360 to 780 nm, by 5 nm increments
alias SmallVector!(95u, float) SpectralColor;

vec3f spectrumToXYZColor(SpectralColor c, SpectralColor illuminant) pure nothrow
{
    SpectralColor c_lit = c * illuminant;
    return vec3f(dot(CIE_XBAR, c_lit), dot(CIE_YBAR, c_lit), dot(CIE_ZBAR, c_lit));
}

// return a (X, Y, Z) triplet from a spectral color
SpectralColor XYZToSpectrumColor(vec3f XYZ, SpectralColor illuminant) pure nothrow
{
    SpectralColor c_lit = CIE_XBAR * XYZ.x + CIE_YBAR * XYZ.y + CIE_ZBAR * XYZ.z;
    return c_lit / illuminant;
}

// return a (x, y, Y) triplet from a (X, Y, Z) triplet
// TODO: bring ref white into account for black
vec3f XYZToxyYColor(vec3f XYZ)
{
    assert(XYZ.x >= 0 && XYZ.x <= 1 
        && XYZ.y >= 0 && XYZ.y <= 1
        && XYZ.z >= 0 && XYZ.z <= 1);
    vec3f res = void;
    res.x = XYZ.x / (XYZ.x + XYZ.y + XYZ.z);
    res.y = XYZ.y / (XYZ.x + XYZ.y + XYZ.z);
    res.z = XYZ.y;
    return res;
}

// return a (X, Y, Z) triplet from a (x, y, Y) triplet
vec3f xyYToXYZColor(vec3f xyY)
{
    assert(xyY.x >= 0 && xyY.x <= 1 
        && xyY.y >= 0 && xyY.y <= 1
        && xyY.z >= 0 && xyY.z <= 1);
    if (xyY == 0)
    {
        return vec3f(0.0f);
    }
    else
    {
        vec3f res = void;
        res.x = xyY.x * xyY.z / xyY.y;
        res.y = xyY.z;
        res.z = (1 - xyY.x - xyY.y) * xyY.z / xyY.y;
        return res;
    }
}

// defining spectrum table of CIE 1931 Standard Colorimetric Observer
private enum SpectralColor CIE_XBAR = SpectralColor
([
    0.0001299f, 0.0002321f, 0.0004149f, 0.0007416f, 0.001368f, 
    0.002236f, 0.004243f, 0.00765f, 0.01431f, 0.02319f, 
    0.04351f, 0.07763f, 0.13438f, 0.21477f, 0.2839f, 
    0.3285f, 0.34828f, 0.34806f, 0.3362f, 0.3187f, 
    0.2908f, 0.2511f, 0.19536f, 0.1421f, 0.09564f, 
    0.05795001f, 0.03201f, 0.0147f, 0.0049f, 0.0024f, 
    0.0093f, 0.0291f, 0.06327f, 0.1096f, 0.1655f, 
    0.2257499f, 0.2904f, 0.3597f, 0.4334499f, 0.5120501f, 
    0.5945f, 0.6784f, 0.7621f, 0.8425f, 0.9163f, 
    0.9786f, 1.0263f, 1.0567f, 1.0622f, 1.0456f, 
    1.0026f, 0.9384f, 0.8544499f, 0.7514f, 0.6424f, 
    0.5419f, 0.4479f, 0.3608f, 0.2835f, 0.2187f, 
    0.1649f, 0.1212f, 0.0874f, 0.0636f, 0.04677f, 
    0.0329f, 0.0227f, 0.01584f, 0.01135916f, 0.008110916f, 
    0.005790346f, 0.004106457f, 0.002899327f, 0.00204919f, 0.001439971f, 
    0.000999949f, 0.000690079f, 0.000476021f, 0.000332301f, 0.000234826f, 
    0.000166151f, 0.000117413f, 8.30753E-05f, 5.87065E-05f, 4.15099E-05f, 
    2.93533E-05f, 2.06738E-05f, 1.45598E-05f, 1.0254E-05f, 7.22146E-06f, 
    5.08587E-06f, 3.58165E-06f, 2.52253E-06f, 1.77651E-06f, 1.25114E-06f
]);

private enum SpectralColor CIE_YBAR = SpectralColor
([
    0.000003917f, 0.000006965f, 0.00001239f, 0.00002202f, 0.000039f, 
    0.000064f, 0.00012f, 0.000217f, 0.000396f, 0.00064f, 
    0.00121f, 0.00218f, 0.004f, 0.0073f, 0.0116f, 
    0.01684f, 0.023f, 0.0298f, 0.038f, 0.048f, 
    0.06f, 0.0739f, 0.09098f, 0.1126f, 0.13902f, 
    0.1693f, 0.20802f, 0.2586f, 0.323f, 0.4073f, 
    0.503f, 0.6082f, 0.71f, 0.7932f, 0.862f, 
    0.9148501f, 0.954f, 0.9803f, 0.9949501f, 1.0f, 
    0.995f, 0.9786f, 0.952f, 0.9154f, 0.87f, 
    0.8163f, 0.757f, 0.6949f, 0.631f, 0.5668f, 
    0.503f, 0.4412f, 0.381f, 0.321f, 0.265f, 
    0.217f, 0.175f, 0.1382f, 0.107f, 0.0816f, 
    0.061f, 0.04458f, 0.032f, 0.0232f, 0.017f, 
    0.01192f, 0.00821f, 0.005723f, 0.004102f, 0.002929f, 
    0.002091f, 0.001484f, 0.001047f, 0.00074f, 0.00052f, 
    0.0003611f, 0.0002492f, 0.0001719f, 0.00012f, 0.0000848f, 
    0.00006f, 0.0000424f, 0.00003f, 0.0000212f, 0.00001499f, 
    0.0000106f, 7.4657E-06f, 5.2578E-06f, 3.7029E-06f, 2.6078E-06f, 
    1.8366E-06f, 1.2934E-06f, 9.1093E-07f, 6.4153E-07f, 4.5181E-07f
]);

private enum SpectralColor CIE_ZBAR = SpectralColor
([
    0.0006061f, 0.001086f, 0.001946f, 0.003486f, 0.006450001f,
    0.01054999f, 0.02005001f, 0.03621f, 0.06785001f, 0.1102f,
    0.2074f, 0.3713f, 0.6456f, 1.0390501f, 1.3856f,
    1.62296f, 1.74706f, 1.7826f, 1.77211f, 1.7441f,
    1.6692f, 1.5281f, 1.28764f, 1.0419f, 0.8129501f,
    0.6162f, 0.46518f, 0.3533f, 0.272f, 0.2123f,
    0.1582f, 0.1117f, 0.07824999f, 0.05725001f, 0.04216f,
    0.02984f, 0.0203f, 0.0134f, 0.008749999f, 0.005749999f,
    0.0039f, 0.002749999f, 0.0021f, 0.0018f, 0.001650001f,
    0.0014f, 0.0011f, 0.001f, 0.0008f, 0.0006f, 
    0.00034f, 0.00024f, 0.00019f, 0.0001f, 5E-05f,
    0.00003f, 0.00002f, 0.00001f, 0.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 
    0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 
    0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 
    0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 
    0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 
    0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 
    0.0f, 0.0f, 0.0f, 0.0f, 0.0f
]);

enum SpectralColor D50 = 0.34567f * CIE_XBAR + 0.35850f * CIE_YBAR + CIE_ZBAR;
enum SpectralColor D65 = 0.31271f * CIE_XBAR + 0.32902f * CIE_YBAR + CIE_ZBAR;