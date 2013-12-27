module gfm.math.rational;

import std.traits,
       std.string;

/**
  
  A rational number, always in reduced form. Supports basic arithmetic.

  Bugs: Remove this module once std.rational is here.

 */
align(1) struct Rational
{
    align(1):    
    public
    {
        long num;   /// Numerator.
        long denom; /// Denominator.

        /// Construct a Rational from an integer.
        this(long n) pure nothrow
        {
            opAssign!long(n);
        }

        /// Construct a Rational from another Rational.
        this(Rational f) pure nothrow
        {
            opAssign!Rational(f);
        }

        /// Construct a Rational from numerator and denominator.
        this(long numerator, long denominator) pure nothrow
        {
            num = numerator;
            denom = denominator;
            reduce();
        }

        /// Converts to pretty string.
        string toString() const
        {
            return format("%s/%s", num, denom);
        }

        /// Cast to floating point.
        T opCast(T)() pure const nothrow if (isFloatingPoint!T)
        {
            return cast(T)num / cast(T)denom;
        }

        /// Assign with another Rational.
        ref Rational opAssign(T)(T other) pure nothrow if (is(Unqual!T == Rational))
        {
            num = other.num;
            denom = other.denom;
            return this;
        }

        /// Assign with an integer.
        ref Rational opAssign(T)(T n) pure nothrow if (isIntegral!T)
        {
            num = n;
            denom = 1;
            return this;
        }

        Rational opBinary(string op, T)(T o) pure const nothrow
        {
            Rational r = this;
            Rational y = o;
            return r.opOpAssign!(op)(y);
        }

        ref Rational opOpAssign(string op, T)(T o) pure nothrow if (!is(Unqual!T == Rational))
        {
            const(self) o = y;
            return opOpAssign!(op)(o);
        }

        ref Rational opOpAssign(string op, T)(T o) pure nothrow if (is(Unqual!T == Rational))
        {
            static if (op == "+")
            {
                num = num * o.denom + o.num * denom;
                denom = denom * o.denom;
                reduce();
            }
            else static if (op == "-")
            {
                opOpAssign!"+"(-o);
            }
            else static if (op == "*")
            {
                denom = denom * o.denom;
                num = num * o.num;
                reduce();
            }
            else static if (op == "/")
            {
                opOpAssign!"*"(o.inverse());
            }
            else
            {
                static assert(false, "unsupported operation '" ~ op ~ "'");
            }
            return this;
        }

        // const unary operations
        Rational opUnary(string op)() pure const nothrow if (op == "+" || op == "-")
        {
            static if (op == "-")
            {
                Rational f = this;
                f.num = -f.num;
                return f;
            }
            else static if (op == "+")
                return this;
        }

        // non-const unary operations
        Rational opUnary(string op)() pure nothrow if (op=="++" || op=="--")
        {
            static if (op=="++")
            {
                num += denom;
                debug checkInvariant(); // should still be reduced
            }
            else static if (op=="--")
            {
                num -= denom;
                debug checkInvariant(); // should still be reduced
            }
            return this;
        }

        bool opEquals(T)(T y) pure const if (!is(Unqual!T == Rational))
        {
            return this == Rational(y);
        }

        bool opEquals(T)(T o) pure const if (is(Unqual!T == Rational))
        {
            // invariants ensures two equal Rationals have equal representations
            return num == o.num && denom == o.denom;
        }

        int opCmp(T)(T o) pure const if (!is(Unqual!T == Rational))
        {
            return opCmp(Rational(o));
        }

        int opCmp(T)(T o) pure const if (is(Unqual!T == Rational))
        {
            assert(denom > 0);
            assert(o.denom > 0);
            long det = num * o.denom - denom * o.num;
            if (det > 0)
                return 1;
            else if (det < 0)
                return -1;
            else
                return 0;
        }

        /// Returns: Inverse of this rational number.
        Rational inverse() pure const nothrow
        {
            return Rational(denom, num);
        }
    }

    private
    {
        // FIXME: be consistent with regards to sign
        static long GCD(long a, long b) pure nothrow
        {
            if (b == 0)
                return a;
            else
                return GCD(b, a % b);
        }

        void reduce() pure nothrow
        {
            const(long) gcd = GCD(num, denom);
            num /= gcd;
            denom /= gcd;
            if (denom < 0)
            {
                num = -num;
                denom = -denom;
            }
            debug checkInvariant();
        }

        void checkInvariant() pure nothrow // can't do this in invariant() because of opAssign
        {
            assert(denom > 0);
            auto gcd = GCD(num, denom);
            assert(gcd == 1 || gcd == -1);
        }
    }
}

unittest
{
    Rational x = Rational(9, 3);
    assert(x.num == 3);
    assert(x.denom == 1);

    assert(x < 4);
    assert(x > 2);
    assert(x > Rational(8,3));
    assert(x > Rational(-8,3));
    assert(x == Rational(-27, -9));

    assert(Rational(-4, 7) + 2 == Rational(10, 7));
    assert(Rational(-4, 7) == Rational(10, 7) - 2);

    assert(++Rational(3,7) == Rational(10,7));
    assert(--Rational(3,7) == Rational(-4,7));
    assert(+x == 3);
    assert(-x == -3);

    Rational y = -4;
    assert(y.num == -4);
    assert(y.denom == 1);

    assert(Rational(2, 3) * Rational(15, 7) == Rational(10, 7));
    assert(Rational(2, 3) == Rational(10, 7) / Rational(15, 7));
}
