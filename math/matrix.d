module gfm.math.matrix;

import std.math;
import std.typetuple;
import std.traits;
import std.typecons;
import std.conv;
import gfm.math.vector;

// generic small non-resizeable matrix with R rows and C columns
// N is the element count, T the contained type
// intended for 3D (mainly size 3x3 and 4x4)
// IMPORTANT: matrices here are in ROW-MAJOR order
// while OpenGL is column-major
align(1) struct Matrix(T, size_t R, size_t C)
{
    public
    {
        static assert(R >= 1u && C >= 1u);

        alias Vector!(T, C) row_t;
        alias Vector!(T, R) column_t;

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
            else static if ((U.length == 1) && (isAssignable!(U[0])) && (!is(U[0] : Matrix)))
            {
                // construct with assignment
                opAssign!(U[0])(values[0]);
            }
            else static assert(false, "cannot create a matrix from given arguments");
        }

        // construct with columns
        static Matrix fromColumns(column_t[] columns...) pure nothrow
        {
            Matrix res;
            for (size_t i = 0; i < R; ++i)
                for (size_t j = 0; j < C; ++j)
                {
                   res.c[i][j] = columns[j][i];
                }
            return res;
        }

        static Matrix fromRows(row_t[R] rows...) pure nothrow
        {
            Matrix res;
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
        void opAssign(U : Matrix)(U x) pure
        {
            for (size_t i = 0; i < _N; ++i)
            {
                v[i] = x.v[i];
            }
        }

        // other small matrices (same size, compatible type)
        void opAssign(U)(U x) pure nothrow
            if (is(typeof(U._isMatrix))
                && is(U._T : _T)
                && (!is(U: Matrix))
                && (U._R == _R) && (U._C == _C))
        {
            for (size_t i = 0; i < _N; ++i)
                v[i] = x.v[i];
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
                res.v[i] = c[i][j];
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
                    sum += c[i][j] * x.v[j];
                }
                res.v[i] = sum;
            }
            return res;
        }

        // matrix * matrix
        auto opBinary(string op, U)(U x)
            if (is(typeof(U._isMatrix)) && (U._R == C) && (op == "*"))
        {
            Matrix!(T, R, U._C) result = void;

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

        ref Vector opOpAssign(string op, U)(U operand) pure if (isConvertible!U)
        {
            Vector conv = operand;
            return opOpAssign!op(conv);
        }

        // cast to other small matrices type
        // if the size are different, the result matrix is truncated and/or filled with identity coefficients
        U opCast(U)() pure nothrow const if (is(typeof(U._isMatrix)) && (U._R == _R) && (U._C == _C))
        {
            U res = U.IDENTITY;
            enum minR = R < U._R ? R : U._R;
            enum minC = C < U._C ? C : U._C;
            for (size_t i = 0; i < minR; ++i)
                for (size_t j = 0; j < minC; ++j)
                {
                    res.c[i][j] = cast(U._T)(c[i][j]);
                }
            return res;
        }

        bool opEquals(U)(U other) pure const nothrow if (is(U : Matrix))
        {
            for (size_t i = 0; i < _N; ++i)
                if (v[i] != other.v[i])
                    return false;
            return true;
        }

        bool opEquals(U)(U other) pure const nothrow
            if ((isAssignable!U) && (!is(U: Matrix)))
        {
            Matrix conv = other;
            return opEquals(conv);
        }

        // +matrix, -matrix, ~matrix, !matrix
        Matrix opUnary(string op)() pure const nothrow if (op == "+" || op == "-" || op == "~" || op == "!")
        {
            Matrix res = void;
            for (size_t i = 0; i < N; ++i)
                mixin("res.v[i] = " ~ op ~ "v[i];");
            return res;
        }

        // matrix inversion, provided for 2x2, 3x3 and 4x4 floating point matrices
        static if (isSquare && isFloatingPoint!T && _R == 2)
        {
            Matrix inverse() pure const nothrow
            {
                T invDet = 1 / (c[0][0] * c[1][1] - c[0][1] * c[1][0]);
                return Matrix( c[1][1] * invDet, -c[0][1] * invDet,
                                   -c[1][0] * invDet,  c[0][0] * invDet);
            }
        }

        static if (isSquare && isFloatingPoint!T && _R == 3)
        {
            Matrix inverse() pure const nothrow
            {
                T det = c[0][0] * (c[1][1] * c[2][2] - c[2][1] * c[1][2])
                      - c[0][1] * (c[1][0] * c[2][2] - c[1][2] * c[2][0])
                      + c[0][2] * (c[1][0] * c[2][1] - c[1][1] * c[2][0]);
                T invDet = 1 / det;

                Matrix res = void;
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
            Matrix inverse() pure const nothrow
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

                Matrix res = void;
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

        /// matrix transposition
        Matrix!(T, C, R) transposed()
        {
            Matrix!(T, C, R) res;
            for (size_t i = 0; i < C; ++i)
                for (size_t j = 0; j < R; ++j)
                    res.c[i][j] = c[j][i];
            return res;
        }

        static if (isSquare && _R > 1)
        {
            /// in-place translate by (v, 1) 
            void translate(Vector!(T, _R-1) v)
            {
                for (size_t i = 0; i < _R; ++i)
                {
                    T dot = 0;
                    for (size_t j = 0; j + 1 < C; ++j)
                        dot += v.v[j] * c[i][j];

                    c[i][_C-1] += dot;
                }
            }

            /// make translation matrix
            static Matrix translation(Vector!(T, _R-1) v)
            {
                Matrix res = IDENTITY;
                for (size_t i = 0; i + 1 < _R; ++i)
                    res.c[i][_C-1] += v.v[i];
                return res;
            }

            /// in-place scaling matrix
            void scale(Vector!(T, _R-1) v)
            {
                for (size_t i = 0; i < _R; ++i)
                    for (size_t j = 0; j + 1 < _C; ++j)
                        c[i][j] *= v.v[j];
            }

            /// make scaling matrix
            static Matrix scaling(Vector!(T, _R-1) v)
            {
                Matrix res = IDENTITY;
                for (size_t i = 0; i + 1 < _R; ++i)
                    res.c[i][i] = v.v[i];
                return res;
            }
        }

        // rotations for 3x3 and 4x4 matrices
        // TODO glRotate equivalent
        static if (isSquare && (_R == 3 || _R == 4) && isFloatingPoint!T)
        {
            private static Matrix rotateAxis(size_t i, size_t j)(T angle)
            {
                Matrix res = IDENTITY;
                const T cosa = cos(angle);
                const T sina = sin(angle);
                res.c[i][i] = cosa;
                res.c[i][j] = -sina;
                res.c[j][i] = sina;
                res.c[j][j] = cosa;
                return res;
            }

            public alias rotateAxis!(1, 2) rotateX;
            public alias rotateAxis!(2, 0) rotateY;
            public alias rotateAxis!(0, 1) rotateZ;

            // similar to the glRotate matrix, however the angle is expressed in radians
            // Reference: http://www.cs.rutgers.edu/~decarlo/428/gl_man/rotate.html
            static Matrix rotation(T angle, Vector!(T, 3u) axis)
            {
                Matrix res = IDENTITY;
                const T c = cos(angle);
                const oneMinusC = 1 - c;
                const T s = sin(angle);
                axis = axis.normalized();
                T x = axis.x, 
                  y = axis.y,
                  z = axis.z;
                T xy = x * y,
                  yz = y * z,
                  xz = x * z;
                
                res.c[0][0] = x * x * oneMinusC + c;
                res.c[0][1] = x * y * oneMinusC - z * s;
                res.c[0][2] = x * z * oneMinusC + y * s;
                res.c[1][0] = y * x * oneMinusC + z * s;
                res.c[1][1] = y * y * oneMinusC + c;
                res.c[1][2] = y * z * oneMinusC - x * s;
                res.c[2][0] = z * x * oneMinusC - y * s;
                res.c[2][1] = z * y * oneMinusC + x * s;
                res.c[2][2] = z * z * oneMinusC + c;
                return res;
            }
        }

        // 4x4 specific transformations for 3D usage
        static if (isSquare && _R == 4 && isFloatingPoint!T)
        {
            // return orthographic projection
            static Matrix orthographic(T left, T right, T bottom, T top, T near, T far)
            {
                T dx = right - left,
                  dy = top - bottom,
                  dz = far - near;

                T tx = -(right + left) / dx;
                T ty = -(top + bottom) / dy;
                T tz = -(far + near)   / dz;

                return Matrix(2 / dx,   0,      0,    tx,
                                0,    2 / dy,   0,    ty,
                                0,      0,    2 / dz, tz,
                                0,      0,      0,     1);
            }

            // perspective projection
            static Matrix perspective(T FOVInRadians, T aspect, T zNear, T zFar)
            {
                T f = 1 / tan(FOVInRadians / 2);
                T d = 1 / (zNear - zFar);

                return Matrix(f / aspect, 0,                  0,                    0,
                                       0, f,                  0,                    0,
                                       0, 0, (zFar + zNear) * d, 2 * d * zFar * zNear,
                                       0, 0,                 -1,                    0);
            }

            // See: http://msdn.microsoft.com/en-us/library/windows/desktop/bb205343(v=vs.85).aspx
            // TODO: verify if it's the right one...
            static Matrix lookAt(Vector!(T, 3u) eye, Vector!(T, 3u) target, Vector!(T, 3u) up)
            {
                Vector!(T, 3u) Z = (eye - target).normalized();
                Vector!(T, 3u) X = cross(up, Z).normalized();
                Vector!(T, 3u) Y = cross(Z, X);

                return Matrix(    X.x,         Y.x,         Z.x,     0,
                                  X.y,         Y.y,         Z.y,     0,
                                  X.z,         Y.z,         Z.z,     0,
                              dot(X, eye), dot(Y, eye), dot(Z, eye), 1);
            }
        }
    }

    private
    {
        alias T _T;
        enum _N = R * C;
        enum _R = R;
        enum _C = C;
        enum bool _isMatrix = true;

        template isAssignable(T)
        {
            enum bool isAssignable =
                is(typeof(
                {
                    T x;
                    Matrix m = x;
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
        // Note: the identity matrix, while only meaningful for square matrices, is also
        //       defined for non-square ones.
        static Matrix makeIdentity() pure
        {
            Matrix res;
            for (size_t i = 0; i < R; ++i)
                for (size_t j = 0; j < C; ++j)
                    res.c[i][j] = (i == j) ? 1 : 0;
            return res;
        }

        static Matrix makeConstant(U)(U x) pure
        {
            Matrix res;
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
        enum ONES = makeConstant(1);
        static if (R == C)
        {
            enum IDENTITY = makeIdentity();
        }
    }
}

// GLSL is a big inspiration here
// we defines types with more or less the same names
template mat2x2(T) { alias Matrix!(T, 2u, 2u) mat2x2; }
template mat3x3(T) { alias Matrix!(T, 3u, 3u) mat3x3; }
template mat4x4(T) { alias Matrix!(T, 4u, 4u) mat4x4; }

// WARNING: in GLSL, first number is _columns_, second is rows
// It is the opposite here: first number is rows, second is columns
// With this convention mat2x3 * mat3x4 -> mat2x4.
template mat2x3(T) { alias Matrix!(T, 2u, 3u) mat2x3; }
template mat2x4(T) { alias Matrix!(T, 2u, 4u) mat2x4; }
template mat3x2(T) { alias Matrix!(T, 3u, 2u) mat3x2; }
template mat3x4(T) { alias Matrix!(T, 3u, 4u) mat3x4; }
template mat4x2(T) { alias Matrix!(T, 4u, 2u) mat4x2; }
template mat4x3(T) { alias Matrix!(T, 4u, 3u) mat4x3; }

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
