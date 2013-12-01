module gfm.opengl.renderbuffer;

import std.string;

import derelict.opengl3.gl3;

import gfm.core.log,
       gfm.math.funcs,
       gfm.opengl.opengl;

final class GLRenderBuffer
{
    public
    {
        this(OpenGL gl, GLenum internalFormat, int width, int height, int samples = 0)
        {
            _gl = gl;
            glGenRenderbuffers(1, &_handle);
            gl.runtimeCheck();
            
            use();
            scope(exit) unuse();
            if (samples > 1)
            {
                // fallback to non multisampled
                if (glRenderbufferStorageMultisample is null)
                {
                    gl._log.warnf("render-buffer multisampling is not supported, fallback to non-multisampled");
                    goto non_mutisampled;
                }
                
                int maxSamples;
                glGetIntegerv(GL_MAX_SAMPLES, &maxSamples);
                if (maxSamples < 1)
                    maxSamples = 1;

                // limit samples to what is supported on this machine
                if (samples >= maxSamples)
                {
                    int newSamples = clamp(samples, 0, maxSamples - 1);
                    gl._log.warnf(format("implementation does not support %s samples, fallback to %s samples", samples, newSamples));
                    samples = newSamples;
                }

                try
                {
                    glRenderbufferStorageMultisample(GL_RENDERBUFFER, samples, internalFormat, width, height);
                }
                catch(OpenGLException e)
                {
                    _gl._log.warn(e.msg);
                    goto non_mutisampled; // fallback to non multisampled
                }
            }
            else
            {
            non_mutisampled:
                glRenderbufferStorage(GL_RENDERBUFFER, internalFormat, width, height);
                gl.runtimeCheck();
            }

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

    package
    {
        GLuint _handle;
    }

    private
    {
        OpenGL _gl;
        GLenum _format;
        GLenum _type;
        bool _initialized;
    }
}
