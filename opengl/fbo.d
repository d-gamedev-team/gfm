module gfm.opengl.fbo;

import std.string;

import derelict.opengl3.gl3;

import gfm.common.log;
import gfm.opengl.opengl, gfm.opengl.exception;

// OpenGL FrameBuffer Object wrapper
final class FBO
{
    public
    {
        this(OpenGL gl)
        {
            _gl = gl;
            glGenFramebuffers(1, &_handle);
            _gl.runtimeCheck();
            _initialized = true;
            _usage = Usage.NONE;
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_initialized)
            {
                glDeleteFramebuffers(1, &_handle);
                _initialized = false;
            }
        }

        void useDraw()
        {
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, _handle);
            _gl.runtimeCheck();
            _usage = Usage.DRAW;            
        }

        void useRead()
        {
            glBindFramebuffer(GL_READ_FRAMEBUFFER, _handle);
            _gl.runtimeCheck();
            _usage = Usage.READ;
        }

        void unuse()
        {
            final switch (_usage)
            {
                case Usage.NONE:
                    throw new OpenGLException("Framebuffer was not bounded");

                case Usage.DRAW:
                    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
                    break;

                case Usage.READ:
                    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);                     
                    break;
            }
            _gl.runtimeCheck();
        }
    }

    private
    {
        OpenGL _gl;
        GLuint  _handle;
        bool _initialized;

        enum Usage
        {
            DRAW,
            READ,
            NONE
        }

        Usage _usage;
    }
}
