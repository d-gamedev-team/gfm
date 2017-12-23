/**
  Provide a 2^N-bit integer type.
  Guaranteed to never allocate and expected binary layout
  Recursive implementation with very slow division.

  <b>Supports all operations that builtin integers support.</b>

  Bugs: it's not sure if the unsigned operand would take precedence in a comparison/division.
          - a < b should be an unsigned comparison if at least one operand is unsigned
          - a / b should be an unsigned division   if at least one operand is unsigned
 */
module gfm.integers.wideint;

import std.traits,
       std.ascii;
import std.format : FormatSpec;

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
    if ((bits & (bits - 1)) == 0)
{

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

private template integer(bool signed, int bits)
    if ((bits & (bits - 1)) != 0)
{
    static assert(0, "wide integer bits must be a power of 2");
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

        enum _bits = bits,
             _signed = signed;
    }

    /// Construct from a value.
    @nogc this(T)(T x) pure nothrow
    {
        opAssign!T(x);
    }

    // Private functions used by the `literal` template.
    private static bool isValidDigitString(string digits)
    {
        import std.algorithm : startsWith;
        import std.ascii : isDigit;

        if (digits.startsWith("0x"))
        {
            foreach (d; digits[2 .. $])
            {
                if (!isHexDigit(d) && d != '_')
                    return false;
            }
        }
        else // decimal
        {
            static if (signed)
                if (digits.startsWith("-"))
                    digits = digits[1 .. $];
            if (digits.length < 1)
                return false;   // at least 1 digit required
            foreach (d; digits)
            {
                if (!isDigit(d) && d != '_')
                    return false;
            }
        }
        return true;
    }

    private static typeof(this) literalImpl(string digits)
    {
        import std.algorithm : startsWith;
        import std.ascii : isDigit;

        typeof(this) value = 0;
        if (digits.startsWith("0x"))
        {
            foreach (d; digits[2 .. $])
            {
                if (d == '_')
                    continue;
                value <<= 4;
                if (isDigit(d))
                    value += d - '0';
                else
                    value += 10 + toUpper(d) - 'A';
            }
        }
        else
        {
            static if (signed)
            {
                bool negative = false;
                if (digits.startsWith("-"))
                {
                    negative = true;
                    digits = digits[1 .. $];
                }
            }
            foreach (d; digits)
            {
                if (d == '_')
                    continue;
                value *= 10;
                value += d - '0';
            }
            static if (signed)
                if (negative)
                    value = -value;
        }
        return value;
    }

    /// Construct from compile-time digit string.
    ///
    /// Both decimal and hex digit strings are supported.
    ///
    /// Example:
    /// ----
    /// auto x = int128.literal!"20_000_000_000_000_000_001";
    /// assert((x >>> 1) == 0x8AC7_2304_89E8_0000);
    ///
    /// auto y = int126.literal!"0x1_158E_4609_13D0_0001";
    /// assert(y == x);
    /// ----
    template literal(string digits)
    {
        static assert(isValidDigitString(digits),
                      "invalid digits in literal: " ~ digits);
        enum literal = literalImpl(digits);
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
    @nogc ref self opAssign(T)(T n) pure nothrow if (isWideIntInstantiation!T && T._bits == bits)
    {
        hi = n.hi;
        lo = n.lo;
        return this;
    }

    /// Assign with a smaller wide integer (sign is extended accordingly).
    @nogc ref self opAssign(T)(T n) pure nothrow if (isWideIntInstantiation!T && T._bits < bits)
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
    @nogc T opCast(T)() pure const nothrow if (isWideIntInstantiation!T)
    {
        static if (T._bits < bits)
            return cast(T)lo;
        else
            return T(this);
    }

    /// Converts to a string. Supports format specifiers %d, %s (both decimal)
    /// and %x (hex).
    void toString(DG, Char)(DG sink, FormatSpec!Char fmt) const
        if (is(typeof(sink((const(Char)[]).init))))
    {
        if (fmt.spec == 'x')
        {
            if (this == 0)
            {
                sink("0");
                return;
            }

            enum maxDigits = bits / 4;
            Char[maxDigits] buf;
            wideIntImpl tmp = this;
            size_t i;

            for (i = maxDigits-1; tmp != 0 && i < buf.length; i--)
            {
                buf[i] = hexDigits[cast(int)tmp & 0b00001111];
                tmp >>= 4;
            }
            assert(i+1 < buf.length);
            sink(buf[i+1 .. $]);
        }
        else // default to decimal
        {
            import std.algorithm : reverse;

            if (this == 0)
            {
                sink("0");
                return;
            }

            // The maximum number of decimal digits is basically
            // ceil(log_10(2^^bits - 1)), which is slightly below
            // ceil(bits * log(2)/log(10)). The value 0.30103 is a slight
            // overestimate of log(2)/log(10), to be sure we never
            // underestimate. We add 1 to account for rounding up.
            enum maxDigits = cast(ulong)(0.30103 * bits) + 1;
            Char[maxDigits] buf;
            size_t i;
            self q = void, r = void;

            wideIntImpl tmp = this;
            if (tmp < 0)
            {
                sink("-");
                tmp = -tmp;
            }
            for (i = maxDigits-1; tmp > 0; i--)
            {
                assert(i < buf.length);
                static if (signed)
                    Internals!bits.signedDivide(tmp, self.literal!"10", q, r);
                else
                    Internals!bits.unsignedDivide(tmp, self.literal!"10", q, r);

                buf[i] = digits[cast(int)(r)];
                tmp = q;
            }
            assert(i+1 < buf.length);
            sink(buf[i+1 .. $]);
        }
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

template isWideIntInstantiation(U)
{
    private static void isWideInt(bool signed, int bits)(wideIntImpl!(signed, bits) x)
    {
    }

    enum bool isWideIntInstantiation = is(typeof(isWideInt(U.init)));
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

// Verify that toString is callable from pure / nothrow / @nogc code as long as
// the callback also has these attributes.
pure nothrow @nogc unittest
{
    int256 x = 123;
    FormatSpec!char fspec;

    fspec.spec = 's';
    x.toString((const(char)[]) {}, fspec);

    // Verify that wide strings actually work
    FormatSpec!dchar dfspec;
    dfspec.spec = 's';
    x.toString((const(dchar)[] x) { assert(x == "123"); }, dfspec);
}

unittest
{
    import std.string : format;

    int128 x;
    x.hi = 1;
    x.lo = 0x158E_4609_13D0_0001;
    assert(format("%s", x) == "20000000000000000001");
    assert(format("%d", x) == "20000000000000000001");
    assert(format("%x", x) == "1158E460913D00001");

    x.hi = 0xFFFF_FFFF_FFFF_FFFE;
    x.lo = 0xEA71_B9F6_EC2F_FFFF;
    assert(format("%d", x) == "-20000000000000000001");
    assert(format("%x", x) == "FFFFFFFFFFFFFFFEEA71B9F6EC2FFFFF");

    x.hi = x.lo = 0;
    assert(format("%d", x) == "0");

    x.hi = x.lo = 0xFFFF_FFFF_FFFF_FFFF;
    assert(format("%d", x) == "-1"); // array index boundary condition
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

unittest
{
    // Just a little over 2^64, so it actually needs int128.
    // Hex value should be 0x1_158E_4609_13D0_0001.
    enum x = int128.literal!"20_000_000_000_000_000_001";
    assert(x.hi == 0x1 && x.lo == 0x158E_4609_13D0_0001);
    assert((x >>> 1) == 0x8AC7_2304_89E8_0000);

    enum y = int128.literal!"0x1_158E_4609_13D0_0001";
    enum z = int128.literal!"0x1_158e_4609_13d0_0001"; // case insensitivity
    assert(x == y && y == z && x == z);
}

unittest
{
    import std.string : format;

    // Malformed literals that should be rejected
    assert(!__traits(compiles, int128.literal!""));
    assert(!__traits(compiles, int128.literal!"-"));

    // Negative literals should be supported
    auto x = int128.literal!"-20000000000000000001";
    assert(x.hi == 0xFFFF_FFFF_FFFF_FFFE &&
           x.lo == 0xEA71_B9F6_EC2F_FFFF);
    assert(format("%d", x) == "-20000000000000000001");
    assert(format("%x", x) == "FFFFFFFFFFFFFFFEEA71B9F6EC2FFFFF");

    // Negative literals should not be supported for unsigned types
    assert(!__traits(compiles, uint128.literal!"-1"));

    // Hex formatting tests
    x = 0;
    assert(format("%x", x) == "0");
    x = -1;
    assert(format("%x", x) == "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF");
}
