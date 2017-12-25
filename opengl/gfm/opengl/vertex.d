module gfm.opengl.vertex;


// Describing vertex, submitting geometry.
// Implement so called Vertex Arrays and VBO (which are Vertex Arrays + OpenGL buffers)

import std.string,
       std.typetuple,
       std.typecons,
       std.traits;

import derelict.opengl;

import gfm.math.vector,
       gfm.opengl.opengl,
       gfm.opengl.program,
       gfm.opengl.buffer;


/// An UDA to specify an attribute which has to be normalized
struct Normalized
{
}

/**
 * A VertexSpecification's role is to describe a Vertex structure.
 * You must instantiate it with a compile-time struct describing your vertex format.
 *
 * Examples:
 * --------------------
 * struct MyVertex
 * {
 *     vec3f position;
 *     vec4f diffuse;
 *     float shininess;
 *     @Normalized vec2i uv;
 *     vec3f normal;
 * }
 * --------------------
 * Member names MUST match those used in the vertex shader as attributes.
 */
final class VertexSpecification(Vertex)
{
    public
    {
        /// Creates a vertex specification.
        /// The program is used to find the attribute location.
        this(GLProgram program)
        {
            _gl = program._gl;
            _program  = program;

            template isRWField(T, string M)
            {
                enum isRWField = __traits(compiles, __traits(getMember, Tgen!T(), M) = __traits(getMember, Tgen!T(), M));
                pragma(msg, T.stringof~"."~M~": "~(isRWField?"1":"0"));
            }

            alias TT = FieldTypeTuple!Vertex;

            // Create all attribute description
            foreach (member; __traits(allMembers, Vertex))
            {
                // Nested struct have a context pointer
                static assert(member != "this",
                              `Found a 'this' member in vertex struct. Use a 'static struct' instead.`);

                enum fullName = "Vertex." ~ member;
                mixin("alias T = typeof(" ~ fullName ~ ");");

                static if (staticIndexOf!(T, TT) != -1)
                {
                    int location = program.attrib(member).location;
                    mixin("enum size_t offset = Vertex." ~ member ~ ".offsetof;");

                    enum UDAs = __traits(getAttributes, member);
                    bool normalize = (staticIndexOf!(Normalized, UDAs) == -1);

                    // detect suitable type
                    int n;
                    GLenum glType;
                    toGLTypeAndSize!T(glType, n);
                    _attributes ~= VertexAttribute(n, offset, glType, location, normalize ? GL_TRUE : GL_FALSE);

                }
            }
        }

        /**
         * Use this vertex specification.
         *
         * Divisor is the value passed to glVertexAttribDivisor.
         * See $(WEB www.opengl.org/wiki/Vertex_Specification#Instanced_arrays) for details.
         *
         * Throws: $(D OpenGLException) on error.
         */
        void use(GLuint divisor = 0)
        {
            // use every attribute
            for (uint i = 0; i < _attributes.length; ++i)
                _attributes[i].use(_gl, cast(GLsizei) vertexSize(), divisor);
        }

        /// Unuse this vertex specification. If you are using a VAO, you don't need to call it,
        /// since the attributes would be tied to the VAO activation.
        /// Throws: $(D OpenGLException) on error.
        void unuse()
        {
            // unuse all the attributes
            for (uint i = 0; i < _attributes.length; ++i)
                _attributes[i].unuse(_gl);
        }

        /// Returns the size of the Vertex; this size can be computer
        /// after you added all your attributes
        size_t vertexSize() pure const nothrow
        {
            return Vertex.sizeof;
        }
    }

    private
    {
        OpenGL _gl;
        GLProgram _program;
        VertexAttribute[] _attributes;
    }
}

/// Describes a single attribute in a vertex entry.
struct VertexAttribute
{
    private
    {
        int n;
        size_t offset;
        GLenum glType;
        GLint location;
        GLboolean normalize;
        bool divisorSet;


        /// Use this attribute.
        /// Throws: $(D OpenGLException) on error.
        void use(OpenGL gl, GLsizei sizeOfVertex, GLuint divisor)
        {
            // fake attribute, do not enable
            if (location == GLAttribute.fakeLocation)
                return ;

            if (divisor != 0)
                divisorSet = true;

            glEnableVertexAttribArray(location);
            if (isIntegerType(glType))
                glVertexAttribIPointer(location, n, glType, sizeOfVertex, cast(GLvoid*)offset);
            else
                glVertexAttribPointer(location, n, glType, normalize, sizeOfVertex, cast(GLvoid*)offset);
            if(divisorSet)
                glVertexAttribDivisor(location, divisor);
            gl.runtimeCheck();
        }

        /// Unuse this attribute.
        /// Throws: $(D OpenGLException) on error.
        void unuse(OpenGL gl)
        {
            // couldn't figure out if glDisableVertexAttribArray resets this, so play it safe
            if(divisorSet)
                glVertexAttribDivisor(location, 0);
            divisorSet = false;
            glDisableVertexAttribArray(location);
            gl.runtimeCheck();
        }
    }
}

private
{
    bool isIntegerType(GLenum t)
    {
        return (t == GL_BYTE
             || t == GL_UNSIGNED_BYTE
             || t == GL_SHORT
             || t == GL_UNSIGNED_SHORT
             || t == GL_INT
             || t == GL_UNSIGNED_INT);
    }

    alias VectorTypes = TypeTuple!(byte, ubyte, short, ushort, int, uint, float, double);
    enum GLenum[] VectorTypesGL =
    [
        GL_BYTE,
        GL_UNSIGNED_BYTE,
        GL_SHORT,
        GL_UNSIGNED_SHORT,
        GL_INT,
        GL_UNSIGNED_INT,
        GL_FLOAT,
        GL_DOUBLE
    ];

    template isSupportedScalarType(T)
    {
        enum isSupportedScalarType = staticIndexOf!(Unqual!T, VectorTypes) != -1;
    }

    template typeToGLScalar(T)
    {
        alias U = Unqual!T;
        enum index = staticIndexOf!(U, VectorTypes);
        static if (index == -1)
        {
            static assert(false, "Could not use " ~ T.stringof ~ " in a vertex description");
        }
        else
            enum typeToGLScalar = VectorTypesGL[index];
    }

    void toGLTypeAndSize(T)(out GLenum type, out int n)
    {
        static if (isSupportedScalarType!T)
        {
            type = typeToGLScalar!T;
            n = 1;
        }
        else static if (isStaticArray!T)
        {
            type = typeToGLScalar!(typeof(T.init[0]));
            n = T.length;
        }
        else
        {
            alias U = Unqual!T;

            // is it a gfm.vector.Vector?
            foreach(int t, S ; VectorTypes)
            {
                static if (is (U == Vector!(S, 2)))
                {
                    type = VectorTypesGL[t];
                    n = 2;
                    return;
                }

                static if (is (U == Vector!(S, 3)))
                {
                    type = VectorTypesGL[t];
                    n = 3;
                    return;
                }

                static if (is (U == Vector!(S, 4)))
                {
                    type = VectorTypesGL[t];
                    n = 4;
                    return;
                }
            }

            assert(false, "Could not use " ~ T.stringof ~ " in a vertex description");
        }
    }
}


/// A helper template to define a simple vertex type from a vector type.
/// By default the unique field will be name "position".
/// Note: it's important the struct isn't larger than the vector itself.
///
/// Example:
///     VertexSpecification!(VertexPosition!vec3f);
///
align(1) struct VertexPosition(Vec, string fieldName = "position") if (isVector!Vec)
{
    align(1):
    mixin("Vec " ~ fieldName ~ ";");
    static assert(VertexPosition.sizeof == Vec.sizeof);
}

unittest
{
   static struct MyVertex
   {
       vec3f position;
       vec4f diffuse;
       float shininess;
       @Normalized vec2i uv;
       vec3f normal;
   }
   alias Test = VertexSpecification!MyVertex;

   alias Test2 = VertexSpecification!(VertexPosition!vec3f);
}
