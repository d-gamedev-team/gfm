module gfm.opengl.vao;

import std.string;

import derelict.opengl3.gl3;

import gfm.opengl.opengl;

/// OpenGL Vertex Array Object wrapper.
final class GLVAO
{
    public
    {
        /// Creates a VAO.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl)
        {
            _gl = gl;
            glGenVertexArrays(1, &_handle);
            gl.runtimeCheck();
            _initialized = true;
        }

        /// Releases the OpenGL VAO resource.
        ~this()
        {
            if (_initialized)
            {
                debug ensureNotInGC("GLVAO");
                glDeleteVertexArrays(1, &_handle);
                _initialized = false;
            }
        }

        /// Uses this VAO.
        /// Throws: $(D OpenGLException) on error.
        void bind()
        {
            glBindVertexArray(_handle);
            _gl.runtimeCheck();
        }

        /// Unuses this VAO.
        /// Throws: $(D OpenGLException) on error.
        void unbind()
        {
            glBindVertexArray(0);
            _gl.runtimeCheck();
        }

        /// Returns: Wrapped OpenGL resource handle.
        GLuint handle() pure const nothrow
        {
            return _handle;
        }
    }

    private
    {
        OpenGL _gl;
        GLuint _handle;
        bool _initialized;
    }
}
