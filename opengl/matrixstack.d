module gfm.opengl.matrixstack;

import gfm.common.memory,
       gfm.math.vector,
       gfm.math.matrix;

// A matrix stack designed to replace fixed-pipeline own matrix stacks.
// Create one for GL_PROJECTION and one for GL_MODELVIEW, and there you go.
// For performance reason, no runtime check for emptyness/fullness, only asserts
// M should be a matrix type
final class MatrixStack(size_t R, T) if (R == 3 || R == 4)
{
    public
    {
        alias Matrix!(T, R, R) matrix_t;

        this(size_t depth = 32) nothrow
        {
            assert(depth > 0);
            size_t memNeeded = matrix_t.sizeof * depth * 2;
            void* data = alignedMalloc(memNeeded * 2, 64);
            _matrices = cast(matrix_t*)data;
            _invMatrices = cast(matrix_t*)(data + memNeeded);
            _top = 0;
            _depth = depth;
            loadIdentity();
        }

        ~this()
        {
            alignedFree(_matrices);
        }

        /// replacement for glLoadIdentity
        void loadIdentity() pure nothrow
        {
            _matrices[_top] = mat4d.IDENTITY;
            _invMatrices[_top] = mat4d.IDENTITY;
        }

        /// replacement for glPushMatrix
        void push() pure nothrow
        {
            assert(_top + 1 < _depth);
            _matrices[_top + 1] = _matrices[_top];
            _invMatrices[_top + 1] = _invMatrices[_top];
            ++_top;
        }

        /// replacement for glPopMatrix
        void pop() pure nothrow
        {
            assert(_top > 0);
            --_top;
        }

        /// return top matrix
        matrix_t top() pure const nothrow
        {
            return _matrices[_top];
        }

        /// return top matrix inverted
        matrix_t invTop() pure const nothrow
        {
            return _invMatrices[_top];
        }

        /// replacement for glMultMatrix
        void mult(matrix_t m) pure nothrow
        {
            mult(m, m.inverse());
        }

        /// same as mult() above, but with provided inverse
        void mult(matrix_t m, matrix_t invM) pure nothrow
        {
            _matrices[_top] = _matrices[_top] * m;
            _invMatrices[_top] = invM *_invMatrices[_top];
        }

        /// Replacement for glTranslate
        void translate(Vector!(T, R-1) v) pure nothrow
        {
            mult(matrix_t.translation(v), matrix_t.translation(-v));
        }

        /// Replacement for glScale
        void scale(Vector!(T, R-1) v) pure nothrow
        {
            mult(matrix_t.scaling(v), matrix_t.scaling(1 / v));
        }

        static if (R == 4)
        {
            /**
             * Replacement for glRotate
             * angle is given in radians
             */ 
            void rotate(T angle, Vector!(T, 3u) axis) pure nothrow
            {
                matrix_t rot = matrix_t.rotation(angle, axis);
                mult(rot, rot.transposed()); // inversing a rotation matrix is tranposing
            }

            /**
             * Replacement for gluPerspective
             * FOV given in radians
             */
            void perspective(T FOVInRadians, T aspect, T zNear, T zFar) pure nothrow
            {
                mult(matrix_t.perspective(FOVInRadians, aspect, zNear, zFar));
            }

            /// Replacement for glOrtho
            void ortho(T left, T right, T bottom, T top, T near, T far) pure nothrow
            {
                mult(matrix_t.orthographic(left, right, bottom, top, near, far));
            }

            /// Replacement for gluLookAt
            void lookAt(vec3!T eye, vec3!T target, vec3!T up) pure nothrow
            {
                mult(matrix_t.lookAt(eye, target, up));
            }
        }
    }

    private
    {
        size_t _top; // index of top matrix
        size_t _depth;
        matrix_t* _matrices;
        matrix_t* _invMatrices;
    }
}

unittest
{
    auto s = new MatrixStack!(4u, double)();
    
    s.loadIdentity();
    s.push();
    s.pop();
}
