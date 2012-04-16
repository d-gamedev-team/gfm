/**
 * Provide a 128-bit integer type
 * guaranteed to never allocate and expected binary layout
 * Designed to be easy to read, probably too slow for heavy use.
 * Relies on division algorithm from Ian Kaplan.
 */
module softcent;
import std.traits : Unqual, isIntegral, isSigned, isUnsigned;
import std.ascii : hexDigits;

@safe struct softcentImpl(bool signed)
{
    private 
    {
        alias softcentImpl self;

        template isSelf(T)
        {
            enum bool isSelf = is(Unqual!T == self);
        }

        static if(signed)
            alias long hi_t;
        else
            alias ulong hi_t;
    }
 
    this(T)(T x) pure nothrow
    {
        opAssign!T(x);
    }

    void opAssign(T)(T n) pure nothrow if (isIntegral!T && isUnsigned!T) // conversion from smaller unsigned types
    {
        hi = 0;
        lo = n;
    }

    void opAssign(T)(T n) pure nothrow if (isIntegral!T && isSigned!T) // conversion from smaller signed types
    {
        // shorter int always gets sign-extended,
        // regardless of the larger int being signed or not
        hi = (n < 0) ? cast(hi_t)(-1) : 0;

        // will also sign extend as well if needed
        lo = cast(long)n; 
    }

    void opAssign(T)(T n) pure nothrow if (is(Unqual!T == softcentImpl!(!signed))) // signed <=> unsigned
    {
        hi = n.hi;
        lo = n.lo;
    }

    void opAssign(T)(T n) pure nothrow if (isSelf!T)
    {
        hi = n.hi;
        lo = n.lo;
    }

    T opCast(T)() pure const nothrow if (isIntegral!T)
    {
        return cast(T)lo;
    }

    T opCast(T)() pure const nothrow if (is(T == bool))
    {
        return this != 0;
    }

    string toString() pure const nothrow
    {
        string outbuff = "0x";
        for (size_t i = 0; i < 16; ++i)
            outbuff ~= hexDigits[15 & (hi >> ((15 - i) * 4))];
        for (size_t i = 0; i < 16; ++i)
            outbuff ~= hexDigits[15 & (lo >> ((15 - i) * 4))];        
        return outbuff;
    }

    self opBinary(string op, T)(T o) pure const nothrow if (!isSelf!T)
    {
        self r = this;
        self y = o;
        return r.opOpAssign!(op)(y);
    }

    self opBinary(string op, T)(T y) pure const nothrow if (isSelf!T)
    {
        self r = this; // copy
        self o = y;
        return r.opOpAssign!(op)(o);
    }

    self opOpAssign(string op, T)(T y) pure nothrow if (!isSelf!T)
    {
        const(self) o = y;
        return opOpAssign!(op)(o);
    }

    self opOpAssign(string op, T)(T y) pure nothrow if (isSelf!T)
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
            assert(y >= 0); // should it be implemented through >>?
            if (y >= 128)
            {
                hi = 0;
                lo = 0;
            }
            else if (y >= 64)
            {
                hi = lo << (y.lo - 64);
                lo = 0;
            }
            else if (y > 0)
            {
                hi = (lo >>> (64 - y.lo)) | (hi << y.lo);
                lo = lo << y.lo;
            }
        }
        else static if (op == ">>" || op == ">>>")
        {
            assert(y >= 0); // should it be implemented through <<?
            static if (!signed || op == ">>>")
                immutable(long) signFill = 0;
            else
                immutable(long) signFill = isNegative() ? cast(long)(-1) : 0;

            if (y >= 128)
            {
                hi = signFill;
                lo = signFill;
            }
            else if (y >= 64)
            {
                lo = hi >> (y.lo - 64);
                hi = signFill;
            }
            else if (y > 0)
            {
                lo = (hi << (64 - y.lo)) | (lo >> y.lo);
                hi = hi >> y.lo;
            }
        }
        else static if (op == "*")
        {
            uint[4] a = toParts();
            uint[4] b = y.toParts();

            this = 0;
            for(size_t i = 0; i < 4; ++i)
                for(size_t j = 0; j < 4 - i; ++j)
                    this += self(cast(ulong)(a[i]) * b[j]) << (32 * (i + j));
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
                Internals.signedDivide(this, y, q, r);
            else
                Internals.unsignedDivide(this, y, q, r);
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
    self opUnary(string op)() pure const nothrow if (op == "+" || op == "-" || op == "~")
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
    self opUnary(string op)() pure nothrow if (op=="++" || op=="--")
    {
        static if (op=="++") 
            increment();
        else static if (op=="--") 
            decrement();
        return this;
    }

    bool opEquals(T)(T y) pure const if (!isSelf!T)
    {
        return this == self(y);
    }

    bool opEquals(T)(T y) pure const if (isSelf!T)
    {
       return lo == y.lo && y.hi == hi;
    }

    int opCmp(T)(T y) pure const if (!isSelf!T)
    {
        return opCmp(self(y));
    }

    int opCmp(T)(T y) pure const if (isSelf!T)
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
        ulong lo;
        hi_t hi;
    }
    else
    {
        hi_t hi;
        ulong lo;
    }

    private
    {
        static if (signed)
        {
            bool isNegative() pure nothrow const
            {
                return ((hi >> 63) & 1) != 0;
            }
        }
        else
        {
            bool isNegative() pure nothrow const
            {
                return false;
            }
        }

        void not() pure nothrow
        {
            hi = ~hi;
            lo = ~lo;
        }

        void increment() pure nothrow
        {
            ++lo;
            if (lo == 0) ++hi;
        }

        void decrement() pure nothrow
        {
            if (lo == 0) --hi;
            --lo;
        }

        self signBit() pure const nothrow
        {
            return self((hi >> 63) & 1);
        }

        uint[4] toParts() pure const nothrow
        {
            uint[4] p = void;
            p[3] = hi >> 32;
            p[2] = hi & 0xffff_ffff;
            p[1] = lo >> 32;
            p[0] = lo & 0xffff_ffff;
            return p;
        }
    }
}

alias softcentImpl!false softucent;
alias softcentImpl!true softcent;

static assert(softucent.sizeof == 16);
static assert(softcent.sizeof == 16);

public softcentImpl!signed abs(bool signed)(softcentImpl!signed x) pure nothrow
{
    if(x >= 0)
        return x;
    else
        return -x;
}


/*
Copyright stuff

Use of this program, for any purpose, is granted the author,
Ian Kaplan, as long as this copyright notice is included in
the source code or any source code derived from this program.
The user assumes all responsibility for using this code.

Ian Kaplan, October 1996

*/
@safe private struct Internals
{
    static void unsignedDivide(softucent dividend, softucent divisor,
                               out softucent quotient, out softucent remainder) pure nothrow
    {
        assert(divisor != 0);

        softucent q = 0, r = 0;

        if (divisor > dividend)
            r = dividend;
        else if (divisor == dividend)
            q = 1;
        else
        {
            size_t numBits = 128;

            softucent d = void;

            while (r < divisor)
            {
                r = (r << 1) | (dividend.signBit());
                d = dividend;
                dividend = dividend << 1;
                --numBits;
            }

            /* The loop, above, always goes one iteration too far.
            To avoid inserting an "if" statement inside the loop
            the last iteration is simply reversed. */
            dividend = d;
            r = r >>> 1;
            ++numBits;

            for (size_t i = 0; i < numBits; ++i)
            {
                r = (r << 1) | (dividend.signBit());
                softucent t = r - divisor;
                softucent s = (t.signBit()) ? 0 : 1;
                dividend = dividend << 1;
                q = (q << 1) | s;
                if (s)
                    r = t;
            }
        }
        quotient = q;
        remainder = r;
    }

    static void signedDivide(softcent dividend, softcent divisor,
                             out softcent quotient, out softcent remainder) pure nothrow
    {
        softucent q, r;
        unsignedDivide(softucent(abs(dividend)), softucent(abs(divisor)), q, r);

        /* the sign of the remainder is the same as the sign of the dividend */
        if (dividend < 0)
            r = -r;

        /* the quotient is negated if the signs of the operands are opposite */
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
            softcent csi = si;
            softucent cui = si;
            softcent csj = sj;
            softucent cuj = sj;
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
                    // higher bitdepth: a sign-extended negative will yield way higher dividend
                    testMixed("/");
                    testUnsigned("/");
                    testMixed("%");
                    testUnsigned("%");
                }
            }
        }
    }
}
