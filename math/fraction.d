module gfm.math.fraction;

/**
* Fractions, always in reduced form.
*/

import std.traits;
import std.string;

struct Fraction
{
    public
    {      
        long num;
        long denom;

        // construct with integer
        this(long n) pure nothrow
        {
            opAssign!long(n);
        }

        this(Fraction f) pure nothrow
        {
            opAssign!Fraction(f);
        }

        // construct from numerator and denominator
        this(long numerator, long denominator) pure nothrow
        {
            num = numerator;
            denom = denominator;
            reduce();
        }       

        string toString() const
        {
            return format("%s/%s", num, denom);
        }

        void opAssign(T)(T other) pure nothrow if (is(Unqual!T == Fraction))
        {
            num = other.num;
            denom = other.denom;
        }

        void opAssign(T)(T n) pure nothrow if (isIntegral!T)
        {
            num = n;
            denom = 1;
        }

        Fraction opBinary(string op, T)(T o) pure const nothrow
        {
            Fraction r = this;
            Fraction y = o;
            return r.opOpAssign!(op)(y);
        }
        
        Fraction opOpAssign(string op, T)(T o) pure nothrow if (!is(Unqual!T == Fraction))
        {
            const(self) o = y;
            return opOpAssign!(op)(o);
        }

        Fraction opOpAssign(string op, T)(T o) pure nothrow if (is(Unqual!T == Fraction))
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
        Fraction opUnary(string op)() pure const nothrow if (op == "+" || op == "-")
        {
            static if (op == "-")
            {
                Fraction f = this;
                f.num = -f.num;                
                return f;
            }
            else static if (op == "+")
                return this;
        }

        // non-const unary operations
        Fraction opUnary(string op)() pure nothrow if (op=="++" || op=="--")
        {
            static if (op=="++") 
            {
                num += denom;
                checkInvariant(); // should still be reduced
            }
            else static if (op=="--")
            {
                num -= denom;
                checkInvariant(); // should still be reduced
            }
            return this;
        }

        bool opEquals(T)(T y) pure const if (!is(Unqual!T == Fraction))
        {
            return this == Fraction(y);
        }

        bool opEquals(T)(T o) pure const if (is(Unqual!T == Fraction))
        {
            // invariants ensures equal fraction have equal representations
            return num == o.num && denom == o.denom;
        }

        int opCmp(T)(T o) pure const if (!is(Unqual!T == Fraction))
        {
            return opCmp(Fraction(o));
        }

        int opCmp(T)(T o) pure const if (is(Unqual!T == Fraction))
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

        Fraction inverse() pure const nothrow
        {
            return Fraction(denom, num);
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
            checkInvariant();            
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
    Fraction x = Fraction(9, 3);    
    assert(x.num == 3);
    assert(x.denom == 1);

    assert(x < 4);
    assert(x > 2);
    assert(x > Fraction(8,3));
    assert(x > Fraction(-8,3));
    assert(x == Fraction(-27, -9));

    assert(Fraction(-4, 7) + 2 == Fraction(10, 7));
    assert(Fraction(-4, 7) == Fraction(10, 7) - 2);

    assert(++Fraction(3,7) == Fraction(10,7));
    assert(--Fraction(3,7) == Fraction(-4,7));
    assert(+x == 3);
    assert(-x == -3);

    Fraction y = -4;
    assert(y.num == -4);
    assert(y.denom == 1);

    assert(Fraction(2, 3) * Fraction(15, 7) == Fraction(10, 7));
    assert(Fraction(2, 3) == Fraction(10, 7) / Fraction(15, 7));
}