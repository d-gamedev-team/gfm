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
 * A VertexSpecification makes it easy to use Vertex Buffer Object with interleaved attributes.
 * It's role is similar to the OpenGL VAO one.
 * If the user requests it, the VertexSpecification can "take control" of a given VBO and/or IBO
 * and automatically bind/unbind them when the VertexSpecification is used/unused.
 * You have to specify every attribute manually for now.
 *
 * TODO: Extract vertex specification from a struct at compile-time.
 */
class VertexSpecification
{
    public
    {
        /// Creates a vertex specification.
        this(OpenGL gl)
        {
            _vboID = 0;
            _iboID = 0;
            _gl = gl;
// the indices we use start from 4 to avoid clashing with "standard" aliases at least with nVidia and AMD hardware AFAIK
// see http://stackoverflow.com/questions/528028/glvertexattrib-which-attribute-indices-are-predefined
            _genericAttribIndex = 4;
            _currentOffset = 0;
            _attributes = [];
            _state = State.UNUSED;
        }

        ~this()
        {
            assert(_state == State.UNUSED);
        }

        /// Use this vertex specification.
        /// Throws: $(D OpenGLException) on error.
        void use()
        {
            assert(_state == State.UNUSED);
            if (_vboID) // if we are "in control" of this VBO, we have to bind it to current OpenGL state
                glBindBuffer(GL_ARRAY_BUFFER, _vboID);
            if (_iboID)  // ditto, for the ibo
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _iboID);
            // for every attribute
            for (uint i = 0; i < _attributes.length; ++i)
                _attributes[i].use(_gl, cast(GLsizei) _currentOffset);
            _state = State.USED;
        }

        /// Unuse this vertex specification.
        /// Throws: $(D OpenGLException) on error.
        void unuse()
        {
            assert(_state == State.USED);
            // Leaving a clean state after unusing an object
            // seems the most reasonable way of doing things.
            if (_vboID) // if we are "in control" of this VBO, we have to bind it to current OpenDL state
                glBindBuffer(GL_ARRAY_BUFFER, 0);
            if (_iboID)  // ditto, for the ibo
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
            // unuse all the attributes
            for (uint i = 0; i < _attributes.length; ++i)
                _attributes[i].unuse(_gl);
            _state = State.UNUSED;
        }

        /// This property allows the user to set/unset the VBO "ownership"
        @property GLuint VBO() { return _vboID; } // property can always be read
        /// Ditto
        @property GLuint VBO(GLuint vboID) { // write property
            assert (_state == State.UNUSED); // Can be modified ONLY when unused
            return _vboID = vboID;
        }

        /// This property allows the user to set/unset the IBO "ownership"
        @property GLuint IBO() { return _iboID; } // property can always be read
        /// Ditto
        @property GLuint IBO(GLuint iboID) { // write property
            assert (_state == State.UNUSED); // Can be modified ONLY when unused
            return _iboID = iboID;
        }

        //property for accessing the count of the VBO elements
        @property GLuint VBOCount() { return _vboCount; }
        /// Ditto
        @property GLuint VBOCount(GLuint vboCount) { return _vboCount = vboCount; }

        //property for accessing the count of the VBO elements
        @property GLuint IBOCount() { return _iboCount; }
        /// Ditto
        @property GLuint IBOCount(GLuint iboCount) { return _iboCount = iboCount; }

        /// Adds an item to the vertex specification.
        /// Params: role = what is the role of this attribute;
        /// n = 1, 2, 3 or 4, is the number of components of the attribute;
        /// For compatibility, you should not define more than 12 attributes
        void add(VertexAttribute.Role role, GLenum glType, int n, GLboolean normalize = GL_FALSE)
        {
            assert(n > 0 && n <= 4);
            assert(_state == State.UNUSED);
            assert(isGLTypeSuitable(glType));
            _attributes ~= VertexAttribute(role, n, _currentOffset, glType, _genericAttribIndex, normalize);
            _currentOffset += n * glTypeSize(glType);
            if (role == VertexAttribute.Role.GENERIC)
                _genericAttribIndex++;
        }

        /// Adds padding space to the vertex specification.
        /// This is useful for alignment. TODO: clarify
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
            USED
        }
        GLuint _vboID;      /// The Vertex BO this VertexSpecification refers to
        GLuint _iboID;      /// The Index BO this VertexSpecification refers to
        GLuint _iboCount;   /// The count of the elements to be drawn when using the IBO
        GLuint _vboCount;   /// The count of the vertices
        State _state;
        OpenGL _gl;
        GLuint _genericAttribIndex;
        VertexAttribute[] _attributes;
        size_t _currentOffset;
    }
}

/// Describes a single attribute in a vertex entry.
struct VertexAttribute
{
    /// Role of this vertex attribute.
    enum Role
    {
        POSITION,  /// This attribute is a position.
        COLOR,     /// This attribute is a color.
        TEX_COORD, /// This attribute is a texture coordinate.
        NORMAL,    /// This attribute is a normal.
        GENERIC    /// This attribute is a generic vertex attribute
    }

    Role role;
    int n;
    size_t offset;
    GLenum glType;
    GLuint genericIndex;
    GLboolean  normalize;

    package
    {
        /// Use this attribute.
        /// Throws: $(D OpenGLException) on error.
        void use(OpenGL gl, GLsizei sizeOfVertex)
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

               case Role.GENERIC:
                    glEnableVertexAttribArray(genericIndex);
                    glVertexAttribPointer(genericIndex, n, glType, normalize, sizeOfVertex, cast(GLvoid *) offset);
                    break;
            }

            gl.runtimeCheck();
        }

        /// Unuse this attribute.
        /// Throws: $(D OpenGLException) on error.
        void unuse(OpenGL gl)
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

                case Role.GENERIC:
                    glDisableVertexAttribArray(genericIndex);
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
