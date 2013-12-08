module gfm.opengl.vbo;


// Describing vertex, submitting geometry.
// Implement so called Vertex Arrays and VBO (which are Vertex Arrays + OpenGL buffers)

import std.string;

import derelict.opengl3.gl3,
       derelict.opengl3.deprecatedFunctions,
       derelict.opengl3.deprecatedConstants;

import gfm.core.log,
       gfm.opengl.opengl;

/** 
 * A vertex specification describes exactly the format of a vertex.
 * Can only be built manually for now.
 *
 * TODO: extract from a struct at compile-time.
 */
class VertexSpecification
{
    public
    {
        /// Creates a vertex specification.
        this(OpenGL gl)
        {
            _gl = gl;
            _currentOffset = 0;
            _elements = [];
            _state = State.UNUSED;
        }

        ~this()
        {
            assert(_state == State.UNUSED);
        }

        /// Use this vertex specification.
        /// Params: 
        ///    useOlderAttribFunctions = Whether we use older pointer attribute functions, 
        ///                              which can be more portable.
        /// Throws: $(D OpenGLException) on error.
        void use(bool useOlderAttribFunctions = false)
        {
            assert(_state == State.UNUSED);
            for (uint i = 0; i < _elements.length; ++i)
                _elements[i].use(_gl, i, useOlderAttribFunctions, cast(GLsizei) _currentOffset);
            _state = useOlderAttribFunctions ? State.USED_OLDER_FUNCTIONS : State.USED_NEWER_FUNCTION;
        }

        /// Unuse this vertex specification.
        /// Throws: $(D OpenGLException) on error.
        void unuse()
        {
            assert(_state == State.USED_OLDER_FUNCTIONS || _state == State.USED_NEWER_FUNCTION);
            for (uint i = 0; i < _elements.length; ++i)
                _elements[i].unuse(_gl, i, _state == State.USED_OLDER_FUNCTIONS);
            _state = State.UNUSED;
        }

        /// Adds an item to the vertex specification.
        void add(VertexElement.Role role, GLenum glType, int n)
        {
            assert(n > 0 && n <= 4);
            assert(_state == State.UNUSED);
            assert(isGLTypeSuitable(glType));
            _elements ~= VertexElement(role, n, _currentOffset, glType);
            _currentOffset += n * glTypeSize(glType);
        }

        /// Adds padding space to the vertex specification.
        /// This is useful for alignment.
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

/// Describes a single attribute in a vertex entry.
struct VertexElement
{
    /// Role of this vertex attribute.
    enum Role
    {
        POSITION,  /// This attribute is a position.
        COLOR,     /// This attribute is a color.
        TEX_COORD, /// This attribute is a texture coordinate.
        NORMAL     /// This attribute is a normal.
    }

    Role role;
    int n;
    size_t offset;
    GLenum glType;

    package
    {
        /// Use this attribute.
        /// Throws: $(D OpenGLException) on error.
        void use(OpenGL gl, GLuint index, bool useOlderAttribFunctions, GLsizei sizeOfVertex)
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
                glEnableVertexAttribArray(index);
                glVertexAttribPointer(index, n, glType, GL_FALSE, sizeOfVertex, cast(GLvoid *) offset);
            }
            gl.runtimeCheck();
        }

        /// Unuse this attribute.
        /// Throws: $(D OpenGLException) on error.
        void unuse(OpenGL gl, GLuint index, bool useOlderAttribFunctions)
        {
            if(useOlderAttribFunctions)
            {
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
            }
            else
            {
                glDisableVertexAttribArray(index);
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
