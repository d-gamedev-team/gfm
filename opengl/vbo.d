module gfm.opengl.vbo;


// Describing vertex, submitting geometry.
// Implement so called Vertex Arrays and VBO (which are Vertex Arrays + OpenGL buffers)

import std.string;
import derelict.opengl3.gl3;
import derelict.opengl3.deprecatedFunctions;
import derelict.opengl3.deprecatedConstants;
import gfm.common.log;
import gfm.opengl.opengl;

/** 
 * A vertex element describe exactly the format of a vertex.
 * Can ony be built manually for now.
 * TODO: extract from a struct at compile-time
 */
class VertexSpecification
{
    public
    {
        this(OpenGL gl)
        {
            _gl = gl;
            _currentOffset = 0;
            _elements = [];
            _state = State.UNUSED;
        }

        // using older pointer functions can be more portable
        void use(bool useOlderAttribFunctions = false)
        {
            assert(_state == State.UNUSED);
            foreach (ref e; _elements)
                e.use(_gl, useOlderAttribFunctions, _currentOffset);
            _state = useOlderAttribFunctions ? State.USED_OLDER_FUNCTIONS : State.USED_NEWER_FUNCTION;
        }

        void unuse()
        {
            assert(_state == State.USED_OLDER_FUNCTIONS || _state == State.USED_NEWER_FUNCTION);
            foreach (ref e; _elements)
                e.unuse(_gl, _state == State.USED_OLDER_FUNCTIONS);
            _state = State.UNUSED;
        }

        void add(VertexElement.Role role, GLenum glType, int n)
        {
            assert(n > 0 && n <= 4);
            assert(_state == State.UNUSED);
            assert(isGLTypeSuitable(glType));
            _elements ~= VertexElement(role, n, _currentOffset, glType);
            _currentOffset += n * glTypeSize(glType);
        }

        void addDummyBytes(int nBytes)
        {
            assert(_state == State.UNUSED);
            _currentOffset += nBytes;
        }
    }

    private
    {
        enum State
        {
            UNUSED,
            USED_OLDER_FUNCTIONS,
            USED_NEWER_FUNCTION
        }
        State _state;
        OpenGL _gl;
        VertexElement[] _elements;
        size_t _currentOffset;
    }
}

struct VertexElement
{
    enum Role
    {
        POSITION, COLOR, TEX_COORD, NORMAL
    }

    Role role;
    int n;
    size_t offset;
    GLenum glType;

    package
    {
        void use(OpenGL gl, bool useOlderAttribFunctions, size_t sizeOfVertex)
        {
            if (useOlderAttribFunctions)
            {
                final switch (role)
                {
                    case Role.POSITION:
                        glEnableClientState(GL_VERTEX_ARRAY);
                        glVertexPointer(n, glType, sizeOfVertex, cast(GLvoid *) offset);
                        break;

                    case Role.COLOR:
                        glEnableClientState(GL_COLOR_ARRAY);
                        glColorPointer(n, glType, sizeOfVertex, cast(GLvoid *) offset);
                        break;

                    case Role.TEX_COORD:
                        glEnableClientState(GL_TEXTURE_COORD_ARRAY);
                        glTexCoordPointer(n, glType, sizeOfVertex, cast(GLvoid *) offset);
                        break;

                    case Role.NORMAL:
                        glEnableClientState(GL_NORMAL_ARRAY);
                        assert(n == 3);
                        glNormalPointer(glType, sizeOfVertex, cast(GLvoid *) offset);
                        break;
                }
            }
            else
            {
                assert(false); // TODO
            }
            gl.runtimeCheck();            
        }

        void unuse(OpenGL gl, bool useOlderAttribFunctions)
        {
            assert(useOlderAttribFunctions); // TODO

            final switch (role)
            {
                case Role.POSITION:
                    glDisableClientState(GL_VERTEX_ARRAY);
                    break;

                case Role.COLOR:
                    glDisableClientState(GL_COLOR_ARRAY);
                    break;

                case Role.TEX_COORD:
                    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
                    break;

                case Role.NORMAL:
                    glDisableClientState(GL_NORMAL_ARRAY);
                    break;
            }
            gl.runtimeCheck();
        }
    }
}

private
{
    bool isGLTypeSuitable(GLenum t) pure nothrow
    {
        return (t == GL_BYTE  
             || t == GL_UNSIGNED_BYTE 
             || t == GL_SHORT 
             || t == GL_UNSIGNED_SHORT
             || t == GL_INT   
             || t == GL_UNSIGNED_INT 
//             || t == GL_HALF  
             || t == GL_FLOAT 
             || t == GL_DOUBLE);
    }

    size_t glTypeSize(GLenum t) pure nothrow
    {
        switch(t)
        {
            case GL_BYTE:
            case GL_UNSIGNED_BYTE: return 1;
//            case GL_HALF:
            case GL_SHORT:
            case GL_UNSIGNED_SHORT: return 2;
            case GL_INT:
            case GL_UNSIGNED_INT:
            case GL_FLOAT: return 4;
            case GL_DOUBLE: return 8;
            default: assert(false);
        }
    }
}
