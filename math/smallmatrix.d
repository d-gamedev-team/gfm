module gfm.math.smallmatrix;

import std.math;
import std.typetuple;
import std.traits;
import std.typecons;
import std.conv;
import gfm.math.smallvector;

// generic small non-resizeable matrix with R rows and C columns
// N is the element count, T the contained type
// intended for 3D (mainly size 3x3 and 4x4)
// IMPORTANT: matrices here are in ROW-MAJOR order
// while OpenGL is column-major

// TODO: - do we need constructor from columns ?
//       - invert square matrices

align(1) struct SmallMatrix(size_t R, size_t C, T)
{
    public
    {
        static assert(R >= 1u && C >= 1u);

        alias SmallVector!(C, T) row_t;
        alias SmallVector!(R, T) column_t;

        enum bool isSquare = (R == C);
        enum numRows = R;
        enum numColumns = C;

        // fields definition
        union
        {
            T[C*R] v;        // all elements
            row_t[R] rows;   // all rows
            T[C][R] c;       // components
        }

        this(U...)(U values) pure
        {
            static if ((U.length == C*R) && allSatisfy!(isTConvertible, U))
            {
                // construct with components
                foreach(int i, x; values)
                    v[i] = x;
            }
            else static if ((U.length == 1) && (isAssignable!(U[0])) && (!is(U[0] : SmallMatrix)))
            {
                // construct with assignment
                opAssign!(U[0])(values[0]);
            }
            else static assert(false, "cannot create a matrix from given arguments");
        }

        // construct with columns
        static SmallMatrix fromColumns(column_t[] columns...)
        {
            SmallMatrix res = void;
            for (size_t i = 0; i < R; ++i)
                for (size_t j = 0; j < C; ++j)
                {
                   res.c[i][j] = columns[j][i];
                }
            return res;
        }

        static SmallMatrix fromRows(row_t[] rows...)
        {
            SmallMatrix res = void;
            res.rows[] = rows[];
            return res;
        }

        // construct with scalar
        this(U)(T x)
        {
            for (size_t i = 0; i < _N; ++i)
                v[i] = x;
        }

        // assign with same type
        void opAssign(U : SmallMatrix)(U x) pure
        {
            for (size_t i = 0; i < _N; ++i)
            {
                v[i] = x.v[i];
            }
        }

        // other small matrices (same size, compatible type)
        void opAssign(U)(U x) pure nothrow
            if (is(typeof(U._isSmallMatrix))
                && is(U._T : _T)
                && (!is(U: SmallMatrix))
                && (U._R == _R) && (U._C == _C))
        {
            for (size_t i = 0; i < _N; ++i)
                v[i] = x.v[i];
        }

        // cast to other small matrices type (compatible size)
        U opCast(U)() pure nothrow const if (is(typeof(U._isSmallVector)) && (U._R == _R) && (U._C == _C))
        {
            U res = void;
            for (size_t i = 0; i < _N; ++i)
                res.v[i] = cast(U._T)v[i];
            return res;
        }

        // assign with a static array of size R * C
        void opAssign(U)(U x) pure nothrow
            if ((isStaticArray!U)
                && is(typeof(x[0]) : T)
                && (U.length == _N))
        {
            for (size_t i = 0; i < _N; ++i)
                v[i] = x[i];
        }

        // assign with a dynamic array of size R * C
        void opAssign(U)(U x) pure nothrow
            if ((isDynamicArray!U)
                && is(typeof(x[0]) : T))
        {
            assert(x.length == _N);
            for (size_t i = 0; i < _N; ++i)
                v[i] = x[i];
        }

        column_t column(size_t j) pure const
        {
            column_t res = void;
            for (size_t i = 0; i < R; ++i)
            {
                res[i] = c[i][j];
            }
            return res;
        }

        row_t row(size_t i) pure const
        {
            return rows[i];
        }

        // matrix * vector
        column_t opBinary(string op)(row_t x) if (op == "*")
        {
            column_t res = void;
            for (size_t i = 0; i < R; ++i)
            {
                T sum = 0;
                for (size_t j = 0; j < C; ++j)
                {
                    sum += c[i][j] * x[j];
                }
                res[i] = sum;
            }
            return res;
        }

        // matrix * matrix
        auto opBinary(string op, U)(U x)
            if (is(typeof(U._isSmallMatrix))
                && (U._R == C)
                && (op == "*"))
        {
            SmallMatrix!(R, U._C, T) result = void;

            for (size_t i = 0; i < R; ++i)
            {
                for (size_t j = 0; j < U._C; ++j)
                {
                    T sum = 0;
                    for (size_t k = 0; k < C; ++k)
                        sum += c[i][k] * x.c[k][j];
                    result.c[i][j] = sum;
                }
            }
            return result;
        }

        ref SmallVector opOpAssign(string op, U)(U operand) pure if (isConvertible!U)
        {
            SmallVector conv = operand;
            return opOpAssign!op(conv);
        }

        // casting to matrices of the same size
        U opCast(U)() pure const if (is(typeof(U._isSmallMatrix)) && (U._R == _R) && (U._C == C))
        {
            U res = void;
            for (size_t i = 0; i < _N; ++i)
                res.v[i] = cast(U._T)v[i];
            return res;
        }

        bool opEquals(U)(U other) pure const if (is(U : SmallMatrix))
        {
            for (size_t i = 0; i < _N; ++i)
                if (v[i] != other.v[i])
                    return false;
            return true;
        }

        bool opEquals(U)(U other) pure const
            if ((isAssignable!U) && (!is(U: SmallMatrix)))
        {
            SmallMatrix conv = other;
            return opEquals(conv);
        }

        // +matrix, -matrix, ~matrix, !matrix
        SmallMatrix opUnary(string op)() pure const if (op == "+" || op == "-" || op == "~" || op == "!")
        {
            SmallMatrix res = void;
            for (size_t i = 0; i < N; ++i)
                mixin("res.v[i] = " ~ op ~ "v[i];");
            return res;
        }

        // matrix inversion, provided for 2x2, 3x3 and 4x4 floating point matrices
        static if (isSquare && isFloatingPoint!T && _R == 2)
        {
            SmallMatrix inverse()
            {
                T invDet = 1 / (c[0][0] * c[1][1] - c[0][1] * c[1][0]);
                return SmallMatrix( c[1][1] * invDet, -c[0][1] * invDet,
                                   -c[1][0] * invDet,  c[0][0] * invDet);
            }
        }

        static if (isSquare && isFloatingPoint!T && _R == 3)
        {
            SmallMatrix inverse()
            {
                T det = c[0][0] * (c[1][1] * c[2][2] - c[2][1] * c[1][2])
                      - c[0][1] * (c[1][0] * c[2][2] - c[1][2] * c[2][0])
                      + c[0][2] * (c[1][0] * c[2][1] - c[1][1] * c[2][0]);
                T invDet = 1 / det;

                SmallMatrix res = void;
                res.c[0][0] =  (c[1][1] * c[2][2] - c[2][1] * c[1][2]) * invDet;
                res.c[0][1] = -(c[0][1] * c[2][2] - c[0][2] * c[2][1]) * invDet;
                res.c[0][2] =  (c[0][1] * c[1][2] - c[0][2] * c[1][1]) * invDet;
                res.c[1][0] = -(c[1][0] * c[2][2] - c[1][2] * c[2][0]) * invDet;
                res.c[1][1] =  (c[0][0] * c[2][2] - c[0][2] * c[2][0]) * invDet;
                res.c[1][2] = -(c[0][0] * c[1][2] - c[1][0] * c[0][2]) * invDet;
                res.c[2][0] =  (c[1][0] * c[2][1] - c[2][0] * c[1][1]) * invDet;
                res.c[2][1] = -(c[0][0] * c[2][1] - c[2][0] * c[0][1]) * invDet;
                res.c[2][2] =  (c[0][0] * c[1][1] - c[1][0] * c[0][1]) * invDet;
                return res;
            }
        }

        static if (isSquare && isFloatingPoint!T && _R == 4)
        {
            SmallMatrix inverse()
            {
                T det2_01_01 = c[0][0] * c[1][1] - c[0][1] * c[1][0];
                T det2_01_02 = c[0][0] * c[1][2] - c[0][2] * c[1][0];
                T det2_01_03 = c[0][0] * c[1][3] - c[0][3] * c[1][0];
                T det2_01_12 = c[0][1] * c[1][2] - c[0][2] * c[1][1];
                T det2_01_13 = c[0][1] * c[1][3] - c[0][3] * c[1][1];
                T det2_01_23 = c[0][2] * c[1][3] - c[0][3] * c[1][2];

                T det3_201_012 = c[2][0] * det2_01_12 - c[2][1] * det2_01_02 + c[2][2] * det2_01_01;
                T det3_201_013 = c[2][0] * det2_01_13 - c[2][1] * det2_01_03 + c[2][3] * det2_01_01;
                T det3_201_023 = c[2][0] * det2_01_23 - c[2][2] * det2_01_03 + c[2][3] * det2_01_02;
                T det3_201_123 = c[2][1] * det2_01_23 - c[2][2] * det2_01_13 + c[2][3] * det2_01_12;

                T det = - det3_201_123 * c[3][0] + det3_201_023 * c[3][1] - det3_201_013 * c[3][2] + det3_201_012 * c[3][3];
                T invDet = 1 / det;

                T det2_03_01 = c[0][0] * c[3][1] - c[0][1] * c[3][0];
                T det2_03_02 = c[0][0] * c[3][2] - c[0][2] * c[3][0];
                T det2_03_03 = c[0][0] * c[3][3] - c[0][3] * c[3][0];
                T det2_03_12 = c[0][1] * c[3][2] - c[0][2] * c[3][1];
                T det2_03_13 = c[0][1] * c[3][3] - c[0][3] * c[3][1];
                T det2_03_23 = c[0][2] * c[3][3] - c[0][3] * c[3][2];
                T det2_13_01 = c[1][0] * c[3][1] - c[1][1] * c[3][0];
                T det2_13_02 = c[1][0] * c[3][2] - c[1][2] * c[3][0];
                T det2_13_03 = c[1][0] * c[3][3] - c[1][3] * c[3][0];
                T det2_13_12 = c[1][1] * c[3][2] - c[1][2] * c[3][1];
                T det2_13_13 = c[1][1] * c[3][3] - c[1][3] * c[3][1];
                T det2_13_23 = c[1][2] * c[3][3] - c[1][3] * c[3][2];

                T det3_203_012 = c[2][0] * det2_03_12 - c[2][1] * det2_03_02 + c[2][2] * det2_03_01;
                T det3_203_013 = c[2][0] * det2_03_13 - c[2][1] * det2_03_03 + c[2][3] * det2_03_01;
                T det3_203_023 = c[2][0] * det2_03_23 - c[2][2] * det2_03_03 + c[2][3] * det2_03_02;
                T det3_203_123 = c[2][1] * det2_03_23 - c[2][2] * det2_03_13 + c[2][3] * det2_03_12;

                T det3_213_012 = c[2][0] * det2_13_12 - c[2][1] * det2_13_02 + c[2][2] * det2_13_01;
                T det3_213_013 = c[2][0] * det2_13_13 - c[2][1] * det2_13_03 + c[2][3] * det2_13_01;
                T det3_213_023 = c[2][0] * det2_13_23 - c[2][2] * det2_13_03 + c[2][3] * det2_13_02;
                T det3_213_123 = c[2][1] * det2_13_23 - c[2][2] * det2_13_13 + c[2][3] * det2_13_12;

                T det3_301_012 = c[3][0] * det2_01_12 - c[3][1] * det2_01_02 + c[3][2] * det2_01_01;
                T det3_301_013 = c[3][0] * det2_01_13 - c[3][1] * det2_01_03 + c[3][3] * det2_01_01;
                T det3_301_023 = c[3][0] * det2_01_23 - c[3][2] * det2_01_03 + c[3][3] * det2_01_02;
                T det3_301_123 = c[3][1] * det2_01_23 - c[3][2] * det2_01_13 + c[3][3] * det2_01_12;

                SmallMatrix res = void;
                res.c[0][0] = - det3_213_123 * invDet;
                res.c[1][0] = + det3_213_023 * invDet;
                res.c[2][0] = - det3_213_013 * invDet;
                res.c[3][0] = + det3_213_012 * invDet;

                res.c[0][1] = + det3_203_123 * invDet;
                res.c[1][1] = - det3_203_023 * invDet;
                res.c[2][1] = + det3_203_013 * invDet;
                res.c[3][1] = - det3_203_012 * invDet;

                res.c[0][2] = + det3_301_123 * invDet;
                res.c[1][2] = - det3_301_023 * invDet;
                res.c[2][2] = + det3_301_013 * invDet;
                res.c[3][2] = - det3_301_012 * invDet;

                res.c[0][3] = - det3_201_123 * invDet;
                res.c[1][3] = + det3_201_023 * invDet;
                res.c[2][3] = - det3_201_013 * invDet;
                res.c[3][3] = + det3_201_012 * invDet;
                return res;
            }
        }

        static if (isSquare && _R > 1)
        {
            // translation matrix
            static SmallMatrix makeTranslate(SmallVector!(_R-1, T) v)
            {
                SmallMatrix res = IDENTITY;
                for (size_t i = 0; i + 1 < _R; ++i)
                    res.c[i][_C-1] += v[i];
                return res;
            }

            // scale matrix
            static SmallMatrix makeScale(SmallVector!(_R-1, T) v)
            {
                SmallMatrix res = IDENTITY;
                for (size_t i = 0; i + 1 < _R; ++i)
                    res.c[i][_C-1] = v[i];
                return res;
            }
        }

        // more operations for 4x4 matrices
        static if (isSquare && _R == 4 && isFloatingPoint!T)
        {
            // rotations
            SmallMatrix rotateX(T angle)
            {
                T cosa = cos(angle);
                T sina = sin(angle);
                return SmallMatrix(1,    0,     0, 0,
                                   0, cosa, -sina, 0,
                                   0, sina,  cosa, 0,
                                   0,    0,     0, 1);
            }

            SmallMatrix rotateY(T angle)
            {
                T cosa = cos(angle);
                T sina = sin(angle);
                return SmallMatrix(cosa, 0, -sina, 0,
                                   0,    1,     0, 0,
                                   sina, 0,  cosa, 0,
                                   0,    0,     0, 1);
            }

            SmallMatrix rotateZ(T angle)
            {
                T cosa = cos(angle);
                T sina = sin(angle);
                return SmallMatrix(cosa, -sina, 0, 0,
                                   sina,  cosa, 0, 0,
                                      0,     0, 1, 0,
                                      0,     0, 0, 1);
            }
        }
    }

    private
    {
        alias T _T;
        enum _N = R * C;
        enum _R = R;
        enum _C = C;
        enum bool _isSmallMatrix = true;

        template isAssignable(T)
        {
            enum bool isAssignable =
                is(typeof(
                {
                    T x;
                    SmallMatrix m = x;
                }()));
        }

        template isTConvertible(U)
        {
            enum bool isTConvertible = is(U : T);
        }

        template isRowConvertible(U)
        {
            enum bool isRowConvertible = is(U : row_t);
        }

        template isColumnConvertible(U)
        {
            enum bool isColumnConvertible = is(U : column_t);
        }
    }

    private
    {
        static if (R == C)
        {
            static SmallMatrix makeIdentity() pure
            {
                SmallMatrix res;
                for (size_t i = 0; i < R; ++i)
                    for (size_t j = 0; j < C; ++j)
                        res.c[i][j] = (i == j) ? 1 : 0;
                return res;
            }
        }

        static SmallMatrix makeConstant(U)(U x) pure
        {
            SmallMatrix res;
            for (size_t i = 0; i < _N; ++i)
                res.v[i] = cast(T)x;
            return res;
        }
    }

    // put here because of order of declaration
    // TODO: is this normal?
    public
    {
        enum ZERO = makeConstant(0);
        static if (R == C)
        {
            enum IDENTITY = makeIdentity();
        }
    }
    
}

// GLSL is a big inspiration here
// we defines types with more or less the same names
template mat2x2(T) { alias SmallMatrix!(2u, 2u, T) mat2x2; }
template mat3x3(T) { alias SmallMatrix!(3u, 3u, T) mat3x3; }
template mat4x4(T) { alias SmallMatrix!(4u, 4u, T) mat4x4; }

// WARNING: in GLSL, first number is _columns_, second is rows
// It is the opposite here: first number is rows, second is columns
// With this convention mat2x3 * mat3x4 -> mat2x4.
template mat2x3(T) { alias SmallMatrix!(2u, 3u, T) mat2x3; }
template mat2x4(T) { alias SmallMatrix!(2u, 4u, T) mat2x4; }
template mat3x2(T) { alias SmallMatrix!(3u, 2u, T) mat3x2; }
template mat3x4(T) { alias SmallMatrix!(3u, 4u, T) mat3x4; }
template mat4x2(T) { alias SmallMatrix!(4u, 2u, T) mat4x2; }
template mat4x3(T) { alias SmallMatrix!(4u, 3u, T) mat4x3; }

alias mat2x2 mat2;
alias mat3x3 mat3;  // shorter names for most common matrices
alias mat4x4 mat4;

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

// define a lot of type names
mixin(definePostfixAliases("mat2"));
mixin(definePostfixAliases("mat3"));
mixin(definePostfixAliases("mat4"));
mixin(definePostfixAliases("mat2x2"));
mixin(definePostfixAliases("mat2x3"));
mixin(definePostfixAliases("mat2x4"));
mixin(definePostfixAliases("mat3x2"));
mixin(definePostfixAliases("mat3x3"));
mixin(definePostfixAliases("mat3x4"));
mixin(definePostfixAliases("mat4x2"));
mixin(definePostfixAliases("mat4x3"));
mixin(definePostfixAliases("mat4x4"));

unittest
{
    mat2i x = mat2i(0, 1,
                    2, 3);
    assert(x.c[0][0] == 0 && x.c[0][1] == 1 && x.c[1][0] == 2 && x.c[1][1] == 3);

    mat2i y = mat2i.fromColumns(vec2i(0, 2), vec2i(1, 3));
    assert(y.c[0][0] == 0 && y.c[0][1] == 1 && y.c[1][0] == 2 && y.c[1][1] == 3);

    assert(x == y);
    x = [0, 1, 2, 3];
    assert(x == y);


    mat2i z = x * y;
    assert(z == mat2i([2, 3, 6, 11]));
    vec2i vz = z * vec2i(2, -1);
    assert(vz == vec2i(1, 1));

    mat2f a = z;
    mat2f w = [4, 5, 6, 7];
    z = cast(mat2i)w;
    assert(w == z);

    {
        mat2x3f A;
        mat3x4f B;
        mat2x4f C = A * B;
    }
}
