module gfm.opengl.matrixstack;

import gfm.math.vector;
import gfm.math.matrix;
import gfm.common.memory;


// A matrix stack designed to replace fixed-pipeline own matrix stacks.
// Create one for GL_PROJECTION and one for GL_MODELVIEW, and there you go.
// For performance reason, no runtime check for emptyness/fullness, only asserts
// M should be a matrix type
// TODO: rotations
final class MatrixStack(size_t R, T) if (R == 3 || R == 4)
{
    public
    {
        alias Matrix!(T, R, R) matrix_t;

        this(size_t depth = 32)
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

        // replacement for glLoadIdentity
        void loadIdentity()
        {
            _matrices[0] = mat4d.IDENTITY;
            _invMatrices[0] = mat4d.IDENTITY;
        }

        // replacement for glPushMatrix
        void push() pure nothrow
        {
            assert(_top + 1 < _depth);
            _matrices[_top + 1] = _matrices[_top];
            _invMatrices[_top + 1] = _invMatrices[_top];
            ++_top;
        }

        // replacement for glPopMatrix
        void pop() pure nothrow
        {
            assert(_top > 0);
            --_top;
        }

        // return top matrix
        matrix_t top() pure const nothrow
        {
            return _matrices[_top];
        }

        // return top matrix inverted
        matrix_t invTop() pure const nothrow
        {
            return _invMatrices[_top];
        }

        /// replacement for glMultMatrix
        void mult(matrix_t m)
        {
            _matrices[_top] = _matrices[_top] * m;
            _invMatrices[_top] = _invMatrices[_top] * m.inverse();
        }

        /// same as mult() above, but with provided inverse
        void mult(matrix_t m, matrix_t invM)
        {
            _matrices[_top] = _matrices[_top] * m;
            _invMatrices[_top] = _invMatrices[_top] * invM;
        }

        /// Replacement for glTranslate
        void translate(Vector!(T, R-1) v)
        {
            _matrices[_top].translate(v);
            _invMatrices[_top].translate(-v);
        }

        /// Replacement for glScale
        void scale(Vector!(T, R-1) v)
        {
            _matrices[_top].scale(v);
            _invMatrices[_top].scale(1 / v);
        }

        static if (R == 4)
        {
            /**
             * Replacement for glRotate
             * angle is given in radians
             */ 
            void rotate(T angle, Vector!(T, 3u) axis)
            {
                matrix_t rot = matrix_t.rotation(angle, axis);
                mult(rot, rot.transposed()); // inversing a rotation matrix is tranposing
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
    // this line makes compilation fail, for some obscure reason
    // auto s = new MatrixStack!(4u, double)();
    
    // s.loadIdentity();
    // s.push();
    // s.pop();
}
