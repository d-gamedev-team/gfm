module gfm.math.vector;

import std.traits,
       std.math,
       std.conv,
       std.array,
       std.string;

import gfm.math.funcs;

/**
 * Generic 1D small vector.
 * Params:
 *    N = number of elements
 *    T = type of elements
 */
struct Vector(T, int N)
{
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

        @nogc this(Args...)(Args args) pure nothrow
        {
            static if (args.length == 1)
            {
                // Construct a Vector from a single value.
                opAssign!(Args[0])(args[0]);
            }
            else
            {
                int index = 0;
                foreach(arg; args)
                {
                    static if (isAssignable!(T, typeof(arg)))
                    {
                        v[index] = arg;
                        index++; // has to be on its own line (DMD 2.068)
                    }
                    else static if (is(typeof(arg._isVector)) && isAssignable!(T, arg._T))
                    {
                        mixin(generateLoopCode!("v[index + @] = arg[@];", arg._N)());
                        index += arg._N;
                    }
                    else
                        static assert(false, "Unrecognized argument in Vector constructor");
                }
                assert(index == N, "Bad arguments in Vector constructor");
            }
        }

        /// Assign a Vector from a compatible type.
        @nogc ref Vector opAssign(U)(U x) pure nothrow if (isAssignable!(T, U))
        {
            mixin(generateLoopCode!("v[@] = x;", N)()); // copy to each component
            return this;
        }

        /// Assign a Vector with a static array type.
        @nogc ref Vector opAssign(U)(U arr) pure nothrow if ((isStaticArray!(U) && isAssignable!(T, typeof(arr[0])) && (arr.length == N)))
        {
            mixin(generateLoopCode!("v[@] = arr[@];", N)());
            return this;
        }

        /// Assign with a dynamic array.
        /// Size is checked in debug-mode.
        @nogc ref Vector opAssign(U)(U arr) pure nothrow if (isDynamicArray!(U) && isAssignable!(T, typeof(arr[0])))
        {
            assert(arr.length == N);
            mixin(generateLoopCode!("v[@] = arr[@];", N)());
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
                                                       && isAssignable!(T, U._T)
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
         ~ "alias " ~ type ~ "!real "  ~ type ~ "r;\n"
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
    import std.range : ElementType, hasLength, isInputRange;
    import std.typetuple : allSatisfy, staticMap;
    import std.traits : Unqual, isArray, isStaticArray, isMutable, CommonType, isFloatingPoint;
    template CommonElementType(T...)
    {
        static if (allArrays!T)
        {
            static if (T.length == 1)
            {
                alias CommonElementType = T[0];
            }
            else static if (T.length >= 2)
            {
                alias CommonElementType = CommonType!(staticMap!(ElementType, T));
            }
        }
        else
        {
            alias CommonElementType = void;
        }
    }

    template CommonArrayType(T...) if (T.length >= 2)
    {
        static if (allSatisfy!(isStaticArray, T))
        {
            alias CommonArrayType = CommonElementType!T[Longest!T.length];
        }
        else static if (allSatisfy!(isArray, T))
        {
            alias CommonArrayType = CommonElementType!T[];
        }
        else
        {
            alias CommonArrayType = void;
        }
    }

    /**
    Same as std.traits.Largest, but for length.
    */
    template Longest(T...) if (T.length >= 1 && allSatisfy!(hasLength, T))
    {
        static if (T.length == 1)
        {
            alias Longest = T[0];
        }
        else static if (T.length == 2)
        {
            static if (T[0].length >= T[1].length)
            {
                alias Longest = T[0];
            }
            else
            {
                alias Longest = T[1];
            }
        }
        else
        {
            alias Longest = Longest!(Longest!(T[0..$/2]), Longest!(T[$/2..$]));
        }
    }

    template Shortest(T...) if (T.length >= 1 && allSatisfy!(hasLength, T))
    {
        static if (T.length == 1)
        {
            alias Shortest = T[0];
        }
        else static if (T.length == 2)
        {
            static if (T[0].length <= T[1].length)
            {
                alias Shortest = T[0];
            }
            else
            {
                alias Shortest = T[1];
            }
        }
        else
        {
            alias Shortest = Shortest!(Shortest!(T[0..$/2]), Shortest!(T[$/2..$]));
        }
    }

    enum bool isVoid(T) = !is(T == void);
    
    enum bool allArrays(T...) = allSatisfy!(isArray, T);
    
    enum bool hasCommonElementType(T...) = allArrays!T && isVoid!(CommonElementType!T);
    
    enum bool hasCommonArrayType(T...) = allArrays!T && isVoid!(CommonArrayType!T);

    enum bool hasSameLength(T...) = is(Shortest!T == Longest!T);
    
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
    
    // Refer to arguments in argument list by index
    static string demux(string name = "a", size_t length = 1, string after = "") pure
    {
        import std.range : iota;
        import std.algorithm : map;
        import std.array : join;
        import std.conv : to;
        return iota(length).map!(a => name ~ "[" ~ a.to!string ~ "]" ~ after).join(", ");
    }
    static string defineFieldAccess(immutable string str)
    {
        import std.conv : to;
        import std.array : Appender;
        Appender!(dchar[]) app;
        foreach (size; 1..str.length+1)
        {
            foreach (i; 0..str.length-size+1)
            {
                size_t j = i + size;
                auto field = str[i..j];
                app.put("ref auto " ~ field ~ "(V)(ref V v) pure if (isStaticArray!V && V.length == " ~ str.length.to!string ~ ")\n");
                app.put("{ return v[");
                // Return slice if accessing more than one element, otherwise return single element
                if (size > 1)
                {
                    app.put(i.to!string ~ ".." ~ j.to!string);
                }
                else
                {
                    app.put(i.to!string);
                }
                app.put("]; }\n\n");
            }
        }
        return app.data.to!string;
    }
    
    // Pass parallel elements of static arrays to a function
    auto dive(alias fun, Arrays...)(Arrays arrays) pure if (allSatisfy!(isStaticArray, Arrays) && hasCommonElementType!Arrays)
    {
        import std.algorithm : map;
        import std.array : array, join;
        import std.range : iota;
        import std.conv : to;
        immutable string str = "return dive!fun(" ~ demux("arrays", Arrays.length, ".to!(CommonArrayType!Arrays).array") ~ ");";
        mixin(str);
    }
    
    // Pass parallel elements of ranges to a function
    auto dive(alias fun, Ranges...)(Ranges ranges) pure if (Ranges.length > 1 && allSatisfy!(isInputRange, Ranges))
    {
        import std.range : zip;
        import std.algorithm : map, reduce;
        return ranges.zip.map!(a => a.reduce!fun);
    }
}

mixin(defineFieldAccess("xy"));
mixin(defineFieldAccess("xyz"));
mixin(defineFieldAccess("wxyz"));
mixin(defineFieldAccess("wxyzt"));

// Unit test for static arrays
unittest
{
    import std.math : approxEqual;
    import std.algorithm : equal;
    
    const int[2] arr1 = [1, 2];
    int[3] arr2a = [4, 2, 6];
    long[3] arr2b = [1, 5, 3];
    real[3] arr2c = [1.2, 3.4, 5.6];
    int[5] arr3 = [10, 11, 12, 13, 14];
    
    // Test named element access
    
    assert(arr2a.x == 4);
    assert(arr2b.y == 5);
    assert(arr2c.z == 5.6);
    
    assert(arr2a.xy == [4, 2]);
    assert(arr2c.yz.approxEqual([3.4, 5.6]));
    
    assert(arr3.xyz == [11, 12, 13]);
    
    // Test vector operations
    
    assert(arr2a.minByElem(arr2b).equal([1, 2, 3]));
    assert(arr2a.minByElem(arr2c).approxEqual([1.2, 2, 5.6]));
    
    assert(arr2a.maxByElem(arr2b).equal([4, 5, 6]));
    assert(arr2a.maxByElem(arr2c).approxEqual([4, 3.4, 6]));
    
    assert(arr2a.dot(arr2b) == 32);
    assert(arr2a.dot(arr2c).approxEqual(45.2));
    
    assert(arr2a.squaredLength == 56);
    assert(arr2c.squaredLength.approxEqual(44.36));
    
    assert(arr2a.squaredDistanceTo(arr2b) == 27);
    assert(arr2a.squaredDistanceTo(arr2c).approxEqual(9.96));
    
    assert(arr2a.floatingLength.approxEqual(7.48331));
    assert(arr2c.floatingLength.approxEqual(6.66033));
    
    assert(arr2a.inverseLength.approxEqual(0.133631));
    assert(arr2c.inverseLength.approxEqual(0.150143));
    assert(arr2a.inverseLength!true.approxEqual(0.133631));
    assert(arr2c.inverseLength!true.approxEqual(0.150143));
    
    assert(arr1.distanceTo(arr2a) == 3);
    
    assert(arr2a.reflect(arr2b) == [-60, -318, -186]);
    assert(arr2a.reflect(arr2c)[].approxEqual([-104.48, -305.36, -500.24]));
    
    import std.conv : to;
    auto arr2cCopy = arr2c.dup.to!(typeof(arr2c));
    assert(arr2cCopy[].approxEqual([1.2, 3.4, 5.6]));
    arr2cCopy.normalize();
    assert(arr2cCopy[].approxEqual([0.180171, 0.510485, 0.840799]));
    arr2cCopy = arr2c.dup;
    assert(arr2cCopy[].approxEqual([1.2, 3.4, 5.6]));
    arr2cCopy.normalize!true();
    assert(arr2cCopy[].approxEqual([0.180171, 0.510485, 0.840799]));
    
    assert(arr2a.normalized[].approxEqual([0.534522, 0.267261, 0.801784]));
    assert(arr2a.normalized!true[].approxEqual([0.534522, 0.267261, 0.801784]));
    
    assert(arr2a.cross(arr2b) == [-24, -6, 18]);
    
    assert(arr2a.orthogonal == [0, -6, 2]);
    assert(arr2c.orthogonal[].approxEqual([0, -5.6, 3.4]));
    
    assert(arr2a.angleBetween(arr2b).approxEqual(0.762942));
    assert(arr2a.angleBetween(arr2c).approxEqual(0.434982));
}

/// Element-wise minimum.
deprecated("use minByElem instead") alias min = minByElem;
@nogc Vector!(T, N) minByElem(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    import std.algorithm: min;
    Vector!(T, N) res = void;
    mixin(generateLoopCode!("res.v[@] = min(a.v[@], b.v[@]);", N)());
    return res;
}
// For static arrays/ranges
auto minByElem(T...)(T t) pure if (hasCommonElementType!T)
{
    import std.algorithm : min;
    return t.dive!min;
}

/// Element-wise maximum.
deprecated("use maxByElem instead") alias max = maxByElem;
@nogc Vector!(T, N) maxByElem(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    import std.algorithm: max;
    Vector!(T, N) res = void;
    mixin(generateLoopCode!("res.v[@] = max(a.v[@], b.v[@]);", N)());
    return res;
}
// For static arrays/ranges
auto maxByElem(T...)(T t) pure if (hasCommonElementType!T)
{
    import std.algorithm : max;
    return t.dive!max;
}

/// Returns: Dot product.
@nogc T dot(T, int N)(const Vector!(T, N) a, const Vector!(T, N) b) pure nothrow
{
    T sum = 0;
    mixin(generateLoopCode!("sum += a.v[@] * b.v[@];", N)());
    return sum;
}
// For static arrays
auto dot(Arrays...)(Arrays arrays) pure if (allSatisfy!(isStaticArray, Arrays))
{
    import std.algorithm : reduce;
    import std.range : zip;
    import std.conv : to;
    import std.array : array;
    immutable string str = "return dot(" ~ demux("arrays", Arrays.length, ".to!(CommonArrayType!Arrays).array") ~ ");";
    mixin(str);
}
// For ranges
auto dot(Ranges...)(Ranges ranges) pure if (allSatisfy!(isInputRange, Ranges))
{
    import std.range : zip;
    import std.algorithm : map, reduce;
    return ranges.zip.map!(a => a.reduce!"a * b").reduce!"a + b";
}

/// Returns: 3D cross product.
/// Thanks to vuaru for corrections.
@nogc Vector!(T, 3) cross(T)(const Vector!(T, 3) a, const Vector!(T, 3) b) pure nothrow
{
    return Vector!(T, 3)(a.y * b.z - a.z * b.y,
                         a.z * b.x - a.x * b.z,
                         a.x * b.y - a.y * b.x);
}
// For static arrays
auto cross(A, B)(A a, B b) pure nothrow if (hasCommonArrayType!(A, B))
{
    CommonArrayType!(A, B) res = [a[1] * b[2] - a[2] * b[1],
                                  a[2] * b[0] - a[0] * b[2],
                                  a[0] * b[1] - a[1] * b[0]];
    return res;
}

/// 3D reflect, like the GLSL function.
/// Returns: a reflected by normal b.
@nogc Vector!(T, 3) reflect(T)(const Vector!(T, 3) a, const Vector!(T, 3) b) pure nothrow
{
    return a - (2 * dot(b, a)) * b;
}
// For static arrays
auto reflect(A, B)(A a, B b) pure if (allSatisfy!(isStaticArray, A, B))
in
{
	import std.algorithm : min;
    assert(min(a.length, b.length) >= 3);
}
body
{
    import std.conv : to;
    alias ReturnType = Unqual!(CommonArrayType!(A, B));
    ReturnType res;
    res[] = a.to!ReturnType[] - 2 * b.to!ReturnType[] * dot(b, a);
    return res;
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
// For static arrays
auto angleBetween(A, B)(A a, B b) if (allSatisfy!(isStaticArray, A, B))
{
    auto aN = a.normalized();
    auto bN = b.normalized();
    auto dp = dot(aN, bN);

    import std.math : asin, PI;
    import std.algorithm : max;
    CommonArrayType!(typeof(aN), typeof(bN)) temp;
    temp.length = max(a.length, b.length);
    if (dp < 0)
    {
        temp[] = -bN[]-aN[];
        return PI - 2 * asin(temp.floatingLength / 2);
    }
    else
    {
        temp[] = bN[]-aN[];
        return 2 * asin(temp.floatingLength / 2);
    }
}

auto squaredLength(V)(V v) pure nothrow
{
    static if (isStaticArray!V)
    {
        return v[].squaredLength;
    }
    else static if (isInputRange!V)
    {
        import std.algorithm : sum, map;
        return v.map!(a => a * a).sum;
    }
}

auto squaredDistanceTo(A, B)(A a, B b) pure if (hasCommonArrayType!(A, B))
{
    import std.conv : to;
    alias ReturnType = CommonArrayType!(A, B);
    ReturnType temp;
    static if (!isStaticArray!ReturnType)
    {
        import std.algorithm : max;
        temp.length = max(a.length, b.length);
    }
    temp[] = b.to!ReturnType[] - a.to!ReturnType[];
    return temp.squaredLength;
}

auto inverseLength(bool fast = false, FloatingType = real, V)(V v) pure nothrow @property if (isInputRange!V || isStaticArray!V)
{
    static if (fast)
    {
        return inverseSqrt(cast(FloatingType)v.squaredLength);
    }
    else
    {
        return cast(FloatingType)(1) / v.floatingLength;
    }
}

auto distanceTo(Lhs, Rhs)(Lhs lhs, Rhs rhs) if (allSatisfy!(isStaticArray, Lhs, Rhs))
{
    import std.array : array;
    return dive!"a - b"(rhs[], lhs[]).array.floatingLength;
}

FloatingType floatingLength(FloatingType = real, V)(V v) pure nothrow @property if (isStaticArray!V)
{
    return floatingLength(v[]);
}
FloatingType floatingLength(FloatingType = real, V)(V v) pure nothrow @property if (isInputRange!V)
{
    import std.math : sqrt;
    return sqrt(cast(FloatingType)v.squaredLength);
}

/**
Returns: Normalized vector v.
Parameters: fast - if should use SSE approximation,
            v - vector to normalize
*/
auto normalized(bool fast = false, FloatingType = real, V)(V v) pure if (isStaticArray!V)
{
    alias ReturnType = FloatingType[V.length];
    ReturnType res;
    import std.conv : to;
    res = v.to!ReturnType;
    return res.normalize!fast.dup;
}

/**
Normalizes vector v in place.
Returns: Reference to v
Parameters: fast - if should use SSE approximation,
            v - vector to normalize
*/
auto ref normalize(bool fast = false, V)(ref V v) pure if (isStaticArray!V && isMutable!V && isFloatingPoint!(ElementType!V))
{
    return v[] *= v.inverseLength!fast;
}

alias getOrthogonalVector = orthogonal;

auto orthogonal(V)(V v) pure nothrow if (V.length == 3)
{
    Unqual!V res = v.dup;
    import std.math : abs;
    if (v[0].abs > v[2].abs)
    {
        res[] = [-v[1], v[0], 0];
    }
    else
    {
        res[] = [0, -v[2], v[1]];
    }
    return res;
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

    // vectors of user-defined types
    import gfm.math.half;
    alias Vector!(half, 2) vec2h;
    vec2h k = vec2h(1.0f, 2.0f);

    // larger vectors
    alias Vector!(float, 5) vec5f;
    vec5f l = vec5f(1, 2.0f, 3.0, k.x.toFloat(), 5.0L);
    l = vec5f(l.xyz, vec2i(1, 2));
}
