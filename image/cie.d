module gfm.image.cie;

import gfm.math.smallvector;

// This module performs various color computation and conversions.
// See: http://www.brucelindbloom.com


// Standard illuminants (or reference whites) provide a basis for comparing colors recorded under different lighting.
enum ReferenceWhite
{
    A,
    B,
    C,
    D50, // 5003 K ("horizon" light), very common
    D55,
    D65, // 6504 K (noon light)
    D75,
    E,   // equal-energy radiator
    F2,
    F7,
    F11
};

// A spectrum color holds energy values from 360 to 780 nm, by 5 nm increments
alias SmallVector!(95u, float) SpectralColor;

// Converts spectral color into a XYZ space (parameterized by an illuminant)
vec3f spectralToXYZColor(SpectralColor c, ReferenceWhite illuminant) pure nothrow
{
    SpectralColor c_lit = c * refWhiteToSpectralColor(illuminant);
    return vec3f(dot(CIE_OBS_X2, c_lit),
                    dot(CIE_OBS_Y2, c_lit),
                    dot(CIE_OBS_Z2, c_lit));
}

// Converts from such a XYZ space back to spectral colors
SpectralColor XYZToSpectralColor(vec3f XYZ, ReferenceWhite illuminant) pure nothrow
{
    SpectralColor c_lit = CIE_OBS_X2 * XYZ.x + CIE_OBS_Y2 * XYZ.y + CIE_OBS_Z2 * XYZ.z;
    return c_lit / illuminant;
}

private
{
    // defining spectrum table of CIE 1931 Standard Colorimetric Observer
    // aka 2° observer
    enum SpectralColor CIE_OBS_X2 = SpectralColor
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
        0.000166151f, 0.000117413f, 8.30753e-05f, 5.87065e-05f, 4.15099e-05f,
        2.93533e-05f, 2.06738e-05f, 1.45598e-05f, 1.0254e-05f, 7.22146e-06f,
        5.08587e-06f, 3.58165e-06f, 2.52253e-06f, 1.77651e-06f, 1.25114e-06f
    ]);

    enum SpectralColor CIE_OBS_Y2 = SpectralColor
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
        0.0000106f, 7.4657e-06f, 5.2578e-06f, 3.7029e-06f, 2.6078e-06f,
        1.8366e-06f, 1.2934e-06f, 9.1093e-07f, 6.4153e-07f, 4.5181e-07f
    ]);

    enum SpectralColor CIE_OBS_Z2 = SpectralColor
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
        0.00034f, 0.00024f, 0.00019f, 0.0001f, 5e-05f,
        0.00003f, 0.00002f, 0.00001f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f, 0.0f
    ]);


    vec3f refWhiteToXYZ(ReferenceWhite white) pure nothrow
    {
        final switch(white)
        {
            case ReferenceWhite.A:   return vec3f( 1.0985f, 1.0f, 0.35585f);
            case ReferenceWhite.B:   return vec3f(0.99072f, 1.0f, 0.85223f);
            case ReferenceWhite.C:   return vec3f(0.98074f, 1.0f, 1.18232f);
            case ReferenceWhite.D50: return vec3f(0.96422f, 1.0f, 0.82521f);
            case ReferenceWhite.D55: return vec3f(0.95682f, 1.0f, 0.92149f);
            case ReferenceWhite.D65: return vec3f(0.95047f, 1.0f, 1.08883f);
            case ReferenceWhite.D75: return vec3f(0.94972f, 1.0f, 1.22638f);
            case ReferenceWhite.E:   return vec3f(    1.0f, 1.0f,     1.0f);
            case ReferenceWhite.F2:  return vec3f(0.99186f, 1.0f, 0.67393f);
            case ReferenceWhite.F7:  return vec3f(0.95041f, 1.0f, 1.08747f);
            case ReferenceWhite.F11: return vec3f(1.00962f, 1.0f, 0.64350f);
        }
    }

    SpectralColor refWhiteToSpectralColor(ReferenceWhite illuminant) pure nothrow
    {
        vec3f XYZ = refWhiteToXYZ(illuminant);
        return CIE_OBS_X2 * XYZ.x + CIE_OBS_Y2 * XYZ.y + CIE_OBS_Z2 * XYZ.z;
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
}
