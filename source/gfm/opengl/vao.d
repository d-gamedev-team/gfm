module gfm.opengl.vao;

import std.string;

import derelict.opengl3.gl3;

import gfm.core.log,
       gfm.opengl.opengl;

/** 
 * Vertex Array Object wrapper.
 */
final class VAO
{
    public
    {
        this(OpenGL gl, GLuint target, GLuint storage, GLuint usage)
        {
            _gl = gl;
            glGenVertexArrays(1, &_handle);
            _initialized = true;
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_initialized)
            {
                glDeleteVertexArrays(1, &_handle);
                _initialized = false;
            }
        }

        void bind()
        {
            glBindVertexArray(_handle);
            _gl.runtimeCheck();
        }

        void unbind() 
        {
            glBindVertexArray(0);
            _gl.runtimeCheck();
        }

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
