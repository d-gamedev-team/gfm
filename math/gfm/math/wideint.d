/**
  Provide a 2^N-bit integer type.
  Guaranteed to never allocate and expected binary layout
  Recursive implementation with very slow division.

  <b>Supports all operations that builtin integers support.</b>

  Bugs: it's not sure if the unsigned operand would take precedence in a comparison/division.
  TODO: add literals.
 */
module gfm.math.wideint;

import std.traits,
       std.ascii;

/// Wide signed integer.
/// Params:
///    bits = number of bits, must be a power of 2.
template wideint(int bits)
{
    alias integer!(true, bits) wideint;
}

/// Wide unsigned integer.
/// Params:
///    bits = number of bits, must be a power of 2.
template uwideint(int bits)
{
    alias integer!(false, bits) uwideint;
}

// Some predefined integers (any power of 2 greater than 128 would work)

alias wideint!128 int128; // cent and ucent!
alias uwideint!128 uint128;

alias wideint!256 int256;
alias uwideint!256 uint256;

/// Use this template to get an arbitrary sized integer type.
private template integer(bool signed, int bits)
{
    static assert((bits & (bits - 1)) == 0); // bits must be a power of 2

    // forward to native type for lower numbers of bits
    static if (bits == 8)
    {
        static if (signed)
            alias byte integer;
        else
            alias ubyte integer;
    }
    else static if (bits == 16)
    {
        static if (signed)
            alias short integer;
        else
            alias ushort integer;
    }
    else static if (bits == 32)
    {
        static if (signed)
            alias int integer;
        else
            alias uint integer;
    }
    else static if (bits == 64)
    {
        static if (signed)
            alias long integer;
        else
            alias ulong integer;
    }
    else
    {
        alias wideIntImpl!(signed, bits) integer;
    }
}

/// Recursive 2^n integer implementation.
struct wideIntImpl(bool signed, int bits)
{
    static assert(bits >= 128);
    private
    {
        alias wideIntImpl self;

        template isSelf(T)
        {
            enum bool isSelf = is(Unqual!T == self);
        }

        alias integer!(true, bits/2) sub_int_t;   // signed bits/2 integer
        alias integer!(false, bits/2) sub_uint_t; // unsigned bits/2 integer

        alias integer!(true, bits/4) sub_sub_int_t;   // signed bits/4 integer
        alias integer!(false, bits/4) sub_sub_uint_t; // unsigned bits/4 integer

        static if(signed)
            alias sub_int_t hi_t; // hi_t has same signedness as the whole struct
        else
            alias sub_uint_t hi_t;

        alias sub_uint_t low_t;   // low_t is always unsigned

        enum _isWideIntImpl = true,
             _bits = bits,
             _signed = signed;
    }

    /// Construct from a value.
    @nogc this(T)(T x) pure nothrow
    {
        opAssign!T(x);
    }

    /// Assign with a smaller unsigned type.
    @nogc ref self opAssign(T)(T n) pure nothrow if (isIntegral!T && isUnsigned!T)
    {
        hi = 0;
        lo = n;
        return this;
    }

    /// Assign with a smaller signed type (sign is extended).
    @nogc ref self opAssign(T)(T n) pure nothrow if (isIntegral!T && isSigned!T)
    {
        // shorter int always gets sign-extended,
        // regardless of the larger int being signed or not
        hi = (n < 0) ? cast(hi_t)(-1) : cast(hi_t)0;

        // will also sign extend as well if needed
        lo = cast(sub_int_t)n;
        return this;
    }

    /// Assign with a wide integer of the same size (sign is lost).
    @nogc ref self opAssign(T)(T n) pure nothrow if (is(typeof(T._isWideIntImpl)) && T._bits == bits)
    {
        hi = n.hi;
        lo = n.lo;
        return this;
    }

    /// Assign with a smaller wide integer (sign is extended accordingly).
    @nogc ref self opAssign(T)(T n) pure nothrow if (is(typeof(T._isWideIntImpl)) && T._bits < bits)
    {
        static if (T._signed)
        {
            // shorter int always gets sign-extended,
            // regardless of the larger int being signed or not
            hi = cast(hi_t)((n < 0) ? -1 : 0);

            // will also sign extend as well if needed
            lo = cast(sub_int_t)n;
            return this;
        }
        else
        {
            hi = 0;
            lo = n;
            return this;
        }
    }

    /// Cast to a smaller integer type (truncation).
    @nogc T opCast(T)() pure const nothrow if (isIntegral!T)
    {
        return cast(T)lo;
    }

    /// Cast to bool.
    @nogc T opCast(T)() pure const nothrow if (is(T == bool))
    {
        return this != 0;
    }

    /// Cast to wide integer of any size.
    @nogc T opCast(T)() pure const nothrow if (is(typeof(T._isWideIntImpl)))
    {
        static if (T._bits < bits)
            return cast(T)lo;
        else
            return T(this);
    }

    /// Converts to a hexadecimal string.
    string toString() pure const nothrow
    {
        string outbuff = "0x";
        enum hexdigits = bits / 8;

        for (int i = 0; i < hexdigits; ++i)
        {
            outbuff ~= hexDigits[cast(int)((hi >> ((15 - i) * 4)) & 15)];
        }
        for (int i = 0; i < hexdigits; ++i)
        {
            outbuff ~= hexDigits[cast(int)((lo >> ((15 - i) * 4)) & 15)];
        }
        return outbuff;
    }

    @nogc self opBinary(string op, T)(T o) pure const nothrow if (!isSelf!T)
    {
        self r = this;
        self y = o;
        return r.opOpAssign!(op)(y);
    }

    @nogc self opBinary(string op, T)(T y) pure const nothrow if (isSelf!T)
    {
        self r = this; // copy
        self o = y;
        return r.opOpAssign!(op)(o);
    }

    @nogc ref self opOpAssign(string op, T)(T y) pure nothrow if (!isSelf!T)
    {
        const(self) o = y;
        return opOpAssign!(op)(o);
    }

    @nogc ref self opOpAssign(string op, T)(T y) pure nothrow if (isSelf!T)
    {
        static if (op == "+")
        {
            hi += y.hi;
            if (lo + y.lo < lo) // deal with overflow
                ++hi;
            lo += y.lo;
        }
        else static if (op == "-")
        {
            opOpAssign!"+"(-y);
        }
        else static if (op == "<<")
        {
            if (y >= bits)
            {
                hi = 0;
                lo = 0;
            }
            else if (y >= bits / 2)
            {
                hi = lo << (y.lo - bits / 2);
                lo = 0;
            }
            else if (y > 0)
            {
                hi = (lo >>> (-y.lo + bits / 2)) | (hi << y.lo);
                lo = lo << y.lo;
            }
        }
        else static if (op == ">>" || op == ">>>")
        {
            assert(y >= 0);
            static if (!signed || op == ">>>")
                immutable(sub_int_t) signFill = 0;
            else
                immutable(sub_int_t) signFill = cast(sub_int_t)(isNegative() ? -1 : 0);

            if (y >= bits)
            {
                hi = signFill;
                lo = signFill;
            }
            else if (y >= bits/2)
            {
                lo = hi >> (y.lo - bits/2);
                hi = signFill;
            }
            else if (y > 0)
            {
                lo = (hi << (-y.lo + bits/2)) | (lo >> y.lo);
                hi = hi >> y.lo;
            }
        }
        else static if (op == "*")
        {
            sub_sub_uint_t[4] a = toParts();
            sub_sub_uint_t[4] b = y.toParts();

            this = 0;
            for(int i = 0; i < 4; ++i)
                for(int j = 0; j < 4 - i; ++j)
                    this += self(cast(sub_uint_t)(a[i]) * b[j]) << ((bits/4) * (i + j));
        }
        else static if (op == "&")
        {
            hi &= y.hi;
            lo &= y.lo;
        }
        else static if (op == "|")
        {
            hi |= y.hi;
            lo |= y.lo;
        }
        else static if (op == "^")
        {
            hi ^= y.hi;
            lo ^= y.lo;
        }
        else static if (op == "/" || op == "%")
        {
            self q = void, r = void;
            static if(signed)
                Internals!bits.signedDivide(this, y, q, r);
            else
                Internals!bits.unsignedDivide(this, y, q, r);
            static if (op == "/")
                this = q;
            else
                this = r;
        }
        else
        {
            static assert(false, "unsupported operation '" ~ op ~ "'");
        }
        return this;
    }

    // const unary operations
    @nogc self opUnary(string op)() pure const nothrow if (op == "+" || op == "-" || op == "~")
    {
        static if (op == "-")
        {
            self r = this;
            r.not();
            r.increment();
            return r;
        }
        else static if (op == "+")
           return this;
        else static if (op == "~")
        {
            self r = this;
            r.not();
            return r;
        }
    }

    // non-const unary operations
    @nogc self opUnary(string op)() pure nothrow if (op == "++" || op == "--")
    {
        static if (op == "++")
            increment();
        else static if (op == "--")
            decrement();
        return this;
    }

    @nogc bool opEquals(T)(T y) pure const if (!isSelf!T)
    {
        return this == self(y);
    }

    @nogc bool opEquals(T)(T y) pure const if (isSelf!T)
    {
       return lo == y.lo && y.hi == hi;
    }

    @nogc int opCmp(T)(T y) pure const if (!isSelf!T)
    {
        return opCmp(self(y));
    }

    @nogc int opCmp(T)(T y) pure const if (isSelf!T)
    {
        if (hi < y.hi) return -1;
        if (hi > y.hi) return 1;
        if (lo < y.lo) return -1;
        if (lo > y.lo) return 1;
        return 0;
    }

    // binary layout should be what is expected on this platform
    version (LittleEndian)
    {
        low_t lo;
        hi_t hi;
    }
    else
    {
        hi_t hi;
        low_t lo;
    }

    private
    {
        static if (signed)
        {
            @nogc bool isNegative() pure nothrow const
            {
                return signBit();
            }
        }
        else
        {
            @nogc bool isNegative() pure nothrow const
            {
                return false;
            }
        }

        @nogc void not() pure nothrow
        {
            hi = ~hi;
            lo = ~lo;
        }

        @nogc void increment() pure nothrow
        {
            ++lo;
            if (lo == 0) ++hi;
        }

        @nogc void decrement() pure nothrow
        {
            if (lo == 0) --hi;
            --lo;
        }

        @nogc bool signBit() pure const nothrow
        {
            enum SIGN_SHIFT = bits / 2 - 1;
            return ((hi >> SIGN_SHIFT) & 1) != 0;
        }

        @nogc sub_sub_uint_t[4] toParts() pure const nothrow
        {
            sub_sub_uint_t[4] p = void;
            enum SHIFT = bits / 4;
            immutable lomask = cast(sub_uint_t)(cast(sub_sub_int_t)(-1));
            p[3] = cast(sub_sub_uint_t)(hi >> SHIFT);
            p[2] = cast(sub_sub_uint_t)(hi & lomask);
            p[1] = cast(sub_sub_uint_t)(lo >> SHIFT);
            p[0] = cast(sub_sub_uint_t)(lo & lomask);
            return p;
        }
    }
}

@nogc public wideIntImpl!(signed, bits) abs(bool signed, int bits)(wideIntImpl!(signed, bits) x) pure nothrow
{
    if(x >= 0)
        return x;
    else
        return -x;
}

private struct Internals(int bits)
{
    alias wideIntImpl!(true, bits) wint_t;
    alias wideIntImpl!(false, bits) uwint_t;

    @nogc static void unsignedDivide(uwint_t dividend, uwint_t divisor,
                                     out uwint_t quotient, out uwint_t remainder) pure nothrow
    {
        assert(divisor != 0);

        uwint_t rQuotient = 0;
        uwint_t cDividend = dividend;

        while (divisor <= cDividend)
        {
            // find N so that (divisor << N) <= cDividend && cDividend < (divisor << (N + 1) )

            uwint_t N = 0;
            uwint_t cDivisor = divisor;
            while (cDividend > cDivisor)
            {
                if (cDivisor.signBit())
                    break;

                if (cDividend < (cDivisor << 1))
                    break;

                cDivisor <<= 1;
                ++N;
            }
            cDividend = cDividend - cDivisor;
            rQuotient += (uwint_t(1) << N);
        }

        quotient = rQuotient;
        remainder = cDividend;
    }

    @nogc static void signedDivide(wint_t dividend, wint_t divisor,
                                   out wint_t quotient, out wint_t remainder) pure nothrow
    {
        uwint_t q, r;
        unsignedDivide(uwint_t(abs(dividend)), uwint_t(abs(divisor)), q, r);

        // remainder has same sign as the dividend
        if (dividend < 0)
            r = -r;

        // negate the quotient if opposite signs
        if ((dividend >= 0) != (divisor >= 0))
            q = -q;

        quotient = q;
        remainder = r;

        assert(remainder == 0 || ((remainder < 0) == (dividend < 0)));
    }
}

unittest
{
    long step = 164703072086692425;
    for (long si = long.min; si <= long.max - step; si += step)
    {
        for (long sj = long.min; sj <= long.max - step; sj += step)
        {
            ulong ui = cast(ulong)si;
            ulong uj = cast(ulong)sj;
            int128 csi = si;
            uint128 cui = si;
            int128 csj = sj;
            uint128 cuj = sj;
            assert(csi == csi);
            assert(~~csi == csi);
            assert(-(-csi) == csi);
            assert(++csi == si + 1);
            assert(--csi == si);

            string testSigned(string op)
            {
                return "assert(cast(ulong)(si" ~ op ~ "sj) == cast(ulong)(csi" ~ op ~ "csj));";
            }

            string testMixed(string op)
            {
                return "assert(cast(ulong)(ui" ~ op ~ "sj) == cast(ulong)(cui" ~ op ~ "csj));"
                     ~ "assert(cast(ulong)(si" ~ op ~ "uj) == cast(ulong)(csi" ~ op ~ "cuj));";
            }

            string testUnsigned(string op)
            {
                return "assert(cast(ulong)(ui" ~ op ~ "uj) == cast(ulong)(cui" ~ op ~ "cuj));";
            }

            string testAll(string op)
            {
                return testSigned(op) ~ testMixed(op) ~ testUnsigned(op);
            }

            mixin(testAll("+"));
            mixin(testAll("-"));
            mixin(testAll("*"));
            mixin(testAll("|"));
            mixin(testAll("&"));
            mixin(testAll("^"));
            if (sj != 0)
            {
                mixin(testSigned("/"));
                mixin(testSigned("%"));
                if (si >= 0 && sj >= 0)
                {
                    // those operations are not supposed to be the same at
                    // higher bitdepth: a sign-extended negative may yield higher dividend
                    testMixed("/");
                    testUnsigned("/");
                    testMixed("%");
                    testUnsigned("%");
                }
            }
        }
    }
}
