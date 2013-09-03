module gfm.math.fixedpoint;

/**
 * Fixed point integers.
 *
 * Status:
 *   Use at your own risk.
 */

import std.traits;

import gfm.math.softcent;

/**
 * M.N fixed point integer
 * Designed for fast execution instead of proper rounding
 * Does not manage overflow
 * If M + N > 32, then softcent is used and this will likely be slow.
 */
struct FixedPoint(int M, int N)
{
    static assert(M > 0);       // unsupported
    static assert(N > 0);
    static assert(M + N <= 64);

    public
    {
        alias TypeNeeded!(N + M) value_t;

        // construct with value
        this(U)(U x) pure nothrow
        {
            opAssign!U(x);
        }

        ref FixedPoint opAssign(U)(U x) pure nothrow if (is(U: FixedPoint))
        {
            value = x.value;
            return this;
        }

        ref FixedPoint opAssign(U)(U x) pure nothrow if (isIntegral!U)
        {
            value = x * ONE;                // exact
            return this;
        }

        ref FixedPoint opAssign(U)(U x) pure nothrow if (isFloatingPoint!U)
        {
            value = cast(value_t)(x * ONE); // truncation
            return this;
        }

        // casting to float
        U opCast(U)() pure const nothrow if (isFloatingPoint!U)
        {
            return cast(U)(value) / ONE;
        }

        // casting to integer (truncation)
        U opCast(U)() pure const nothrow if (isIntegral!U)
        {
            return cast(U)(value) >> N;
        }

        ref FixedPoint opOpAssign(string op, U)(U x) pure nothrow if (is(U: FixedPoint))
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

        ref FixedPoint opOpAssign(string op, U)(U x) pure nothrow if (isConvertible!U)
        {
            FixedPoint conv = x;
            return opOpAssign!op(conv);
        }

        FixedPoint opBinary(string op, U)(U x) pure const nothrow if (is(U: FixedPoint) || (isConvertible!U))
        {
            FixedPoint temp = this;
            return temp.opOpAssign!op(x);
        }

        FixedPoint opBinaryRight(string op, U)(U x) pure const nothrow if (isConvertible!U)
        {
            FixedPoint temp = x;
            return temp.opOpAssign!op(this);
        }

        bool opEquals(U)(U other) pure const nothrow if (is(U : FixedPoint))
        {
            return value == other.value;
        }

        bool opEquals(U)(U other) pure const nothrow if (isConvertible!U)
        {
            FixedPoint conv = other;
            return opEquals(conv);
        }

        int opCmp(in FixedPoint other) pure const nothrow
        {
            if (value > other.value)
                return 1;
            else if (value < other.value)
                return -1;
            else
                return 0;
        }

        FixedPoint opUnary(string op)() pure const nothrow if (op == "+")
        {
            return this;
        }

        FixedPoint opUnary(string op)() pure const nothrow if (op == "-")
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
        enum value_t HIGH_MASK = ~LOW_MASK;
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

alias FixedPoint!(4,4) fix4;
alias FixedPoint!(8,8) fix8;
alias FixedPoint!(16,16) fix16;
alias FixedPoint!(24,8) fix24_8;
alias FixedPoint!(32,32) fix32_32;

// select an integer type suitable to hold bits
private template TypeNeeded(int bits)
{
    static if (bits <= 8)
    {
        alias byte TypeNeeded;
    }
    else static if (bits <= 16)
    {
        alias short TypeNeeded;
    }
    else static if (bits <= 32)
    {
        alias int TypeNeeded;
    }
    else static if (bits <= 64)
    {
        alias long TypeNeeded;
    }
    else static if (bits <= 128)
    {
        alias softcent TypeNeeded;
    }
    else
    {
        // bigger fixed-point integers are not supported
        static assert(false);
    }
}

FixedPoint!(M, N) abs(int M, int N)(FixedPoint!(M, N) x) pure nothrow
{
    FixedPoint!(M, N) res = void;
    res.value = ((x.value >= 0) ? x.value : -x.value);
    return res;
}

unittest
{
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
