module gfm.math.vector;

import std.traits;
import std.math;

// generic 1D small vector
// N is the element count, T the contained type
// intended for 3D
// TODO: - generic way to build a Vector from a variadic constructor of scalars, tuples, arrays and smaller vectors
//       - find a way to enable swizzling assignment
// TBD:  - do we need support for slice assignment and opSliceOpAsssign? meh.

align(1) struct Vector(T, size_t N)
{
nothrow:
    public
    {
        static assert(N >= 1u);

        // fields definition
        union
        {
            T[N] v;
            struct
            {
                static if (N >= 1) T x;
                static if (N >= 2) T y;
                static if (N >= 3) T z;
                static if (N >= 4) T w;
            }
        }

        static if (N == 2u)
        {
            this(X : T, Y : T)(X x_, Y y_) pure nothrow
            {
                x = x_;
                y = y_;
            }
        }
        else static if (N == 3u)
        {
            this(X : T, Y : T, Z : T)(X x_, Y y_, Z z_) pure nothrow
            {
                x = x_;
                y = y_;
                z = z_;
            }

            this(X : T, Y : T)(Vector!(X, 2u) xy_, Y z_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = z_;
            }
        }
        else static if (N == 4u)
        {
            this(X : T, Y : T, Z : T, W : T)(X x_, Y y_, Z z_, W w_) pure nothrow
            {
                x = x_;
                y = y_;
                z = z_;
                w = w_;
            }

            this(X : T, Y : T)(Vector!(X, 2u) xy_, Vector!(Y, 2u)zwy_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = zw_.x;
                w = zw_.y;
            }

            this(X : T, Y : T, Z : T)(Vector!(X, 2u) xy_, Y z_, Z w_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = z_;
                w = w_;
            }

            this(X : T, Y : T)(Vector!(X, 3u) xyz_, Y w_) pure nothrow
            {
                x = xyz_.x;
                y = xyz_.y;
                z = zwz_.z;
                w = w_;
            }

            this(X : T, Y : T)(X x_, Vector!(X, 3u) yzw_) pure nothrow
            {
                x = x_;
                y = yzw_.x;
                z = yzw_.y;
                w = yzw_.z;
            }
        }

        this(U)(U x) pure nothrow
        {
            opAssign!U(x);
        }

        // assign with compatible type
        void opAssign(U)(U x) pure nothrow if (is(U: T))
        {
            v[] = x; // copy to each component
        }

        // assign with a static array type
        void opAssign(U)(U arr) pure nothrow if ((isStaticArray!(U) && is(typeof(arr[0]) : T) && (arr.length == N)))
        {
            for (size_t i = 0; i < N; ++i)
            {
                v[i] = arr[i];
            }
        }

        // assign with a dynamic array (check size)
        void opAssign(U)(U arr) pure nothrow if (isDynamicArray!(U) && is(typeof(arr[0]) : T))
        {
            assert(arr.length == N);
            for (size_t i = 0; i < N; ++i)
            {
                v[i] = arr[i];
            }
        }

        // same small vectors
        void opAssign(U)(U u) pure nothrow if (is(U : Vector))
        {
            static if (N <= 4u)
            {
                x = u.x;
                static if(N >= 2u) y = u.y;
                static if(N >= 3u) z = u.z;
                static if(N >= 4u) w = u.w;
            }
            else
            {
                for (size_t i = 0; i < N; ++i)
                {
                    v[i] = x.v[i];
                }
            }
        }

        // other small vectors (same size, compatible type)
        void opAssign(U)(U x) pure nothrow if (is(typeof(U._isVector))
                                            && is(U._T : T)
                                             && (!is(U: Vector))
                                             && (U._N == _N))
        {
            for (size_t i = 0; i < N; ++i)
            {
                v[i] = x.v[i];
            }
        }

        bool opEquals(U)(U other) pure const nothrow
            if (is(U : Vector))
        {
            for (size_t i = 0; i < N; ++i)
            {
                if (v[i] != other.v[i])
                {
                    return false;
                }
            }
            return true;
        }

        bool opEquals(U)(U other) pure const nothrow
            if (isConvertible!U)
        {
            Vector conv = other;
            return opEquals(conv);
        }

        Vector opUnary(string op)() pure const nothrow
            if (op == "+" || op == "-" || op == "~" || op == "!")
        {
            Vector res = void;
            for (size_t i = 0; i < N; ++i)
            {
                mixin("res.v[i] = " ~ op ~ "v[i];");
            }
            return res;
        }

        ref Vector opOpAssign(string op, U)(U operand) pure nothrow
            if (is(U : Vector))
        {
            for (size_t i = 0; i < N; ++i)
            {
                mixin("v[i] " ~ op ~ "= operand.v[i];");
            }
            return this;
        }

        ref Vector opOpAssign(string op, U)(U operand) pure nothrow if (isConvertible!U)
        {
            Vector conv = operand;
            return opOpAssign!op(conv);
        }

        Vector opBinary(string op, U)(U operand) pure const nothrow
            if (is(U: Vector) || (isConvertible!U))
        {
            Vector temp = this;
            return temp.opOpAssign!op(operand);
        }

        Vector opBinaryRight(string op, U)(U operand) pure const nothrow if (isConvertible!U)
        {
            Vector temp = operand;
            return temp.opOpAssign!op(this);
        }

        ref T opIndex(size_t i) pure nothrow
        {
            return v[i];
        }

        ref const(T) opIndex(size_t i) pure const nothrow
        {
            return v[i];
        }

        /*
        T opIndex(size_t i) pure const nothrow
        {
            return v[i];
        }*/

        T opIndexAssign(U : T)(U x, size_t i) pure nothrow
        {
            return v[i] = x;
        }
    /+
        T opIndexOpAssign(string op, U)(size_t i, U x) if (is(U : T))
        {
            mixin("v[i] " ~ op ~ "= x;");
            return v[i];
        }

         T opIndexUnary(string op, U)(size_t i) if (op == "+" || op == "-" || op == "~")
        {
            mixin("return " ~ op ~ "v[i];");
        }

        ref T opIndexUnary(string op, U, I)(I i) if (op == "++" || op == "--")
        {
            mixin(op ~ "v[i];");
            return v[i];
        }
    +/

        // implement swizzling
        @property auto opDispatch(string op, U = void)() pure const nothrow
            if (isValidSwizzle!(op))
        {
            alias Vector!(T, op.length) returnType;
            returnType res = void;
            enum indexTuple = swizzleTuple!(op, op.length).result;
            foreach(i, index; indexTuple)
            {
                res.v[i] = v[index];
            }
            return res;
        }

        /+
        // Support swizzling assignment like in shader languages.
        // eg: eg: vec.yz = vec.zx;
        void opDispatch(string op, U)(U x) pure
            if ((op.length >= 2)
                && (isValidSwizzleUnique!op)                  // v.xyy will be rejected
                && is(typeof(Vector!(op.length, T)(x)))) // can be converted to a small vector of the right size
        {
            Vector!(op.length, T) conv = x;
            enum indexTuple = swizzleTuple!(op, op.length).result;
            foreach(i, index; indexTuple)
            {
                v[index] = conv[i];
            }
            return res;
        }
        +/

        // casting to small vectors of the same size
        U opCast(U)() pure const nothrow if (is(typeof(U._isVector)) && (U._N == _N))
        {
            U res = void;
            for (size_t i = 0; i < N; ++i)
            {
                res.v[i] = cast(U._T)v[i];
            }
            return res;
        }

        // implement slices operator overloading
        // allows to go back to slice world
        size_t opDollar() pure const nothrow
        {
            return N;
        }

        // vec[]
        T[] opSlice() pure nothrow
        {
            return v[];
        }

        // vec[a..b]
        T[] opSlice(int a, int b) pure nothrow
        {
            return v[a..b];
        }

        // Squared length
        T squaredLength() pure const nothrow
        {
            T sumSquares = 0;
            for (size_t i = 0; i < N; ++i)
            {
                sumSquares += v[i] * v[i];
            }
            return sumSquares;
        }

        // Euclidean distance
        T squaredDistanceTo(Vector v) pure const nothrow
        {
            return (v - this).squaredLength();
        }

        static if (isFloatingPoint!T)
        {
            // Euclidean length
            T length() pure const nothrow
            {
                return sqrt(squaredLength());
            }

            // Euclidean distance
            T distanceTo(Vector v) pure const nothrow
            {
                return (v - this).length();
            }

            // normalization
            void normalize() pure nothrow
            {
                auto invLength = 1 / length();
                for (size_t i = 0; i < N; ++i)
                {
                    v[i] *= invLength;
                }
            }

            Vector normalized() pure const nothrow
            {
                Vector res = this;
                res.normalize();
                return res;
            }
        }
    }

    private
    {
        enum _isVector = true; // do we really need this? I don't know.

        enum _N = N;
        alias T _T;

        // define types that can be converted to this, but are not the same type
        // TODO: don't use assignment...
        template isConvertible(T)
        {
            enum bool isConvertible = (!is(T : Vector))
            && is(typeof(
                {
                    T x;
                    Vector v = x;
                }()));
        }

        // define types that can't be converted to this
        template isForeign(T)
        {
            enum bool isForeign = (!isConvertible!T) && (!is(T: Vector));
        }

        template isValidSwizzle(string op)
        {
            static if (op.length == 0)
            {
                enum bool isValidSwizzle = false;
            }
            else
            {
                enum bool isValidSwizzle = isValidSwizzleImpl!(op, op.length).result;
            }
        }

        template searchElement(char c, string s)
        {
            static if (s.length == 0)
            {
                enum bool result = false;
            }
            else
            {
                enum string tail = s[1..s.length];
                enum bool result = (s[0] == c) || searchElement!(c, tail).result;
            }
        }

        template hasNoDuplicates(string s)
        {
            static if (s.length == 1)
            {
                enum bool result = true;
            }
            else
            {
                enum tail = s[1..s.length];
                enum bool result = !(searchElement!(s[0], tail).result) && hasNoDuplicates!(tail).result;
            }
        }

        template isValidSwizzleUnique(string op)
        {
            static if (isValidSwizzle!op)
            {
                enum isValidSwizzleUnique = hasNoDuplicates!op.result;
            }
            else
            {
                enum bool isValidSwizzleUnique = false;
            }
        }

        template isValidSwizzleImpl(string op, size_t opLength)
        {
            static if (opLength == 0)
            {
                enum bool result = true;
            }
            else
            {
                enum len = op.length;
                enum bool result = (swizzleIndex!(op[0]) != -1)
                                   && isValidSwizzleImpl!(op[1..len], opLength - 1).result;
            }
        }

        template swizzleIndex(char c)
        {
            static if(c == 'x' && N >= 1)
            {
                enum size_t swizzleIndex = 0u;
            }
            else static if(c == 'y' && N >= 2)
            {
                enum size_t swizzleIndex = 1u;
            }
            else static if(c == 'z' && N >= 3)
            {
                enum size_t swizzleIndex = 2u;
            }
            else static if (c == 'w' && N >= 4)
            {
                enum size_t swizzleIndex = 3u;
            }
            else
                enum size_t swizzleIndex = cast(size_t)(-1);
        }

        template swizzleTuple(string op, size_t opLength)
        {
            static assert(opLength > 0);
            enum c = op[0];
            static if (opLength == 1)
            {
                enum result = [swizzleIndex!c];
            }
            else
            {
                enum string rest = op[1..opLength];
                enum recurse = swizzleTuple!(rest, opLength - 1).result;
                enum result = [swizzleIndex!c] ~ recurse;
            }

        }
    }
}

private string definePostfixAliases(string type)
{
    return "alias " ~ type ~ "!byte "   ~ type ~ "b;\n"
         ~ "alias " ~ type ~ "!ubyte "  ~ type ~ "ub;\n"
         ~ "alias " ~ type ~ "!short "  ~ type ~ "s;\n"
         ~ "alias " ~ type ~ "!ushort " ~ type ~ "us;\n"
         ~ "alias " ~ type ~ "!int "    ~ type ~ "i;\n"
         ~ "alias " ~ type ~ "!uint "   ~ type ~ "ui;\n"
         ~ "alias " ~ type ~ "!long "   ~ type ~ "l;\n"
         ~ "alias " ~ type ~ "!ulong "  ~ type ~ "ul;\n"
         ~ "alias " ~ type ~ "!float "  ~ type ~ "f;\n"
         ~ "alias " ~ type ~ "!double " ~ type ~ "d;\n"
         ~ "alias " ~ type ~ "!real "   ~ type ~ "L;\n";
}

template vec2(T) { alias Vector!(T, 2u) vec2; }
template vec3(T) { alias Vector!(T, 3u) vec3; }
template vec4(T) { alias Vector!(T, 4u) vec4; }

mixin(definePostfixAliases("vec2"));
mixin(definePostfixAliases("vec3"));
mixin(definePostfixAliases("vec4"));


/// element-wise minimum
Vector!(T, N) min(T, size_t N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    Vector!(T, N) res = void;
    for(size_t i = 0; i < N; ++i)
        res[i] = min(a[i], b[i]);
    return res;
}


/// element-wise maximum
Vector!(T, N) max(T, size_t N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    Vector!(T, N) res = void;
    for(size_t i = 0; i < N; ++i)
        res[i] = max(a[i], b[i]);
    return res;
}


/// dot product
T dot(T, size_t N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    T sum = 0;
    for(size_t i = 0; i < N; ++i)
    {
        sum += a[i] * b[i];
    }
    return sum;
}


/// 3D cross product
Vector!(T, 3u) cross(T)(const Vector!(T, 3u) a, const Vector!(T, 3u) b) pure nothrow
{
    return Vector!(T, 3u)(a.y * b.z - b.z * a.y,
                          a.z * b.x - b.x * a.z,
                          a.x * b.y - b.y * a.x);
}


/**
 * Return angle between vectors
 * see "The Right Way to Calculate Stuff" at http://www.plunk.org/~hatch/rightway.php
 */
T angleBetween(T, size_t N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    auto aN = a.normalized();
    auto bN = b.normalized();
    auto dp = dot(aN, bN);

    if (dp < 0)
        return PI - 2 * asin((-bN-aN).length / 2);
    else
        return 2 * asin((bN-aN).length / 2);
}


unittest
{
    static assert(vec2i.isValidSwizzle!"xyx");
    static assert(!vec2i.isValidSwizzle!"xyz");
    static assert(vec2i.isValidSwizzleUnique!"xy");
    static assert(vec2i.isValidSwizzleUnique!"yx");
    static assert(!vec2i.isValidSwizzleUnique!"xx");

    assert(vec2l(0, 1) == vec2i(0, 1));

    int[2] arr = [0, 1];
    int[] arr2 = new int[2];
    arr2[] = arr[];
    vec2i a = vec2i([0, 1]);
    vec2i a2 = vec2i(0, 1);
    immutable vec2i b = vec2i(0);
    assert(b[0] == 0 && b[1] == 0);
    vec2i c = arr;
    vec2l d = arr2;
    assert(a == a2);
    assert(a == c);
    assert(vec2l(a) == vec2l(a));
    assert(vec2l(a) == d);

    vec4i x = [4, 5, 6, 7];
    assert(x == x);
    --x[0];
    assert(x[0] == 3);
    ++x[0];
    assert(x[0] == 4);
    x[1] &= 1;
    x[2] = 77 + x[2];
    x[3] += 3;
    assert(x == [4, 1, 83, 10]);
    assert(x.xxywz == [4, 4, 1, 10, 83]);
    assert(x.xxxxxxx == [4, 4, 4, 4, 4, 4, 4]);
    assert(a != b);

    vec2l e = a;
    vec2l f = a + b;
    assert(f == vec2l(a));

    vec3ui g = vec3i(78,9,4);
    g ^= vec3i(78,9,4);
    assert(g == vec3ui(0));
    //g[0..2] = 1u;
    //assert(g == [2, 1, 0]);

    assert(vec2i(4, 5) + 1 == vec2i(5,6));
    assert(vec2i(4, 5) - 1 == vec2i(3,4));
    assert(1 + vec2i(4, 5) == vec2i(5,6));
    assert(vec3f(1,1,1) * 0 == 0);
    assert(1.0 * vec3d(4,5,6) == vec3f(4,5.0f,6.0));

    auto dx = vec2i(1,2);
    auto dy = vec2i(4,5);
    auto dp = dot(dx, dy);
    assert(dp == 14 );

    vec3i h = cast(vec3i)(vec3d(0.5, 1.1, -2.2));
    assert(h == [0, 1, -2]);
    assert(h[] == [0, 1, -2]);
    assert(h[1..3] == [1, -2]);
    assert(h.zyx == [-2, 1, 0]);
//    h.xy = vec2i(0, 1);
    assert(h.xy == [0, 1]);
    //assert(h == [-2, 1, 0]);
    assert(!__traits(compiles, h.xx = h.yy));
    vec4ub j;
}

