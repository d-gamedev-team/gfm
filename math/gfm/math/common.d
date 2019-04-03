/++
Common floating point math functions.
Copied from $(HTTP github.com/libmir/mir-core/blob/master/source/mir/math/common.d, mir-core).

License:   $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).
Copyright: Copyright © 2016-, Ilya Yaroshenko
Authors:   Ilya Yaroshenko
+/
module gfm.math.common;

import std.traits : isFloatingPoint;

version(LDC)
{
    nothrow @nogc pure @safe:

    pragma(LDC_intrinsic, "llvm.sqrt.f#")
    ///
    T sqrt(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.sin.f#")
    ///
    T sin(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.cos.f#")
    ///
    T cos(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.powi.f#")
    ///
    T powi(T)(in T val, int power) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.pow.f#")
    ///
    T pow(T)(in T val, in T power) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.exp.f#")
    ///
    T exp(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.log.f#")
    ///
    T log(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.fma.f#")
    ///
    T fma(T)(T vala, T valb, T valc) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.fabs.f#")
    ///
    T fabs(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.floor.f#")
    ///
    T floor(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.exp2.f#")
    ///
    T exp2(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.log10.f#")
    ///
    T log10(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.log2.f#")
    ///
    T log2(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.ceil.f#")
    ///
    T ceil(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.trunc.f#")
    ///
    T trunc(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.rint.f#")
    ///
    T rint(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.nearbyint.f#")
    ///
    T nearbyint(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.copysign.f#")
    ///
    T copysign(T)(in T mag, in T sgn) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.round.f#")
    ///
    T round(T)(in T val) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.fmuladd.f#")
    ///
    T fmuladd(T)(in T vala, in T valb, in T valc) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.minnum.f#")
    ///
    T fmin(T)(in T vala, in T valb) if (isFloatingPoint!T);

    pragma(LDC_intrinsic, "llvm.maxnum.f#")
    ///
    T fmax(T)(in T vala, in T valb) if (isFloatingPoint!T);
}
else version(GNU)
{
    static import gcc.builtins;

    // Calls GCC builtin for either float (suffix "f"), double (no suffix), or real (suffix "l").
    private enum mixinGCCBuiltin(string fun) =
    `static if (T.mant_dig == float.mant_dig) return gcc.builtins.__builtin_`~fun~`f(x);`~
    ` else static if (T.mant_dig == double.mant_dig) return gcc.builtins.__builtin_`~fun~`(x);`~
    ` else static if (T.mant_dig == real.mant_dig) return gcc.builtins.__builtin_`~fun~`l(x);`~
    ` else static assert(0);`;

    // As above but for two-argument function.
    private enum mixinGCCBuiltin2(string fun) =
    `static if (T.mant_dig == float.mant_dig) return gcc.builtins.__builtin_`~fun~`f(x, y);`~
    ` else static if (T.mant_dig == double.mant_dig) return gcc.builtins.__builtin_`~fun~`(x, y);`~
    ` else static if (T.mant_dig == real.mant_dig) return gcc.builtins.__builtin_`~fun~`l(x, y);`~
    ` else static assert(0);`;

    ///
    T sqrt(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`sqrt`); }
    ///
    T sin(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`sin`); }
    ///
    T cos(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`cos`); }
    ///
    T pow(T)(in T x, in T power) if (isFloatingPoint!T) { alias y = power; mixin(mixinGCCBuiltin2!`pow`); }
    ///
    T powi(T)(in T x, int power) if (isFloatingPoint!T) { alias y = power; mixin(mixinGCCBuiltin2!`powi`); }
    ///
    T exp(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`exp`); }
    ///
    T log(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`log`); }
    ///
    T fabs(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`fabs`); }
    ///
    T floor(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`floor`); }
    ///
    T exp2(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`exp2`); }
    ///
    T log10(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`log10`); }
    ///
    T log2(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`log2`); }
    ///
    T ceil(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`ceil`); }
    ///
    T trunc(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`trunc`); }
    ///
    T rint(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`rint`); }
    ///
    T nearbyint(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`nearbyint`); }
    ///
    T copysign(T)(in T mag, in T sgn) if (isFloatingPoint!T) { alias y = sgn; mixin(mixinGCCBuiltin2!`copysign`); }
    ///
    T round(T)(in T x) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin!`round`); }
    ///
    T fmuladd(T)(in T a, in T b, in T c) if (isFloatingPoint!T)
    {
        static if (T.mant_dig == float.mant_dig)
            return gcc.builtins.__builtin_fmaf(a, b, c);
        else static if (T.mant_dig == double.mant_dig)
            return gcc.builtins.__builtin_fma(a, b, c);
        else static if (T.mant_dig == real.mant_dig)
            return gcc.builtins.__builtin_fmal(a, b, c);
        else
            static assert(0);
    }
    unittest { assert(fmuladd!double(2, 3, 4) == 2 * 3 + 4); }
    ///
    T fmin(T)(in T x, in T y) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin2!`fmin`); }
    ///
    T fmax(T)(in T x, in T y) if (isFloatingPoint!T) { mixin(mixinGCCBuiltin2!`fmax`); }
}
else static if (__VERSION__ >= 2082)
{
    static import std.math;
    // Some std.math functions have appropriate return types (float,
    // double, real) without need for a wrapper. We can alias them
    // directly but we leave the templates afterwards for documentation
    // purposes and so explicit template instantiation still works.
    // The aliases will always match before the templates.
    // Note that you cannot put any "static if" around the aliases or
    // compilation will fail due to conflict with the templates!
    alias sqrt = std.math.sqrt;
    alias sin = std.math.sin;
    alias cos = std.math.cos;
    alias exp = std.math.exp;
    alias fabs = std.math.fabs;
    alias floor = std.math.floor;
    alias exp2 = std.math.exp2;
    alias ceil = std.math.ceil;
    alias rint = std.math.rint;

    ///
    T sqrt(T)(in T x) if (isFloatingPoint!T) { return std.math.sqrt(x); }
    ///
    T sin(T)(in T x) if (isFloatingPoint!T) { return std.math.sin(x); }
    ///
    T cos(T)(in T x) if (isFloatingPoint!T) { return std.math.cos(x); }
    ///
    T pow(T)(in T x, in T power) if (isFloatingPoint!T) { return std.math.pow(x, power); }
    ///
    T powi(T)(in T x, int power) if (isFloatingPoint!T) { return std.math.pow(x, power); }
    ///
    T exp(T)(in T x) if (isFloatingPoint!T) { return std.math.exp(x); }
    ///
    T log(T)(in T x) if (isFloatingPoint!T) { return std.math.log(x); }
    ///
    T fabs(T)(in T x) if (isFloatingPoint!T) { return std.math.fabs(x); }
    ///
    T floor(T)(in T x) if (isFloatingPoint!T) { return std.math.floor(x); }
    ///
    T exp2(T)(in T x) if (isFloatingPoint!T) { return std.math.exp2(x); }
    ///
    T log10(T)(in T x) if (isFloatingPoint!T) { return std.math.log10(x); }
    ///
    T log2(T)(in T x) if (isFloatingPoint!T) { return std.math.log2(x); }
    ///
    T ceil(T)(in T x) if (isFloatingPoint!T) { return std.math.ceil(x); }
    ///
    T trunc(T)(in T x) if (isFloatingPoint!T) { return std.math.trunc(x); }
    ///
    T rint(T)(in T x) if (isFloatingPoint!T) { return std.math.rint(x); }
    ///
    T nearbyint(T)(in T x) if (isFloatingPoint!T) { return std.math.nearbyint(x); }
    ///
    T copysign(T)(in T mag, in T sgn) if (isFloatingPoint!T) { return std.math.copysign(mag, sgn); }
    ///
    T round(T)(in T x) if (isFloatingPoint!T) { return std.math.round(x); }
    ///
    T fmuladd(T)(in T a, in T b, in T c) if (isFloatingPoint!T) { return a * b + c; }
    unittest { assert(fmuladd!double(2, 3, 4) == 2 * 3 + 4); }
    ///
    T fmin(T)(in T x, in T y) if (isFloatingPoint!T) { return std.math.fmin(x, y); }
    ///
    T fmax(T)(in T x, in T y) if (isFloatingPoint!T) { return std.math.fmax(x, y); }

    @nogc nothrow pure @safe unittest
    {
        // Check the aliases are correct.
        static assert(is(typeof(sqrt(1.0f)) == float));
        static assert(is(typeof(sin(1.0f)) == float));
        static assert(is(typeof(cos(1.0f)) == float));
        static assert(is(typeof(exp(1.0f)) == float));
        static assert(is(typeof(fabs(1.0f)) == float));
        static assert(is(typeof(floor(1.0f)) == float));
        static assert(is(typeof(exp2(1.0f)) == float));
        static assert(is(typeof(ceil(1.0f)) == float));
        static assert(is(typeof(rint(1.0f)) == float));

        auto x = sqrt!float(2.0f); // Explicit template instantiation still works.
        auto fp = &sqrt!float; // Can still take function address.
    }
}
else // Versions of DMD prior to 2.082
{
    private enum mixinCMath(string fun) =
        `pragma(inline, true);
        static if (is(typeof(() pure => core.stdc.math.`~fun~`f(0.5f))))
        if (!__ctfe)
        {
            static if (T.mant_dig == float.mant_dig)
                return core.stdc.math.`~fun~`f(x);
            else static if (T.mant_dig == double.mant_dig)
                return core.stdc.math.`~fun~`(x);
        }
        return std.math.`~fun~`(x);`;

    static import core.stdc.math;
    static import std.math;

    alias sqrt = std.math.sqrt;

    ///
    T sqrt(T)(in T x) if (isFloatingPoint!T) { return std.math.sqrt(x); }
    ///
    T sin(T)(in T x) if (isFloatingPoint!T) { mixin(mixinCMath!`sin`); }
    ///
    T cos(T)(in T x) if (isFloatingPoint!T) { mixin(mixinCMath!`cos`); }
    ///
    T pow(T)(in T x, in T power) if (isFloatingPoint!T) { return std.math.pow(x, power); }
    ///
    T powi(T)(in T x, int power) if (isFloatingPoint!T) { return std.math.pow(x, power); }
    ///
    T exp(T)(in T x) if (isFloatingPoint!T) { mixin(mixinCMath!`exp`); }
    ///
    T log(T)(in T x) if (isFloatingPoint!T) { return std.math.log(x); }
    ///
    T fabs(T)(in T x) if (isFloatingPoint!T) { mixin(mixinCMath!`fabs`); }
    ///
    T floor(T)(in T x) if (isFloatingPoint!T) { mixin(mixinCMath!`floor`); }
    ///
    T exp2(T)(in T x) if (isFloatingPoint!T) { mixin(mixinCMath!`exp2`); }
    ///
    T log10(T)(in T x) if (isFloatingPoint!T) { return std.math.log10(x); }
    ///
    T log2(T)(in T x) if (isFloatingPoint!T) { return std.math.log2(x); }
    ///
    T ceil(T)(in T x) if (isFloatingPoint!T) { mixin(mixinCMath!`ceil`); }
    ///
    T trunc(T)(in T x) if (isFloatingPoint!T) { return std.math.trunc(x); }
    ///
    T rint(T)(in T x) if (isFloatingPoint!T) { mixin(mixinCMath!`rint`); }
    ///
    T nearbyint(T)(in T x) if (isFloatingPoint!T) { return std.math.nearbyint(x); }
    ///
    T copysign(T)(in T mag, in T sgn) if (isFloatingPoint!T) { return std.math.copysign(mag, sgn); }
    ///
    T round(T)(in T x) if (isFloatingPoint!T) { return std.math.round(x); }
    ///
    T fmuladd(T)(in T a, in T b, in T c) if (isFloatingPoint!T) { return a * b + c; }
    unittest { assert(fmuladd!double(2, 3, 4) == 2 * 3 + 4); }
    ///
    T fmin(T)(in T x, in T y) if (isFloatingPoint!T) { return std.math.fmin(x, y); }
    ///
    T fmax(T)(in T x, in T y) if (isFloatingPoint!T) { return std.math.fmax(x, y); }

    @nogc nothrow pure @safe unittest
    {
        // Check the aliases are correct.
        static assert(is(typeof(sqrt(1.0f)) == float));
        auto x = sqrt!float(2.0f); // Explicit template instantiation still works.
        auto fp = &sqrt!float; // Can still take function address.

        // Check all expected cmath functions are present.
        static assert(is(typeof(sin(1.0f)) == float));
        static assert(is(typeof(cos(1.0f)) == float));
        static assert(is(typeof(exp(1.0f)) == float));
        static assert(is(typeof(fabs(1.0f)) == float));
        static assert(is(typeof(floor(1.0f)) == float));
        static assert(is(typeof(exp2(1.0f)) == float));
        static assert(is(typeof(ceil(1.0f)) == float));
        static assert(is(typeof(rint(1.0f)) == float));
    }
}
