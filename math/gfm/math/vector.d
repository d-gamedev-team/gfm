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

        @nogc inout(T)[] opIndex() pure inout nothrow
        {
            return this.v[];
        }

        @nogc ref inout(T) opIndex(size_t i) pure inout nothrow
        {
            return this.v[i];
        }

        @nogc inout(T)[] opIndex(size_t[2] s) pure inout nothrow
        {
            return this.v[s[0] .. s[1]];
        }

        @nogc T opIndexAssign(U : T)(U arg) pure nothrow
        {
            this.opIndexAssign!U(arg, [0, N]);
            return arg;
        }

        @nogc ref T opIndexAssign(U : T)(U arg, size_t i) pure nothrow
        {
            return this.v[i] = arg;
        }

        @nogc T opIndexAssign(V)(V arg, size_t[2] s) pure nothrow
        {
            size_t slice = s[1] - s[0];

            static if (is(V : Vector!(U, M), U, size_t M))
            {
                assert(slice == M, "Length mismatch in vector slice assignment.");

                foreach (i; 0 .. slice)
                    this.v[i + s[0]] = arg.v[i];
            }
            else static if (is(V : U[M], U, size_t M))
            {
                assert(slice == M, "Length mismatch in vector slice assignment.");

                foreach (i; 0 .. slice)
                    this.v[i + s[0]] = arg[i];
            }
            else static if (is(V : U[], U))
            {
                assert(slice == arg.length, "Length mismatch in vector slice assignment.");

                foreach (i; 0 .. slice)
                    this.v[i + s[0]] = arg[i];
            }
            else static if (isNumeric!V)
            {
                foreach (i; 0 .. slice)
                    this.v[i + s[0]] = arg;
            }
            else
                static assert(0, "Cannot apply operator \"" ~ op ~ "\" to types " ~ V.stringof ~ " and " ~ Vector.stringof);

            return this.v[s[0] .. s[1]];
        }

        static bool isValidSwizzle(const(char)[] swizzle) pure nothrow
        {
            ubyte n = cast(ubyte)clamp(N, 0, 4);
            const(char)[] xyzw = "xyzw"[0 .. n];
            const(char)[] rgba = "rgba"[0 .. n];
            const(char)[] stpq = "stpq"[0 .. n];

            import std.algorithm.searching;

            try
            {
                return swizzle.all!(e => xyzw.canFind(e)) ||
                       swizzle.all!(e => rgba.canFind(e)) ||
                       swizzle.all!(e => stpq.canFind(e));
            }
            catch (Exception)
                return false;
        }

        /// Returns: true if the swizzle has each letter no more than once
        static bool isUniqueSwizzle(const(char)[] swizzle) pure nothrow
        {
            ubyte n = cast(ubyte)clamp(N, 0, 4);
            const(char)[] xyzw = "xyzw"[0 .. n];
            const(char)[] rgba = "rgba"[0 .. n];
            const(char)[] stpq = "stpq"[0 .. n];

            import std.algorithm.searching;

            try
            {
                if (!swizzle.all!(e => xyzw.canFind(e)) &&
                    !swizzle.all!(e => rgba.canFind(e)) &&
                    !swizzle.all!(e => stpq.canFind(e)))
                     return false;
            }
            catch (Exception)
                return false;

            for (size_t i = 0; i < swizzle.length; i++)
            {
                for (size_t ii = i + 1; ii < swizzle.length; ii++)
                {
                    if (swizzle[i] == swizzle[ii])
                        return false;
                }
            }

            return true;
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
            static if (N >= 1 && name[0] == 'x' ||
                       N >= 2 && name[0] == 'y' ||
                       N >= 3 && name[0] == 'z' ||
                       N >= 4 && name[0] == 'w')
            {
                enum swizzleType = 1;
            }
            else static if (N >= 1 && name[0] == 'r' ||
                            N >= 2 && name[0] == 'g' ||
                            N >= 3 && name[0] == 'b' ||
                            N >= 4 && name[0] == 'a')
            {
                enum swizzleType = 2;
            }
            else static if (N >= 1 && name[0] == 's' ||
                            N >= 2 && name[0] == 't' ||
                            N >= 3 && name[0] == 'p' ||
                            N >= 4 && name[0] == 'q')
            {
                enum swizzleType = 3;
            }
            else
                static assert(0);

            Vector!(T, name.length) result = void;

            static if (swizzleType == 1)
            {
                static foreach (i, c; name)
                {
                    static if (N >= 1 && c == 'x')
                    {
                        result.v[i] = this.x;
                    }
                    else static if (N >= 2 && c == 'y')
                    {
                        result.v[i] = this.y;
                    }
                    else static if (N >= 3 && c == 'z')
                    {
                        result.v[i] = this.z;
                    }
                    else static if (N >= 4 && c == 'w')
                    {
                        result.v[i] = this.w;
                    }
                    else
                        static assert(0, "Invalid vector swizzle.");
                        // Silent error, need to fix the compiler
                }
            }
            else static if (swizzleType == 2)
            {
                static foreach (i, c; name)
                {
                    static if (N >= 1 && c == 'r')
                    {
                        result.v[i] = this.r;
                    }
                    else static if (N >= 2 && c == 'g')
                    {
                        result.v[i] = this.g;
                    }
                    else static if (N >= 3 && c == 'b')
                    {
                        result.v[i] = this.b;
                    }
                    else static if (N >= 4 && c == 'a')
                    {
                        result.v[i] = this.a;
                    }
                    else
                        static assert(0, "Invalid vector swizzle.");
                        // Silent error, need to fix the compiler
                }
            }
            else static if (swizzleType == 3)
            {
                static foreach (i, c; name)
                {
                    static if (N >= 1 && c == 's')
                    {
                        result.v[i] = this.s;
                    }
                    else static if (N >= 2 && c == 't')
                    {
                        result.v[i] = this.t;
                    }
                    else static if (N >= 3 && c == 'p')
                    {
                        result.v[i] = this.p;
                    }
                    else static if (N >= 4 && c == 'q')
                    {
                        result.v[i] = this.q;
                    }
                    else
                        static assert(0, "Invalid vector swizzle.");
                        // Silent error, need to fix the compiler
                }
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
        @nogc @property V opDispatch(string name, V : Vector!(U, M), U : T, size_t M)(V vec) pure nothrow
            if (name.length == M)
        {
            // TODO: Maybe support array overloads as well?

            static if (N >= 1 && name[0] == 'x' ||
                       N >= 2 && name[0] == 'y' ||
                       N >= 3 && name[0] == 'z' ||
                       N >= 4 && name[0] == 'w')
            {
                enum swizzleType = 1;
            }
            else static if (N >= 1 && name[0] == 'r' ||
                            N >= 2 && name[0] == 'g' ||
                            N >= 3 && name[0] == 'b' ||
                            N >= 4 && name[0] == 'a')
            {
                enum swizzleType = 2;
            }
            else static if (N >= 1 && name[0] == 's' ||
                            N >= 2 && name[0] == 't' ||
                            N >= 3 && name[0] == 'p' ||
                            N >= 4 && name[0] == 'q')
            {
                enum swizzleType = 3;
            }
            else
                static assert(0);

            static if (swizzleType == 1)
            {
                static foreach (i, c; name)
                {
                    static if (N >= 1 && c == 'x' && !is(typeof(sx)))
                    {
                        this.x = vec.v[i];
                        enum sx = true;
                    }
                    else static if (N >= 2 && c == 'y' && !is(typeof(sy)))
                    {
                        this.y = vec.v[i];
                        enum sy = true;
                    }
                    else static if (N >= 3 && c == 'z' && !is(typeof(sz)))
                    {
                        this.z = vec.v[i];
                        enum sz = true;
                    }
                    else static if (N >= 4 && c == 'w' && !is(typeof(sw)))
                    {
                        this.w = vec.v[i];
                        enum sw = true;
                    }
                    else
                        static assert(0, "Invalid vector swizzle.");
                        // Silent error, need to fix the compiler
                }
            }
            else static if (swizzleType == 2)
            {
                static foreach (i, c; name)
                {
                    static if (N >= 1 && c == 'r' && !is(typeof(sr)))
                    {
                        this.r = vec.v[i];
                        enum sr = true;
                    }
                    else static if (N >= 2 && c == 'g' && !is(typeof(sg)))
                    {
                        this.g = vec.v[i];
                        enum sg = true;
                    }
                    else static if (N >= 3 && c == 'b' && !is(typeof(sb)))
                    {
                        this.b = vec.v[i];
                        enum sb = true;
                    }
                    else static if (N >= 4 && c == 'a' && !is(typeof(sa)))
                    {
                        this.a = vec.v[i];
                        enum sa = true;
                    }
                    else
                        static assert(0, "Invalid vector swizzle.");
                        // Silent error, need to fix the compiler
                }
            }
            else static if (swizzleType == 3)
            {
                static foreach (i, c; name)
                {
                    static if (N >= 1 && c == 's' && !is(typeof(sa)))
                    {
                        this.s = vec.v[i];
                        enum ss = true;
                    }
                    else static if (N >= 2 && c == 't' && !is(typeof(st)))
                    {
                        this.t = vec.v[i];
                        enum st = true;
                    }
                    else static if (N >= 3 && c == 'p' && !is(typeof(sp)))
                    {
                        this.p = vec.v[i];
                        enum sp = true;
                    }
                    else static if (N >= 4 && c == 'q' && !is(typeof(sq)))
                    {
                        this.q = vec.v[i];
                        enum sq = true;
                    }
                    else
                        static assert(0, "Invalid vector swizzle.");
                        // Silent error, need to fix the compiler
                }
            }

            return vec;
        }

        /// Casting to small vectors of the same size.
        /// Example:
        /// ---
        /// vec4f vf;
        /// vec4d vd = cast!(vec4d)vf;
        /// ---
        @nogc V opCast(V : Vector!(U, N), U)() pure const nothrow
        {
            V result = void;

            foreach (i, e; this.v)
                result.v[i] = cast(U)e;

            return result;
        }

        /// Implement slices operator overloading.
        /// Allows to go back to slice world.
        /// Returns: length.
        @nogc @property size_t opDollar() pure const nothrow
        {
            return N;
        }

        /// vec[a..b]
        @nogc size_t[2] opSlice(size_t dim : 0)(size_t start, size_t end) pure const nothrow
        {
            return [start, end];
        }

        /// Squared Euclidean length of the Vector
        /// Returns: squared length.
        @nogc T squaredMagnitude() pure const nothrow
        {
            T sumSquares = 0;

            foreach (e; this.v)
                sumSquares += e * e;

            return sumSquares;
        }

        /// Squared Euclidean distance between this vector and another one
        /// Returns: squared Euclidean distance.
        @nogc T squaredDistanceTo(Vector vec) pure const nothrow
        {
            return cast(T)(vec - this).squaredMagnitude();
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
                T invMag = inverseMagnitude();

                foreach (ref e; this.v)
                    e *= invMag;
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
                T invLength = fastInverseMagnitude();
                foreach (ref e; this.v)
                    e *= invLength;
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
        alias _T = T;
    }
}

/// True if `T` is some kind of `Vector`
enum isVector(T) = is(T : Vector!U, U...);

///
unittest
{
    static assert( isVector!vec2f);
    static assert( isVector!vec3d);
    static assert( isVector!(vec4!real));
    static assert(!isVector!float);
}

/// Get the numeric type used to measure a vectors's coordinates.
alias DimensionType(T : Vector!(U, M), U, size_t M) = U;

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

/// Element-wise minimum.
@nogc Vector!(T, N) minByElem(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    import std.algorithm : min;
    Vector!(T, N) result = void;
    foreach (i; 0 .. N)
        result.v[i] = min(a.v[i], b.v[i]);
    return result;
}

/// Element-wise maximum.
@nogc Vector!(T, N) maxByElem(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    import std.algorithm: max;
    Vector!(T, N) result = void;
    foreach (i; 0 .. N)
        result.v[i] = max(a.v[i], b.v[i]);
    return result;
}

/// Element-wise absolute value.
@nogc Vector!(T, N) absByElem(T, int N)(const Vector!(T, N) a) pure nothrow
{
    Vector!(T, N) result = void;
    foreach (i; 0 .. N)
        result.v[i] = abs(a.v[i]);
    return result;
}

/// Dot product of two vectors
/// Returns: Dot product.
@nogc T dot(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    T sum = 0;
    foreach (i; 0 .. N)
        sum += a.v[i] * b.v[i];
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
    import core.exception;
    import std.exception;

    assert( vec2i.isValidSwizzle("xyx"));
    assert(!vec2i.isValidSwizzle("xyz"));
    assert( vec4i.isValidSwizzle("brra"));
    assert(!vec4i.isValidSwizzle("rgyz"));
    
    assert( vec2i.isUniqueSwizzle("xy"));
    assert( vec2i.isUniqueSwizzle("yx"));
    assert(!vec2i.isUniqueSwizzle("xx"));

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

    assert(vec2i(4, 5) + 1 == vec2i(5, 6));
    assert(vec2i(4, 5) - 1 == vec2i(3, 4));
    assert(1 + vec2i(4, 5) == vec2i(5, 6));
    assert(vec3f(1,1,1) * 0 == 0);
    assert(1.0 * vec3d(4,5,6) == vec3f(4, 5.0f, 6.0));

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
    static assert(!is(typeof(h.xx = h.yz)));
    vec4ub j;

    assert(lerp(vec2f(-10, -1), vec2f(10, 1), 0.5f) == vec2f(0, 0));

    // larger vectors
    alias Vector!(float, 5) vec5f;
    vec5f l = vec5f(1, 2.0f, 3.0, 4u, 5.0L);
    l = vec5f(l.xyz, vec2i(1, 2));

    // the ctor should not compile if given too many arguments
    static assert(!is(typeof(vec2f(1, 2, 3))));
    bool thrown = false;
    try
    {
        vec2f(vec2f(1, 2), 3);
    }
    catch (AssertError)
        thrown = true;
    assert(thrown); // Should throw

    vec3f(vec2f(1, 2), 3);
    vec3f(1, 2, 3);

    assert(absByElem(vec3i(-1, 0, 2)) == vec3i(1, 0, 2));
}
