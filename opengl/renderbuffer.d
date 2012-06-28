module gfm.opengl.renderbuffer;

import derelict.opengl3.gl3;

import gfm.common.log;
import gfm.opengl.opengl;

final class RenderBuffer
{
    public
    {
        this(OpenGL gl, GLenum internalFormat, int width, int height)
        {
            _gl = gl;
            glGenRenderbuffers(1, &_handle);
            gl.runtimeCheck();
            
            use();
            scope(exit) unuse();
            glRenderbufferStorage(GL_RENDERBUFFER, internalFormat, width, height);

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
                _initialized = false;
                glDeleteRenderbuffers(1, &_handle);
            }
        }

        void use()
        {
            glBindRenderbuffer(GL_RENDERBUFFER, _handle);
            _gl.runtimeCheck();
        }

        void unuse()
        {
            glBindRenderbuffer(GL_RENDERBUFFER, 0);
            _gl.runtimeCheck();
        }
    }

    private
    {
        OpenGL _gl;
        GLuint _handle;
        GLenum _format;
        GLenum _type;
        bool _initialized;
    }
}
