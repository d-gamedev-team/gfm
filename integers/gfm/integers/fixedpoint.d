module gfm.integers.fixedpoint;

import std.traits;

import gfm.integers.wideint;

/**
    M.N fixed point integer.
    Only signed integers are supported.
    Only supports basic arithmetic.
    If M + N > 32, then wide integers are used and this will likely be slow.

    Params:
        M = number of bits before the mark, M > 0
        N = number of bits after the mark, N > 0

    Bugs: No proper rounding.
 */
struct FixedPoint(int M, int N)
{
    static assert(M > 0);       // M == 0 is unsupported
    static assert(N > 0);       // N == 0 also unsupported, but in this case you can use wideint!M

    public
    {
        alias TypeNeeded!(N + M) value_t;

        /// Construct with an assignable value.
        @nogc this(U)(U x) pure nothrow
        {
            opAssign!U(x);
        }

        /// Construct with an assignable value.
        @nogc ref FixedPoint opAssign(U)(U x) pure nothrow if (is(U: FixedPoint))
        {
            value = x.value;
            return this;
        }

        @nogc ref FixedPoint opAssign(U)(U x) pure nothrow if (isIntegral!U)
        {
            value = x * ONE;                // exact
            return this;
        }

        @nogc ref FixedPoint opAssign(U)(U x) pure nothrow if (isFloatingPoint!U)
        {
            value = cast(value_t)(x * ONE); // truncation
            return this;
        }

        // casting to float
        @nogc U opCast(U)() pure const nothrow if (isFloatingPoint!U)
        {
            return cast(U)(value) / ONE;
        }

        // casting to integer (truncation)
        @nogc U opCast(U)() pure const nothrow if (isIntegral!U)
        {
            return cast(U)(value) >> N;
        }

        @nogc ref FixedPoint opOpAssign(string op, U)(U x) pure nothrow if (is(U: FixedPoint))
        {
            static if (op == "+")
            {
                value += x.value;
                return this;
            }
            else static if (op == "-")
            {
                value -= x.value;
                return this;
            }
            else static if (op == "*")
            {
                alias TypeNeeded!(2 * N + M) inter_t;
                value = cast(value_t)((cast(inter_t)value * x.value) >> N);
                return this;
            }
            else static if (op == "/")
            {
                alias TypeNeeded!(2 * N + M) inter_t;
                value = cast(value_t)((cast(inter_t)value << N) / x.value);
                //             ^ possible overflow when downcasting
                return this;
            }
            else
            {
                static assert(false, "FixedPoint does not support operator " ~ op);
            }
        }

        @nogc ref FixedPoint opOpAssign(string op, U)(U x) pure nothrow if (isConvertible!U)
        {
            FixedPoint conv = x;
            return opOpAssign!op(conv);
        }

        @nogc FixedPoint opBinary(string op, U)(U x) pure const nothrow if (is(U: FixedPoint) || (isConvertible!U))
        {
            FixedPoint temp = this;
            return temp.opOpAssign!op(x);
        }

        @nogc FixedPoint opBinaryRight(string op, U)(U x) pure const nothrow if (isConvertible!U)
        {
            FixedPoint temp = x;
            return temp.opOpAssign!op(this);
        }

        @nogc bool opEquals(U)(U other) pure const nothrow if (is(U : FixedPoint))
        {
            return value == other.value;
        }

        @nogc bool opEquals(U)(U other) pure const nothrow if (isConvertible!U)
        {
            FixedPoint conv = other;
            return opEquals(conv);
        }

        @nogc int opCmp(in FixedPoint other) pure const nothrow
        {
            if (value > other.value)
                return 1;
            else if (value < other.value)
                return -1;
            else
                return 0;
        }

        @nogc FixedPoint opUnary(string op)() pure const nothrow if (op == "+")
        {
            return this;
        }

        @nogc FixedPoint opUnary(string op)() pure const nothrow if (op == "-")
        {
            FixedPoint res = void;
            res.value = -value;
            return res;
        }

        value_t value;
    }

    private
    {
        enum value_t ONE = cast(value_t)1 << N;
        enum value_t HALF = ONE >>> 1;
        enum value_t LOW_MASK = ONE - 1;
        enum value_t HIGH_MASK = ~cast(int)(LOW_MASK);
        static assert((ONE & LOW_MASK) == 0);

        // define types that can be converted to FixedPoint, but are not FixedPoint
        template isConvertible(T)
        {
            enum bool isConvertible = (!is(T : FixedPoint))
            && is(typeof(
                {
                    T x;
                    FixedPoint v = x;
                }()));
        }
    }
}

// Selects a signed integer type suitable to hold numBits bits.
private template TypeNeeded(int numBits)
{
    static if (numBits <= 8)
    {
        alias byte TypeNeeded;
    }
    else
    {
        enum N = nextPowerOf2(numBits);
        alias wideint!N TypeNeeded;
    }
}

/// abs() function for fixed-point numbers.
@nogc FixedPoint!(M, N) abs(int M, int N)(FixedPoint!(M, N) x) pure nothrow
{
    FixedPoint!(M, N) res = void;
    res.value = ((x.value >= 0) ? x.value : -x.value);
    return res;
}

unittest
{
    alias FixedPoint!(4,4) fix4;
    alias FixedPoint!(8,8) fix8;
    alias FixedPoint!(16,16) fix16;
    alias FixedPoint!(24,8) fix24_8;
    alias FixedPoint!(32,32) fix32_32;

    static assert (is(fix24_8.value_t == int));
    static assert (is(fix16.value_t == int));
    static assert (is(fix8.value_t == short));
    static assert (is(fix4.value_t == byte));

    static assert(fix8.ONE == 0x0100);
    static assert(fix16.ONE == 0x00010000);
    static assert(fix24_8.ONE == 0x0100);

    fix16 a = 1, b = 2, c = 3;
    assert(a < b);
    assert(c >= b);
    fix16 d;
    auto apb = a + b;
    auto bmc = b * c;
    d = a + b * c;
    assert(d.value == 7 * d.ONE);
    assert(d == 7);
    assert(32768 * (d / 32768) == 7);
}

private bool isPowerOf2(T)(T i) pure nothrow @nogc if (isIntegral!T) 
{
    assert(i >= 0);
    return (i != 0) && ((i & (i - 1)) == 0);
}

private int nextPowerOf2(int i) pure nothrow @nogc
{
    int v = i - 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    assert(isPowerOf2(v));
    return v;
}