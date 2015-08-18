module gfm.math.vector;

import std.traits,
       std.math,
       std.conv,
       std.array,
       std.string;

import gfm.math.funcs;

static if( __VERSION__ < 2066 ) private enum nogc = 1;

/**
 * Generic 1D small vector.
 * Params:
 *    N = number of elements
 *    T = type of elements
 */
align(1) struct Vector(T, int N)
{
align(1):
nothrow:
    public
    {
        static assert(N >= 1);

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

        static if (N == 2)
        {
            /// Creates a vector of 2 elements.
            @nogc this(X : T, Y : T)(X x_, Y y_) pure nothrow
            {
                x = x_;
                y = y_;
            }
        }
        else static if (N == 3)
        {
            /// Creates a vector of 3 elements.
            @nogc this(X : T, Y : T, Z : T)(X x_, Y y_, Z z_) pure nothrow
            {
                x = x_;
                y = y_;
                z = z_;
            }

            /// Creates a vector of 3 elements.
            @nogc this(X : T, Y : T)(Vector!(X, 2) xy_, Y z_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = z_;
            }

            /// Creates a vector of 3 elements.
            @nogc this(X : T, Y : T)(X x_, Vector!(Y, 2) yz_) pure nothrow
            {
                x = x_;
                y = yz_.x;
                z = yz_.y;
            }
        }
        else static if (N == 4)
        {
            /// Creates a vector of 4 elements.
            @nogc this(X : T, Y : T, Z : T, W : T)(X x_, Y y_, Z z_, W w_) pure nothrow
            {
                x = x_;
                y = y_;
                z = z_;
                w = w_;
            }

            /// Creates a vector of 4 elements.
            @nogc this(X : T, Y : T)(Vector!(X, 2) xy_, Vector!(Y, 2)zw_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = zw_.x;
                w = zw_.y;
            }

            /// Creates a vector of 4 elements.
            @nogc this(X : T, Y : T, Z : T)(Vector!(X, 2) xy_, Y z_, Z w_) pure nothrow
            {
                x = xy_.x;
                y = xy_.y;
                z = z_;
                w = w_;
            }

            /// Creates a vector of 4 elements.
            @nogc this(X : T, Y : T)(Vector!(X, 3) xyz_, Y w_) pure nothrow
            {
                x = xyz_.x;
                y = xyz_.y;
                z = xyz_.z;
                w = w_;
            }

            /// Creates a vector of 4 elements.
            @nogc this(X : T, Y : T)(X x_, Vector!(X, 3) yzw_) pure nothrow
            {
                x = x_;
                y = yzw_.x;
                z = yzw_.y;
                w = yzw_.z;
            }
        }

        /// Construct a Vector from a value.
        @nogc this(U)(U x) pure nothrow
        {
            opAssign!U(x);
        }

        /// Assign a Vector from a compatible type.
        @nogc ref Vector opAssign(U)(U x) pure nothrow if (is(U: T))
        {
            v[] = x; // copy to each component
            return this;
        }

        /// Assign a Vector with a static array type.
        @nogc ref Vector opAssign(U)(U arr) pure nothrow if ((isStaticArray!(U) && is(typeof(arr[0]) : T) && (arr.length == N)))
        {
            v[] = arr[];
            return this;
        }
        
        /// Assign from castable static array.
        @nogc ref Vector opAssign(U)(U arr) pure nothrow if ((isStaticArray!(U) && is(typeof(cast(T)arr[0])) && (arr.length == N)))
        {
            mixin(generateLoopCode!("v[@] = cast(T)arr[@];", N)());
            return this;
        }

        /// Assign with a dynamic array.
        /// Size is checked in debug-mode.
        @nogc ref Vector opAssign(U)(U arr) pure nothrow if (isDynamicArray!(U) && is(typeof(arr[0]) : T))
        {
            assert(arr.length == N);
            mixin(generateLoopCode!("v[@] = arr[@];", N)());
            return this;
        }
        
        /// Assign from castable dynamic array.
        @nogc ref Vector opAssign(U)(U arr) pure nothrow if (isDynamicArray!(U) && is(typeof(cast(T)arr[0])))
        {
            mixin(generateLoopCode!("v[@] = cast(T)arr[@];", N)());
            return this;
        }

        /// Assign from a samey Vector.
        @nogc ref Vector opAssign(U)(U u) pure nothrow if (is(U : Vector))
        {
            v[] = u.v[];
            return this;
        }

        /// Assign from other vectors types (same size, compatible type).
        @nogc ref Vector opAssign(U)(U x) pure nothrow if (is(typeof(U._isVector))
                                                       && is(U._T : T)
                                                       && (!is(U: Vector))
                                                       && (U._N == _N))
        {
            mixin(generateLoopCode!("v[@] = x.v[@];", N)());
            return this;
        }

        /// Returns: a pointer to content.
        @nogc inout(T)* ptr() pure inout nothrow @property
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

        @nogc bool opEquals(U)(U other) pure const nothrow
            if (is(U : Vector))
        {
            for (int i = 0; i < N; ++i)
            {
                if (v[i] != other.v[i])
                {
                    return false;
                }
            }
            return true;
        }

        @nogc bool opEquals(U)(U other) pure const nothrow
            if (isConvertible!U)
        {
            Vector conv = other;
            return opEquals(conv);
        }

        @nogc Vector opUnary(string op)() pure const nothrow
            if (op == "+" || op == "-" || op == "~" || op == "!")
        {
            Vector res = void;
            mixin(generateLoopCode!("res.v[@] = " ~ op ~ " v[@];", N)());
            return res;
        }

        @nogc ref Vector opOpAssign(string op, U)(U operand) pure nothrow
            if (is(U : Vector))
        {
            mixin(generateLoopCode!("v[@] " ~ op ~ "= operand.v[@];", N)());
            return this;
        }

        @nogc ref Vector opOpAssign(string op, U)(U operand) pure nothrow if (isConvertible!U)
        {
            Vector conv = operand;
            return opOpAssign!op(conv);
        }

        @nogc Vector opBinary(string op, U)(U operand) pure const nothrow
            if (is(U: Vector) || (isConvertible!U))
        {
            Vector result = void;
            static if (is(U: T))
                mixin(generateLoopCode!("result.v[@] = cast(T)(v[@] " ~ op ~ " operand);", N)());
            else
            {
                Vector other = operand;
                mixin(generateLoopCode!("result.v[@] = cast(T)(v[@] " ~ op ~ " other.v[@]);", N)());
            }
            return result;
        }

        @nogc Vector opBinaryRight(string op, U)(U operand) pure const nothrow if (isConvertible!U)
        {
            Vector result = void;
            static if (is(U: T))
                mixin(generateLoopCode!("result.v[@] = cast(T)(operand " ~ op ~ " v[@]);", N)());
            else
            {
                Vector other = operand;
                mixin(generateLoopCode!("result.v[@] = cast(T)(other.v[@] " ~ op ~ " v[@]);", N)());
            }
            return result;
        }

        @nogc ref T opIndex(size_t i) pure nothrow
        {
            return v[i];
        }

        @nogc ref const(T) opIndex(size_t i) pure const nothrow
        {
            return v[i];
        }

        @nogc T opIndexAssign(U : T)(U x, size_t i) pure nothrow
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
        @nogc @property auto opDispatch(string op, U = void)() pure const nothrow if (isValidSwizzle!(op))
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
        @nogc @property void opDispatch(string op, U)(U x) pure
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
        @nogc U opCast(U)() pure const nothrow if (is(typeof(U._isVector)) && (U._N == _N))
        {
            U res = void;
            mixin(generateLoopCode!("res.v[@] = cast(U._T)v[@];", N)());
            return res;
        }

        /// Implement slices operator overloading.
        /// Allows to go back to slice world.
        /// Returns: length.
        @nogc int opDollar() pure const nothrow
        {
            return N;
        }

        /// Returns: a slice which covers the whole Vector.
        @nogc T[] opSlice() pure nothrow
        {
            return v[];
        }

        // vec[a..b]
        @nogc T[] opSlice(int a, int b) pure nothrow
        {
            return v[a..b];
        }

        /// Returns: squared length.
        @nogc T squaredLength() pure const nothrow
        {
            T sumSquares = 0;
            mixin(generateLoopCode!("sumSquares += v[@] * v[@];", N)());
            return sumSquares;
        }

        // Returns: squared Euclidean distance.
        @nogc T squaredDistanceTo(Vector v) pure const nothrow
        {
            return (v - this).squaredLength();
        }

        static if (isFloatingPoint!T)
        {
            /// Returns: Euclidean length
            @nogc T length() pure const nothrow
            {
                return sqrt(squaredLength());
            }

            /// Returns: Inverse of Euclidean length.
            @nogc T inverseLength() pure const nothrow
            {
                return 1 / sqrt(squaredLength());
            }

            /// Faster but less accurate inverse of Euclidean length.
            /// Returns: Inverse of Euclidean length.
            @nogc T fastInverseLength() pure const nothrow
            {
                return inverseSqrt(squaredLength());
            }

            /// Returns: Euclidean distance between this and other.
            @nogc T distanceTo(Vector other) pure const nothrow
            {
                return (other - this).length();
            }

            /// In-place normalization.
            @nogc void normalize() pure nothrow
            {
                auto invLength = inverseLength();
                mixin(generateLoopCode!("v[@] *= invLength;", N)());
            }

            /// Returns: Normalized vector.
            @nogc Vector normalized() pure const nothrow
            {
                Vector res = this;
                res.normalize();
                return res;
            }

            /// Faster but less accurate in-place normalization.
            @nogc void fastNormalize() pure nothrow
            {
                auto invLength = fastInverseLength();
                mixin(generateLoopCode!("v[@] *= invLength;", N)());
            }

            /// Faster but less accurate vector normalization.
            /// Returns: Normalized vector.
            @nogc Vector fastNormalized() pure const nothrow
            {
                Vector res = this;
                res.fastNormalize();
                return res;
            }

            static if (N == 3)
            {
                /// Gets an orthogonal vector from a 3-dimensional vector.
                /// Doesn’t normalise the output.
                /// Authors: Sam Hocevar
                /// See_also: Source at $(WEB lolengine.net/blog/2013/09/21/picking-orthogonal-vector-combing-coconuts).
                @nogc Vector getOrthogonalVector() pure const nothrow
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
         ~ "alias " ~ type ~ "!double " ~ type ~ "d;\n";
}

template vec2(T) { alias Vector!(T, 2) vec2; }
template vec3(T) { alias Vector!(T, 3) vec3; }
template vec4(T) { alias Vector!(T, 4) vec4; }

mixin(definePostfixAliases("vec2"));
mixin(definePostfixAliases("vec3"));
mixin(definePostfixAliases("vec4"));


private
{
    static string generateLoopCode(string formatString, int N)() pure nothrow
    {
        string result;
        for (int i = 0; i < N; ++i)
        {
            string index = ctIntToString(i);
            // replace all @ by indices
            result ~= formatString.replace("@", index);
        }
        return result;
    }

    // Speed-up CTFE conversions
    static string ctIntToString(int n) pure nothrow
    {
        static immutable string[16] table = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];
        if (n < 10)
            return table[n];
        else
            return to!string(n);
    }
}


/// Element-wise minimum.
@nogc Vector!(T, N) min(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    import std.algorithm: min;
    Vector!(T, N) res = void;
    mixin(generateLoopCode!("res.v[@] = min(a.v[@], b.v[@]);", N)());
    return res;
}

/// Element-wise maximum.
@nogc Vector!(T, N) max(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    import std.algorithm: max;
    Vector!(T, N) res = void;
    mixin(generateLoopCode!("res.v[@] = max(a.v[@], b.v[@]);", N)());
    return res;
}

/// Returns: Dot product.
@nogc T dot(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    T sum = 0;
    mixin(generateLoopCode!("sum += a.v[@] * b.v[@];", N)());
    return sum;
}

/// Returns: 3D cross product.
/// Thanks to vuaru for corrections.
@nogc Vector!(T, 3) cross(T)(const Vector!(T, 3) a, const Vector!(T, 3) b) pure nothrow
{
    return Vector!(T, 3)(a.y * b.z - a.z * b.y,
                         a.z * b.x - a.x * b.z,
                         a.x * b.y - a.y * b.x);
}

/// 3D reflect, like the GLSL function.
/// Returns: a reflected by normal b.
@nogc Vector!(T, 3) reflect(T)(const Vector!(T, 3) a, const Vector!(T, 3) b) pure nothrow
{
    return a - (2 * dot(b, a)) * b;
}


/// Returns: angle between vectors.
/// See_also: "The Right Way to Calculate Stuff" at $(WEB www.plunk.org/~hatch/rightway.php)
@nogc T angleBetween(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
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

