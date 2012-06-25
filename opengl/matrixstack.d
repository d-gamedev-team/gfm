module gfm.opengl.matrixstack;

import gfm.math.smallvector;
import gfm.math.smallmatrix;
import gfm.common.memory;


// A matrix stack designed to replace fixed-pipeline own matrix stacks.
// Create one for GL_PROJECTION and one for GL_MODELVIEW, and there you go.
// For performance reason, no runtime check for emptyness/fullness, only asserts
// M should be a matrix type
final class MatrixStack(M) if (M.isSquare)
{
    public
    {

        this(size_t depth = 32)
        {
            assert(depth > 0);            
            size_t memNeeded = M.sizeof * depth * 2;
            void* data = alignedMalloc(memNeeded * 2, 64); 
            _matrices = cast(M*)data;
            _invMatrices = cast(M*)(data + memNeeded);
            _top = 0;
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
        M top() pure const nothrow 
        {
            return _matrices[_top];
        }

        // return top matrix inverted
        M invTop() pure const nothrow
        {
            return _invMatrices[_top];
        }

        // replacement for glMultMatrix
        void mult(M m)
        {
            _matrices[_top] = _matrices[_top] * m;
            _matrices[_top] = _matrices[_top] * m.inverse();
        }
    }

    private
    {
        size_t _top; // index of top matrix
        size_t _depth;
        M* _matrices;
        M* _invMatrices;
    }
}

unittest
{
    auto s = new MatrixStack!mat4x4d();

    s.loadIdentity();
    s.push();
    s.pop();
    
}