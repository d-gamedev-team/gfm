module gfm.integers.half;

import std.traits,
       std.string;

/**

  16-bits floating point type (Half).
  Implements conversion from ftp://www.fox-toolkit.org/pub/fasthalffloatconversion.pdf
  by Jeroen van der Zijp.

  Supports builtin operations that float support, but computations are performed in 32-bits
  float and converted back.

  Bugs: rounding is not IEEE compliant.

 */
struct half
{
    public
    {
        ushort value;

        /// Construct a half from a float.
        @nogc this(float n) pure nothrow
        {
            opAssign!float(n);
        }

        /// Construct a half from another half.
        @nogc this(half h) pure nothrow
        {
            opAssign!half(h);
        }

        /// Converts to a pretty string.
        string toString() const
        {
            return format("%s", value);
        }

        /// Converts to a float.
        @nogc float toFloat() pure const nothrow
        {
            return halfToFloat(value);
        }

        /// Assign with float.
        @nogc ref half opAssign(T)(T other) pure nothrow if (is(T: float))
        {
            value = floatToHalf(other);
            return this;
        }

        /// Assign with another half.
        @nogc ref half opAssign(T)(T other) pure nothrow if (is(Unqual!T == half))
        {
            value = other.value;
            return this;
        }

        @nogc half opBinary(string op, T)(T o) pure const nothrow if (is(Unqual!T == half))
        {
            return opBinary!(op, float)(o.toFloat());
        }

        @nogc half opBinary(string op, T)(T o) pure const nothrow if (is(T: float))
        {
            half res = void;
            mixin("res.value = floatToHalf(toFloat() " ~ op ~ "o);");
            return res;
        }

        @nogc ref half opOpAssign(string op, T)(T o) pure nothrow
        {
            half res = opBinary!(op, T)(o);
            this = res;
            return this;
        }

        @nogc half opUnary(string op)() pure const nothrow if (op == "+" || op == "-")
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


        @nogc bool opEquals(T)(T other) pure const nothrow if (!is(Unqual!T == half))
        {
            return this == half(other);
        }

        @nogc bool opEquals(T)(T other) pure const nothrow if (is(Unqual!T == half))
        {
            return value == other.value;
        }
    }
}

static assert (half.sizeof == 2);


// Conversions.

private union uint_float
{
    float f;
    uint ui;
}

/// Converts from float to half.
@nogc ushort floatToHalf(float f) pure nothrow
{
    uint_float uf = void;
    uf.f = f;
    uint idx = (uf.ui >> 23) & 0x1ff;
    return cast(ushort)(basetable[idx] + ((uf.ui & 0x007fffff) >> shifttable[idx]));
}

/// Converts from half to float.
@nogc float halfToFloat(ushort h) pure nothrow
{
    uint_float uf = void;
    uf.ui = mantissatable[offsettable[h>>10] + (h & 0x3ff)] + exponenttable[h>>10];
    return uf.f;
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

private
{
    // build tables through CTFE

    static immutable uint[2048] mantissatable =
    (){
        uint[2048] t;
        t[0] = 0;
        for (uint i = 1; i < 1024; ++i)
        {
            uint m = i << 13;            // zero pad mantissa bits
            uint e = 0;                  // zero exponent
            while(0 == (m & 0x00800000)) // while not normalized
            {
                e -= 0x00800000;         // decrement exponent (1<<23)
                m = m << 1;              // shift mantissa
            }

            m = m & (~0x00800000);       // clear leading 1 bit
            e += 0x38800000;             // adjust bias ((127-14)<<23)
            t[i] = m | e;                // return combined number
        }

        for (uint i = 1024; i < 2047; ++i)
            t[i] = 0x38000000 + ((i-1024) << 13);

        return t;
    }();

    static immutable uint[64] exponenttable =
    (){
        uint[64] t;
        t[0] = 0;
        for (uint i = 1; i <= 30; ++i)
            t[i] = i << 23;
        t[31] = 0x47800000;
        t[32] = 0x80000000;
        for (uint i = 33; i <= 62; ++i)
            t[i] = 0x80000000 + ((i - 32) << 23);

        t[63] = 0xC7800000;
        return t;
    }();

    static immutable ushort[64] offsettable =
    (){
        ushort[64] t;
        t[] = 1024;
        t[0] = t[32] = 0;
        return t;
    }();

    static immutable ushort[512] basetable =
    (){
        ushort[512] t;
        for (uint i = 0; i < 256; ++i)
        {
            int e = cast(int)i - 127;
            if (e < -24)
            {
                t[i | 0x000] = 0x0000;
                t[i | 0x100] = 0x8000;
            }
            else if(e < -14)
            {
                t[i | 0x000] = (0x0400 >> (-e - 14));
                t[i | 0x100] = (0x0400 >> (-e - 14)) | 0x8000;
            }
            else if(e <= 15)
            {
                t[i | 0x000] = cast(ushort)((e + 15) << 10);
                t[i | 0x100] = cast(ushort)((e + 15) << 10) | 0x8000;
            }
            else
            {
                t[i | 0x000] = 0x7C00;
                t[i | 0x100] = 0xFC00;
            }
        }
        return t;
    }();

    static immutable ubyte[512] shifttable =
    (){
        ubyte[512] t;

        for (uint i = 0; i < 256; ++i)
        {
            int e = cast(int)i - 127;
            if (e < -24)
            {
                t[i | 0x000] = 24;
                t[i | 0x100] = 24;
            }
            else if(e < -14)
            {
                t[i | 0x000] = cast(ubyte)(-e - 1);
                t[i | 0x100] = cast(ubyte)(-e - 1);
            }
            else if(e <= 15)
            {
                t[i | 0x000]=13;
                t[i | 0x100]=13;
            }
            else if (e < 128)
            {
                t[i | 0x000]=24;
                t[i | 0x100]=24;
            }
            else
            {
                t[i | 0x000] = 13;
                t[i | 0x100] = 13;
            }
        }

        return t;
    }();
}
