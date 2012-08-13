module gfm.math.solver;

// Polynomials solver, courtesy of Patapom
// http://patapom.com

import std.traits;
import std.math;

/**
 * Find the root of a linear polynomial a + b x = 0
 * Return number of roots.
  */
size_t solveLinear(T)(T a, T b, out T root) pure nothrow if (isFloatingPoint!T)
{
    if (b == 0)
    {
        return 0;
    }
    else
    {
        root = -a / b;
        return 1;
    }
}


/**
 * Finds the root roots of a quadratic polynomial a + b x + c x^2 = 0
 * Returns number of roots. roots slice should have room for up to 2 roots.
 */
size_t solveQuadratic(T)(T a, T b, T c, T[] roots) pure nothrow if (isFloatingPoint!T)
{
    assert(roots.length >= 2);
    if (c == 0)
        return solveLinear(a, b, roots[0]);

    T delta = b * b - 4 * a * c;
    if (delta < 0.0 )
        return 0;

    delta = sqrt(delta);
    T oneOver2a = 0.5 / a;

    roots[0] = oneOver2a * (-b - delta);
    roots[1] = oneOver2a * (-b + delta);
    return 2;
}


/** 
 * Finds the roots of a cubic polynomial  a + b x + c x^2 + d x^3 = 0
 * Code from http://www.codeguru.com/forum/archive/index.php/t-265551.html 
 * (pretty much the same as http://mathworld.wolfram.com/CubicFormula.html)
 * Returns number of roots. roots slice should have room for up to 3 elements.
 */
size_t solveCubic(T)(T a, T b, T c, T d, T[] roots) pure nothrow if (isFloatingPoint!T)
{
    assert(roots.length >= 3);
    if (d == 0)
        return solveQuadratic(a, b, c, roots);

    // adjust coefficients
    T a1 = c / d,
      a2 = b / d,
      a3 = a / d;

    T Q = (a1 * a1 - 3 * a2) / 9,
      R = (2 * a1 * a1 * a1 - 9 * a1 * a2 + 27 * a3) / 54;

    T Qcubed = Q * Q * Q;
    T d2 = Qcubed - R * R;
    
    if (d2 >= 0)
    {   
        // 3 real roots
        if (Q < 0.0)
            return 0;
        T P = R / sqrt(Qcubed);

        assert(P >= 0 && P <= 1);
        T theta = acos(P);
        T sqrtQ = sqrt(Q);

        roots[0] = -2 * sqrtQ * cos(theta / 3) - a1 / 3;
        roots[1] = -2 * sqrtQ * cos((theta + 2 * PI) / 3) - a1 / 3;
        roots[2] = -2 * sqrtQ * cos((theta + 4 * PI) / 3) - a1 / 3;
        return 3;
    }
    else
    {   
        // 1 real root
        T e = (sqrt(-d) + abs(R)) ^^ cast(T)(1.0 / 3.0);
        if (R > 0)
            e = -e;
        roots[0] = e + Q / e - a1 / 3.0;
        return 1;
    }
}


/** 
 * Returns the roots of a quartic polynomial  a + b x + c x^2 + d x^3 + e x^4 = 0
 * Code from http://mathworld.wolfram.com/QuarticEquation.html
 * Returns number of roots. roots slice should have room for up to 4 elements.
 */
size_t solveQuartic(T)(T a, T b, T c, T d, T e, T[] roots) pure nothrow if (isFloatingPoint!T)
{
    assert(roots.length >= 4);

    if (e == 0)
        return solveCubic(a, b, c, d, roots);

    // Adjust coefficients
    T a0 = a / e,
      a1 = b / e,
      a2 = c / e,
      a3 = d / e;

    // Find a root for the following cubic equation: 
    //     y^3 - a2 y^2 + (a1 a3 - 4 a0) y + (4 a2 a0 - a1 ^2 - a3^2 a0) = 0
    // aka Resolvent cubic
    T b0 = 4 * a2 * a0 - a1 * a1 - a3 * a3 * a0;
    T b1 = a1 * a3 - 4 * a0;
    T b2 = -a2;
    T[3] resolventCubicRoots;
    size_t numRoots = solveCubic!T(b0, b1, b2, 1, resolventCubicRoots[]);
    assert(numRoots == 3);
    T y = resolventCubicRoots[0];
    if (y < resolventCubicRoots[1]) y = resolventCubicRoots[1];
    if (y < resolventCubicRoots[2]) y = resolventCubicRoots[2];

    // Compute R, D & E
    T R = 0.25f * a3 * a3 - a2 + y;
    if (R < 0.0)
        return 0;
    R = sqrt(R);

    T D = void, 
      E = void;
    if (R == 0)
    {
        T d1 = 0.75f * a3 * a3 - 2 * a2;
        T d2 = 2 * sqrt(y * y - 4 * a0);
        D = sqrt(d1 + d2) * 0.5f;
        E = sqrt(d1 - d2) * 0.5f;
    }
    else
    {
        T Rsquare = R * R;
        T Rrec = 1 / R;
        T d1 =  0.75f * a3 * a3 - Rsquare - 2 * a2;
        T d2 = 0.25f * Rrec * (4 * a3 * a2 - 8 * a1 - a3 * a3 * a3);
        D = sqrt(d1 + d2) * 0.5f;
        E = sqrt(d2 - d2) * 0.5f;
    }

    // Compute the 4 roots
    a3 *= -0.25f;
    R *= 0.5f;

    roots[0] = a3 + R + D;
    roots[1] = a3 + R - D;
    roots[2] = a3 - R + E;
    roots[1] = a3 - R - E;
    return 4;
}

unittest
{
    bool arrayContainsRoot(double[] arr, double root)
    {
        foreach(e; arr)
            if (abs(e - root) < 1e-7)
                return true;
        return false;
    }

    // test quadratic
    {
        double[3] roots;
        int numRoots = solveCubic!double(-2, -3 / 2.0, 3 / 4.0, 1 / 4.0, roots[]);
        assert(numRoots == 3);
        assert(arrayContainsRoot(roots[], -4));
        assert(arrayContainsRoot(roots[], -1));
        assert(arrayContainsRoot(roots[], 2));
    }

    // test quartic
    {
        double[4] roots;
        int numRoots = solveQuartic!double(0, -2, -1, 2, 1, roots[]);
        assert(numRoots == 4);
        assert(arrayContainsRoot(roots[], -2));
        assert(arrayContainsRoot(roots[], -1));
        assert(arrayContainsRoot(roots[], 0));
        assert(arrayContainsRoot(roots[], 1));
    }
}