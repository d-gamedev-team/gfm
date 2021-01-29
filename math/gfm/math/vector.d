/// N-dimension vector mathematical object
module gfm.math.vector;

import std.traits,
       std.math,
       std.conv,
       std.array,
       std.string;

import gfm.math.funcs;

/// Generic N-Dimensional vector.
/// Params:
///    T = type of elements
///    N = number of elements
struct Vector(T, ubyte N)
    if (isNumeric!T)
{
    public
    {
        static assert(N > 0);

        // fields definition
        union
        {
            T[N] v;
            struct
            {
                static if (N >= 1)
                {
                    T x;
                    alias r = x;
                    alias s = x;
                }
                static if (N >= 2)
                {
                    T y;
                    alias g = y;
                    alias t = y;
                }
                static if (N >= 3)
                {
                    T z;
                    alias b = z;
                    alias p = z;
                }
                static if (N >= 4)
                {
                    T w;
                    alias a = w;
                    alias q = w;
                }
            }
        }

        alias ElementType = T;
        enum ubyte elementCount = N;

        /// Construct a Vector with a `T[]` or the values as arguments
        this(Args...)(Args args) pure nothrow
        {
            static if (args.length == 1 && is(typeof(args[0]) : T))
            {
                foreach (i; 0 .. N)
                    this.v[i++] = args[0];
            }
            else static if (args.length > N)
            {
                // This doesn't cover every case but still useful
                static assert(0, "Too many elements in vector constructor.");
            }
            else
            {
                // We rely on compiler to unroll these loops
                size_t i = 0;
                foreach (arg; args)
                {
                    static if (is(typeof(arg) : Vector!(U, M), U : T, size_t M))
                    {
                        foreach (e; arg.v)
                        {
                            assert(i < N, "Too many elements in vector constructor.");
                            this.v[i++] = e;
                        }
                    }
                    else static if (is(typeof(arg) : U[M], U : T, size_t M) ||
                                    is(typeof(arg) : U[], U : T))
                    {
                        foreach (e; arg)
                        {
                            assert(i < N, "Too many elements in vector constructor.");
                            this.v[i++] = e;
                        }
                    }
                    else static if (is(typeof(arg) : T))
                    {
                        assert(i < N, "Too many elements in vector constructor.");
                        this.v[i++] = arg;
                    }
                    else
                        static assert(0, "Incompatible arguments in vector constructor.");
                }

                assert(i == N, "Not enough elements in vector constructor.");
            }
        }

        /// Assign a Vector from a compatible type.
        @nogc ref Vector opAssign(V)(V arg) pure nothrow
        {
            static if (is(V : Vector!(U, M), U : T, size_t M))
            {
                static assert(N == M, "Vector lengths don't match.");

                foreach (i, e; arg.v)
                    this.v[i] = e;
            }
            else static if (is(V : U[M], U : T, size_t M))
            {
                static assert(N == M, "Vector lengths don't match.");

                foreach (i, e; arg)
                    this.v[i] = e;
            }
            else static if (is(V : U[], U : T))
            {
                assert(N == arg.length, "Vector lengths don't match.");

                foreach (i, e; arg)
                    this.v[i] = e;
            }
            else static if (isNumeric!V)
            {
                foreach (i; 0 .. N)
                    this.v[i] = arg;
            }
            else
                static assert(0, "Cannot assign " ~ V.stringof ~ " to " ~ Vector.stringof);

            return this;
        }

        /// Returns: a pointer to content.
        @nogc inout(T)* ptr() pure inout nothrow @property
        {
            return this.v.ptr;
        }

        /// Converts to a pretty string.
        string toString() const nothrow
        {
            try
                return format("%s", this.v);
            catch (Exception e)
                assert(false); // should not happen since format is right
        }

        @nogc bool opEquals(V)(V arg) pure const nothrow
        {
            static if (is(V : Vector!(U, M), U, size_t M))
            {
                return this.v == arg.v;
            }
            else static if (is(V : U[M], U, size_t M) ||
                            is(V : U[], U))
            {
                return this.v == arg;
            }
            else static if (is(V : T))
            {
                foreach (e; this.v)
                    if (e != arg)
                        return false;
                return true;
            }
            else
                static assert(0, "Cannot check equality between " ~ V.stringof ~ " and " ~ Vector.stringof);
        }

        @nogc auto opUnary(string op)() pure const nothrow
            if (op == "+" || op == "-" || op == "~" || op == "!")
        {
            alias U = Unqual!(typeof(mixin(op ~ "this.x")));
            Vector!(U, N) result = void;

            foreach (i, e; this.v)
                mixin("result.v[i] = " ~ op ~ "e;");

            return result;
        }

        @nogc ref Vector opOpAssign(string op, V)(V arg) pure nothrow
        {
            static if (is(V : Vector!(U, M), U, size_t M))
            {
                static assert(N == M, "Vector lengths don't match.");

                foreach (i, e; arg.v)
                    mixin("this.v[i] " ~ op ~ "= e;");
            }
            else static if (is(V : U[M], U, size_t M))
            {
                static assert(N == M, "Vector and array lengths don't match.");

                foreach (i, e; arg)
                    mixin("this.v[i] " ~ op ~ "= e;");
            }
            else static if (is(V : U[], U))
            {
                assert(N == arg.length, "Vector and array lengths don't match.");

                foreach (i, e; arg)
                    mixin("this.v[i] " ~ op ~ "= e;");
            }
            else static if (isNumeric!V)
            {
                foreach (i; 0 .. N)
                    mixin("this.v[i] " ~ op ~ "= arg;");
            }
            else
                static assert(0, "Cannot apply operator \"" ~ op ~ "\" to types " ~ V.stringof ~ " and " ~ Vector.stringof);

            return this;
        }

        @nogc auto opBinary(string op, V)(V arg) pure const nothrow
        {
            static if (is(V : Vector!(U, M), U, size_t M))
            {
                static assert(N == M, "Vector lengths don't match.");

                alias E = Unqual!(typeof(mixin("this.v[0] " ~ op ~ " arg.v[0]")));
                Vector!(E, N) result = void;

                foreach (i, e; arg.v)
                    mixin("result.v[i] = this.v[i] " ~ op ~ " e;");
            }
            else static if (is(V : U[M], U, size_t M))
            {
                static assert(N == M, "Vector and array lengths don't match.");

                alias E = Unqual!(typeof(mixin("this.v[0] " ~ op ~ " arg[0]")));
                Vector!(E, N) result = void;

                foreach (i, e; arg)
                    mixin("result.v[i] = this.v[i] " ~ op ~ " e;");
            }
            else static if (is(V : U[], U))
            {
                assert(N == arg.length, "Vector and array lengths don't match.");

                alias E = Unqual!(typeof(mixin("this.v[0] " ~ op ~ " arg[0]")));
                Vector!(E, N) result = void;

                foreach (i, e; arg)
                    mixin("result.v[i] = this.v[i] " ~ op ~ " e;");
            }
            else static if (isNumeric!V)
            {
                alias E = Unqual!(typeof(mixin("this.v[0] " ~ op ~ " arg")));
                Vector!(E, N) result = void;

                foreach (i; 0 .. N)
                    mixin("result.v[i] = this.v[i] " ~ op ~ " arg;");
            }
            else
                static assert(0, "Cannot apply operator \"" ~ op ~ "\" to types " ~ V.stringof ~ " and " ~ Vector.stringof);

            return result;
        }

        @nogc auto opBinaryRight(string op, V)(V arg) pure const nothrow
        {
            // Don't need is(V : Vector!(U, M)) branch because the compiler tries both opBinary and opBinaryRight

            static if (is(V : U[M], U, size_t M))
            {
                static assert(N == M, "Vector and array lengths don't match.");

                alias E = Unqual!(typeof(mixin("arg[0] " ~ op ~ " this.v[0]")));
                Vector!(E, N) result = void;

                foreach (i, e; arg)
                    mixin("result.v[i] = e " ~ op ~ " this.v[i];");
            }
            else static if (is(V : U[], U))
            {
                assert(N == arg.length, "Vector and array lengths don't match.");

                alias E = Unqual!(typeof(mixin("arg[0] " ~ op ~ " this.v[0]")));
                Vector!(E, N) result = void;

                foreach (i, e; arg)
                    mixin("result.v[i] = e " ~ op ~ " this.v[i];");
            }
            else static if (isNumeric!V)
            {
                alias E = Unqual!(typeof(mixin("arg " ~ op ~ " this.v[0]")));
                Vector!(E, N) result = void;

                foreach (i; 0 .. N)
                    mixin("result.v[i] = arg " ~ op ~ " this.v[i];");
            }
            else
                static assert(0, "Cannot apply operator \"" ~ op ~ "\" to types " ~ Vector.stringof ~ " and " ~ V.stringof);

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
        @nogc @property auto opDispatch(string name)() pure const nothrow
            if (name.length > 1)
        {
            Vector!(T, name.length) result = void;

            static foreach (i, c; name)
            {
                static if (c == 'x')
                {
                    result.v[i] = this.x;
                }
                else static if (c == 'y')
                {
                    result.v[i] = this.y;
                }
                else static if (c == 'z')
                {
                    result.v[i] = this.z;
                }
                else static if (c == 'w')
                {
                    result.v[i] = this.w;
                }
                else
                    static assert(0, "Invalid vector swizzle.");
                    // Silent error, need to fix the compiler
            }

            return result;
        }

        @nogc @property auto opDispatch(string name)() pure const nothrow
            if (name.length > 1)
        {
            Vector!(T, name.length) result = void;

            static foreach (i, c; name)
            {
                static if (c == 'r')
                {
                    result.v[i] = this.r;
                }
                else static if (c == 'g')
                {
                    result.v[i] = this.g;
                }
                else static if (c == 'b')
                {
                    result.v[i] = this.b;
                }
                else static if (c == 'a')
                {
                    result.v[i] = this.a;
                }
                else
                    static assert(0, "Invalid vector swizzle.");
                    // Silent error, need to fix the compiler
            }

            return result;
        }

        @nogc @property auto opDispatch(string name)() pure const nothrow
            if (name.length > 1)
        {
            Vector!(T, name.length) result = void;

            static foreach (i, c; name)
            {
                static if (c == 's')
                {
                    result.v[i] = this.s;
                }
                else static if (c == 't')
                {
                    result.v[i] = this.t;
                }
                else static if (c == 'p')
                {
                    result.v[i] = this.p;
                }
                else static if (c == 'q')
                {
                    result.v[i] = this.q;
                }
                else
                    static assert(0, "Invalid vector swizzle.");
                    // Silent error, need to fix the compiler
            }

            return result;
        }

        /// Support swizzling assignment like in shader languages.
        ///
        /// Example:
        /// ---
        /// vec3f v = [0, 1, 2];
        /// v.yz = v.zx;
        /// assert(v == [0, 2, 0]);
        /// ---
        @nogc @property void opDispatch(string name, U, size_t M)(Vector!(U, M) vec) pure
            if (name.length == M)
        {
            static foreach (i, c; name)
            {
                static if (c == 'x')
                {
                    this.x = vec.v[i];
                }
                else static if (c == 'y')
                {
                    this.y = vec.v[i];
                }
                else static if (c == 'z')
                {
                    this.z = vec.v[i];
                }
                else static if (c == 'w')
                {
                    this.w = vec.v[i];
                }
                else
                    static assert(0, "Invalid vector swizzle.");
                    // Silent error, need to fix the compiler
            }
        }

        @nogc @property void opDispatch(string name, U, size_t M)(Vector!(U, M) vec) pure
            if (name.length == M)
        {
            static foreach (i, c; name)
            {
                static if (c == 'r')
                {
                    this.x = vec.v[i];
                }
                else static if (c == 'g')
                {
                    this.y = vec.v[i];
                }
                else static if (c == 'b')
                {
                    this.z = vec.v[i];
                }
                else static if (c == 'a')
                {
                    this.w = vec.v[i];
                }
                else
                    static assert(0, "Invalid vector swizzle.");
                    // Silent error, need to fix the compiler
            }
        }

        @nogc @property void opDispatch(string name, U, size_t M)(Vector!(U, M) vec) pure
            if (name.length == M)
        {
            static foreach (i, c; name)
            {
                static if (c == 's')
                {
                    this.x = vec.v[i];
                }
                else static if (c == 't')
                {
                    this.y = vec.v[i];
                }
                else static if (c == 'p')
                {
                    this.z = vec.v[i];
                }
                else static if (c == 'q')
                {
                    this.w = vec.v[i];
                }
                else
                    static assert(0, "Invalid vector swizzle.");
                    // Silent error, need to fix the compiler
            }
        }

        /// Casting to small vectors of the same size.
        /// Example:
        /// ---
        /// vec4f vf;
        /// vec4d vd = cast!(vec4d)vf;
        /// ---
        @nogc U opCast(U)() pure const nothrow if (isVector!U && (U._N == _N))
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

        /// Slice containing vector values
        /// Returns: a slice which covers the whole Vector.
        @nogc T[] opSlice() pure nothrow
        {
            return v[];
        }

        /// vec[a..b]
        @nogc T[] opSlice(int a, int b) pure nothrow
        {
            return v[a..b];
        }

        /// Squared Euclidean length of the Vector
        /// Returns: squared length.
        @nogc T squaredMagnitude() pure const nothrow
        {
            T sumSquares = 0;
            mixin(generateLoopCode!("sumSquares += v[@] * v[@];", N)());
            return sumSquares;
        }

        /// Squared Euclidean distance between this vector and another one
        /// Returns: squared Euclidean distance.
        @nogc T squaredDistanceTo(Vector v) pure const nothrow
        {
            return (v - this).squaredMagnitude();
        }

        static if (isFloatingPoint!T)
        {
            /// Euclidean length of the vector
            /// Returns: Euclidean length
            @nogc T magnitude() pure const nothrow
            {
                return sqrt(squaredMagnitude());
            }

            /// Inverse Euclidean length of the vector
            /// Returns: Inverse of Euclidean length.
            @nogc T inverseMagnitude() pure const nothrow
            {
                return 1 / sqrt(squaredMagnitude());
            }

            alias fastInverseLength = fastInverseMagnitude;
            /// Faster but less accurate inverse of Euclidean length.
            /// Returns: Inverse of Euclidean length.
            @nogc T fastInverseMagnitude() pure const nothrow
            {
                return inverseSqrt(squaredMagnitude());
            }

            /// Euclidean distance between this vector and another one
            /// Returns: Euclidean distance between this and other.
            @nogc T distanceTo(Vector other) pure const nothrow
            {
                return (other - this).magnitude();
            }

            /// In-place normalization.
            @nogc void normalize() pure nothrow
            {
                auto invMag = inverseMagnitude();
                mixin(generateLoopCode!("v[@] *= invMag;", N)());
            }

            /// Returns a normalized copy of this Vector
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
                auto invLength = fastInverseMagnitude();
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
                /// Doesn’t normalize the output.
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
    }
}

/// True if `T` is some kind of `Vector`
enum isVector(T) = is(T : Vector!U, U...);

///
unittest
{
    static assert(isVector!vec2f);
    static assert(isVector!vec3d);
    static assert(isVector!(vec4!real));
    static assert(!isVector!float);
}

/// Get the numeric type used to measure a vectors's coordinates.
alias DimensionType(T : Vector!U, U...) = U[0];

///
unittest
{
    static assert(is(DimensionType!vec2f == float));
    static assert(is(DimensionType!vec3d == double));
}

///
template vec2(T) { alias Vector!(T, 2) vec2; }
///
template vec3(T) { alias Vector!(T, 3) vec3; }
///
template vec4(T) { alias Vector!(T, 4) vec4; }

alias vec2!int    vec2i;  ///
alias vec2!float  vec2f;  ///
alias vec2!double vec2d;  ///

alias vec3!int    vec3i;  ///
alias vec3!float  vec3f;  ///
alias vec3!double vec3d;  ///

alias vec4!int    vec4i;  ///
alias vec4!float  vec4f;  ///
alias vec4!double vec4d;  ///

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
@nogc Vector!(T, N) minByElem(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    import std.algorithm: min;
    Vector!(T, N) res = void;
    mixin(generateLoopCode!("res.v[@] = min(a.v[@], b.v[@]);", N)());
    return res;
}

/// Element-wise maximum.
@nogc Vector!(T, N) maxByElem(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    import std.algorithm: max;
    Vector!(T, N) res = void;
    mixin(generateLoopCode!("res.v[@] = max(a.v[@], b.v[@]);", N)());
    return res;
}

/// Element-wise absolute value.
@nogc Vector!(T, N) absByElem(T, int N)(const Vector!(T, N) a) pure nothrow
{
    Vector!(T, N) res = void;
    mixin(generateLoopCode!("res.v[@] = abs(a.v[@]);", N)());
    return res;
}

/// Dot product of two vectors
/// Returns: Dot product.
@nogc T dot(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    T sum = 0;
    mixin(generateLoopCode!("sum += a.v[@] * b.v[@];", N)());
    return sum;
}

/// Cross product of two 3D vectors
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
@nogc Vector!(T, N) reflect(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    return a - (2 * dot(b, a)) * b;
}

///
@nogc unittest
{
    // reflect a 2D vector across the x axis (the normal points along the y axis)
    assert(vec2f(1,1).reflect(vec2f(0,1)) == vec2f(1,-1));
    assert(vec2f(1,1).reflect(vec2f(0,-1)) == vec2f(1,-1));

    // note that the normal must be, well, normalized:
    assert(vec2f(1,1).reflect(vec2f(0,20)) != vec2f(1,-1));

    // think of this like a ball hitting a flat floor at an angle.
    // the x and y components remain unchanged, and the z inverts
    assert(vec3f(2,3,-0.5).reflect(vec3f(0,0,1)) == vec3f(2,3,0.5));
}

/// Angle between two vectors
/// Returns: angle between vectors.
/// See_also: "The Right Way to Calculate Stuff" at $(WEB www.plunk.org/~hatch/rightway.php)
@nogc T angleBetween(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    auto aN = a.normalized();
    auto bN = b.normalized();
    auto dp = dot(aN, bN);

    if (dp < 0)
        return T(PI) - 2 * asin((-bN-aN).magnitude / 2);
    else
        return 2 * asin((bN-aN).magnitude / 2);
}

static assert(vec2f.sizeof == 8);
static assert(vec3d.sizeof == 24);
static assert(vec4i.sizeof == 16);

unittest
{
    static assert(vec2i.isValidSwizzle!"xyx");
    static assert(!vec2i.isValidSwizzle!"xyz");
    static assert(vec4i.isValidSwizzle!"brra");
    static assert(!vec4i.isValidSwizzle!"rgyz");
    static assert(vec2i.isValidSwizzleUnique!"xy");
    static assert(vec2i.isValidSwizzleUnique!"yx");
    static assert(!vec2i.isValidSwizzleUnique!"xx");

    alias vec2l = vec2!long;
    alias vec3ui = vec3!uint;
    alias vec4ub = vec4!ubyte;

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
    x = vec4i(x.xyz, 166);
    assert(x == [4, 1, 83, 166]);

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

    // larger vectors
    alias Vector!(float, 5) vec5f;
    vec5f l = vec5f(1, 2.0f, 3.0, 4u, 5.0L);
    l = vec5f(l.xyz, vec2i(1, 2));

    // the ctor should not compile if given too many arguments
    static assert(!is(typeof(vec2f(1, 2, 3))));
    static assert(!is(typeof(vec2f(vec2f(1, 2), 3))));
    static assert( is(typeof(vec3f(vec2f(1, 2), 3))));
    static assert( is(typeof(vec3f(1, 2, 3))));

    assert(absByElem(vec3i(-1, 0, 2)) == vec3i(1, 0, 2));
}

