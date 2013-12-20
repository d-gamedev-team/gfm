module gfm.math.vector;

import std.traits,
       std.math,
       std.string;

import gfm.math.funcs;

/**
 * Generic 1D small vector.
 * Params: 
 *    N = number of elements
 *    T = type of elements
 */
align(1) struct Vector(T, size_t N)
{
align(1):
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
                static if (N >= 1)
                {
                    T x;
                    alias x r;
                }
                static if (N >= 2)
                {
                    T y;
                    alias y g;
                }
                static if (N >= 3)
                {
                    T z;
                    alias z b;
                }
                static if (N >= 4)
                {
                    T w;
                    alias w a;
                }
            }
        }

        static if (N == 2u)
        {
            /// Creates a vector of 2 elements.
            this(X : T, Y : T)(X x_, Y y_) pure nothrow
            {
                x = x_;
                y = y_;
            }
        }
        else static if (N == 3u)
        {
            /// Creates a vector of 3 elements.
            this(X : T, Y : T, Z : T)(X x_, Y y_, Z z_) pure nothrow
            {
                x = x_;
                y = y_;
                z = z_;
            }

            /// Creates a vector of 3 elements.
            this(X : T, Y : T)(Vector!(X, 2u) xy_, Y z_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = z_;
            }

            /// Creates a vector of 3 elements.
            this(X : T, Y : T)(X x_, Vector!(Y, 2u) yz_) pure nothrow
            {
                x = x_;
                y = yz_.x;
                z = yz_.y;
            }
        }
        else static if (N == 4u)
        {
            /// Creates a vector of 4 elements.
            this(X : T, Y : T, Z : T, W : T)(X x_, Y y_, Z z_, W w_) pure nothrow
            {
                x = x_;
                y = y_;
                z = z_;
                w = w_;
            }

            /// Creates a vector of 4 elements.
            this(X : T, Y : T)(Vector!(X, 2u) xy_, Vector!(Y, 2u)zw_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = zw_.x;
                w = zw_.y;
            }

            /// Creates a vector of 4 elements.
            this(X : T, Y : T, Z : T)(Vector!(X, 2u) xy_, Y z_, Z w_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = z_;
                w = w_;
            }

            /// Creates a vector of 4 elements.
            this(X : T, Y : T)(Vector!(X, 3u) xyz_, Y w_) pure nothrow
            {
                x = xyz_.x;
                y = xyz_.y;
                z = xyz_.z;
                w = w_;
            }

            /// Creates a vector of 4 elements.
            this(X : T, Y : T)(X x_, Vector!(X, 3u) yzw_) pure nothrow
            {
                x = x_;
                y = yzw_.x;
                z = yzw_.y;
                w = yzw_.z;
            }
        }

        /// Construct a Vector from a value.
        this(U)(U x) pure nothrow
        {
            opAssign!U(x);
        }

        /// Assign a Vector from a compatible type.
        ref Vector opAssign(U)(U x) pure nothrow if (is(U: T))
        {
            v[] = x; // copy to each component
            return this;
        }

        /// Assign a Vector with a static array type.
        ref Vector opAssign(U)(U arr) pure nothrow if ((isStaticArray!(U) && is(typeof(arr[0]) : T) && (arr.length == N)))
        {
            for (size_t i = 0; i < N; ++i)
                v[i] = arr[i];
            return this;
        }

        /// Assign with a dynamic array.
        /// Size is checked in debug-mode.
        ref Vector opAssign(U)(U arr) pure nothrow if (isDynamicArray!(U) && is(typeof(arr[0]) : T))
        {
            assert(arr.length == N);
            for (size_t i = 0; i < N; ++i)
                v[i] = arr[i];
            return this;
        }

        /// Assign from a samey Vector.
        ref Vector opAssign(U)(U u) pure nothrow if (is(U : Vector))
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
                    v[i] = u.v[i];
                }
            }
            return this;
        }

        /// Assign from other vectors types (same size, compatible type).
        ref Vector opAssign(U)(U x) pure nothrow if (is(typeof(U._isVector))
                                                 && is(U._T : T)
                                                 && (!is(U: Vector))
                                                 && (U._N == _N))
        {
            for (size_t i = 0; i < N; ++i)
                v[i] = x.v[i];
            return this;
        }

        /// Returns: a pointer to content.
        T* ptr() pure nothrow @property
        {
            return v.ptr;
        }

        /// Converts to a pretty string.
        string toString() const nothrow
        {
            try
                return format("%s", v);
            catch (Exception e) 
                assert(false); // should not happen since format is right
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

        T opIndexAssign(U : T)(U x, size_t i) pure nothrow
        {
            return v[i] = x;
        }


        /// Implements swizzling.
        ///
        /// Example:
        /// ---
        /// vec4i vi = [4, 1, 83, 10];
        /// assert(vi.zxxyw == [83, 4, 4, 1, 10]);
        /// ---
        @property auto opDispatch(string op, U = void)() pure const nothrow if (isValidSwizzle!(op))
        {
            alias Vector!(T, op.length) returnType;
            returnType res = void;
            enum indexTuple = swizzleTuple!op;
            foreach(i, index; indexTuple)
                res.v[i] = v[index];
            return res;
        }

        /// Support swizzling assignment like in shader languages.
        ///
        /// Example:
        /// ---
        /// vec3f v = [0, 1, 2];
        /// v.yz = v.zx;
        /// assert(v == [0, 2, 0]);
        /// ---
        void opDispatch(string op, U)(U x) pure
            if ((op.length >= 2)
                && (isValidSwizzleUnique!op)                   // v.xyy will be rejected
                && is(typeof(Vector!(T, op.length)(x)))) // can be converted to a small vector of the right size
        {
            Vector!(T, op.length) conv = x;
            enum indexTuple = swizzleTuple!op;
            foreach(i, index; indexTuple)
                v[index] = conv[i];
        }

        /// Casting to small vectors of the same size.
        /// Example:
        /// ---
        /// vec4f vf;
        /// vec4d vd = cast!(vec4d)vf;
        /// ---
        U opCast(U)() pure const nothrow if (is(typeof(U._isVector)) && (U._N == _N))
        {
            U res = void;
            for (size_t i = 0; i < N; ++i)
            {
                res.v[i] = cast(U._T)v[i];
            }
            return res;
        }

        /// Implement slices operator overloading.
        /// Allows to go back to slice world.
        /// Returns: length.
        size_t opDollar() pure const nothrow
        {
            return N;
        }

        /// Returns: a slice which covers the whole Vector.
        T[] opSlice() pure nothrow
        {
            return v[];
        }

        // vec[a..b]
        T[] opSlice(int a, int b) pure nothrow
        {
            return v[a..b];
        }

        /// Returns: squared length.
        T squaredLength() pure const nothrow
        {
            T sumSquares = 0;
            for (size_t i = 0; i < N; ++i)
            {
                sumSquares += v[i] * v[i];
            }
            return sumSquares;
        }

        // Returns: squared Euclidean distance.
        T squaredDistanceTo(Vector v) pure const nothrow
        {
            return (v - this).squaredLength();
        }

        static if (isFloatingPoint!T)
        {
            /// Returns: Euclidean length
            T length() pure const nothrow
            {
                return sqrt(squaredLength());
            }

            /// Returns: Euclidean distance between this and other.
            T distanceTo(Vector other) pure const nothrow
            {
                return (other - this).length();
            }

            /// In-place normalization.
            void normalize() pure nothrow
            {
                auto invLength = 1 / length();
                for (size_t i = 0; i < N; ++i)
                {
                    v[i] *= invLength;
                }
            }

            /// Returns: Normalized vector.
            Vector normalized() pure const nothrow
            {
                Vector res = this;
                res.normalize();
                return res;
            }

            static if (N == 3)
            {
                /// Gets an orthogonal vector from a 3-dimensional vector.
                /// Doesn’t normalise the output.
                /// Authors: Sam Hocevar
                /// See_also: Source at $(WEB lolengine.net/blog/2013/09/21/picking-orthogonal-vector-combing-coconuts).
                Vector getOrthogonalVector()
                {
                    return abs(x) > abs(z) ? Vector(-y, x, 0.0) : Vector(0.0, -z, y);
                }
            }
        }
    }

    private
    {
        enum _isVector = true; // do we really need this? I don't know.

        enum _N = N;
        alias T _T;

        // define types that can be converted to this, but are not the same type
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

        template isValidSwizzle(string op, int lastSwizzleClass = -1)
        {
            static if (op.length == 0)
                enum bool isValidSwizzle = true;
            else
            {
                enum len = op.length;
                enum int swizzleClass = swizzleClassify!(op[0]);
                enum bool swizzleClassValid = (lastSwizzleClass == -1 || (swizzleClass == lastSwizzleClass));
                enum bool isValidSwizzle = (swizzleIndex!(op[0]) != -1) 
                                         && swizzleClassValid 
                                         && isValidSwizzle!(op[1..len], swizzleClass);
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

        // true if the swizzle has at the maximum one time each letter
        template isValidSwizzleUnique(string op)
        {
            static if (isValidSwizzle!op)
                enum isValidSwizzleUnique = hasNoDuplicates!op.result;
            else
                enum bool isValidSwizzleUnique = false;
        }

        template swizzleIndex(char c)
        {
            static if((c == 'x' || c == 'r') && N >= 1)
                enum swizzleIndex = 0;
            else static if((c == 'y' || c == 'g') && N >= 2)
                enum swizzleIndex = 1;
            else static if((c == 'z' || c == 'b') && N >= 3)
                enum swizzleIndex = 2;
            else static if ((c == 'w' || c == 'a') && N >= 4)
                enum swizzleIndex = 3;
            else
                enum swizzleIndex = -1;
        }

        template swizzleClassify(char c)
        {
            static if(c == 'x' || c == 'y' || c == 'z' || c == 'w')
                enum swizzleClassify = 0;
            else static if(c == 'r' || c == 'g' || c == 'b' || c == 'a')
                enum swizzleClassify = 1;
            else
                enum swizzleClassify = -1;
        }

        template swizzleTuple(string op)
        {
            enum opLength = op.length;
            static if (op.length == 0)
                enum swizzleTuple = [];
            else
                enum swizzleTuple = [ swizzleIndex!(op[0]) ] ~ swizzleTuple!(op[1..op.length]);
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


/// Element-wise minimum.
Vector!(T, N) min(T, size_t N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    Vector!(T, N) res = void;
    for(size_t i = 0; i < N; ++i)
        res[i] = min(a[i], b[i]);
    return res;
}

/// Element-wise maximum.
Vector!(T, N) max(T, size_t N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    Vector!(T, N) res = void;
    for(size_t i = 0; i < N; ++i)
        res[i] = max(a[i], b[i]);
    return res;
}

/// Returns: Dot product.
T dot(T, size_t N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    T sum = 0;
    for(size_t i = 0; i < N; ++i)
    {
        sum += a[i] * b[i];
    }
    return sum;
}

/// Returns: 3D cross product.
/// Thanks to vuaru for corrections.
Vector!(T, 3u) cross(T)(const Vector!(T, 3u) a, const Vector!(T, 3u) b) pure nothrow
{
    return Vector!(T, 3u)(a.y * b.z - a.z * b.y,
                          a.z * b.x - a.x * b.z,
                          a.x * b.y - a.y * b.x);
}

/// 3D reflect, like the GLSL function.
/// Returns: a reflected by normal b.
Vector!(T, 3u) reflect(T)(const Vector!(T, 3u) a, const Vector!(T, 3u) b) pure nothrow
{
    return a - (2 * dot(b, a)) * b;
}


/// Returns: angle between vectors.
/// See_also: "The Right Way to Calculate Stuff" at $(WEB www.plunk.org/~hatch/rightway.php)
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
    static assert(vec4i.isValidSwizzle!"brra");
    static assert(!vec4i.isValidSwizzle!"rgyz");
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
    assert(x.abgr == [10, 83, 1, 4]);
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

    h.yx = vec2i(5, 2); // swizzle assignment

    assert(h.xy == [2, 5]);
    assert(-h[1] == -5);
    assert(++h[0] == 3);

    //assert(h == [-2, 1, 0]);
    assert(!__traits(compiles, h.xx = h.yy));
    vec4ub j;

    assert(lerp(vec2f(-10, -1), vec2f(10, 1), 0.5) == vec2f(0, 0));
}

