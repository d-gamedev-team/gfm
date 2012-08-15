module gfm.math.half;

// Half floats
// Implements conversion from ftp://www.fox-toolkit.org/pub/fasthalffloatconversion.pdf
// by Jeroen van der Zijp

import std.traits;
import std.string;


struct half
{
    public
    {
        ushort value;

        // construct from float
        this(float n) pure nothrow
        {
            opAssign!float(n);
        }

        // construct from copy
        this(half h) pure nothrow
        {
            opAssign!half(h);
        }

        string toString() const
        {
            return format("%s", value);
        }

        float toFloat() pure const nothrow
        {
            return halfToFloat(value);
        }

        void opAssign(T)(T other) pure nothrow if (is(T: float))
        {
            value = floatToHalf(other);
        }

        void opAssign(T)(T other) pure nothrow if (is(Unqual!T == half))
        {
            value = other.value;
        }

        half opBinary(string op, T)(T o) pure const nothrow if (is(Unqual!T == half))
        {
            return opBinary!(op, float)(o.toFloat());
        }

        half opBinary(string op, T)(T o) pure const nothrow if (is(T: float))
        {
            half res = void;
            mixin("res.value = floatToHalf(toFloat() " ~ op ~ "o);");
            return res;
        }

        half opOpAssign(string op, T)(T o) pure nothrow
        {
            half res = opBinary!(op, T)(o);
            this = res;
            return res;
        }

        half opUnary(string op)() pure const nothrow if (op == "+" || op == "-")
        {
            static if (op == "-")
            {
                half h = this;
                h.value ^= 0x8000; // flip sign bit
                return h;
            }
            else static if (op == "+")
                return this;
        }


        bool opEquals(T)(T other) pure const if (!is(Unqual!T == half))
        {
            return this == half(other);
        }

        bool opEquals(T)(T other) pure const if (is(Unqual!T == half))
        {
            return value == other.value;
        }
    }
}

// conversions

ushort floatToHalf(float f) pure nothrow
{
    // TODO
    return 0;
}

float halfToFloat(ushort h) pure nothrow
{
    // TODO
    return 0.0f;
}

unittest
{
    half a = 1.0f;
    assert (a == 1);
    half b = 2.0f;
    assert (a * 2 == b);
    half c = a + b;
    half d = (b / a - c) ;
    assert (-d == 1);
}
