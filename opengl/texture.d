module gfm.opengl.texture;

import std.string;

import derelict.opengl3.gl3;

import gfm.common.log;
import gfm.opengl.opengl, gfm.opengl.exception;

final class GLTexture
{
    public
    {
        this(OpenGL gl, GLuint target)
        {
            _gl = gl;
            _target = target;
            glGenTextures(1, &_handle);
            _gl.runtimeCheck();
            _initialized = true;
            _textureUnit = -1;
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_initialized)
            {
                glDeleteTextures(1, &_handle);
                _initialized = false;
            }
        }

        void use(int textureUnit = 0)
        {
            glActiveTexture(GL_TEXTURE0 + textureUnit);
            glBindTexture(_target, _handle);
            _gl.runtimeCheck();
            _textureUnit = textureUnit;
        }

        void unuse()
        {   
            if (_textureUnit == -1)
                throw new OpenGLException("Texture was not bound");
            glBindTexture(_target, 0);
            _textureUnit = -1;
            _gl.runtimeCheck();
        }
    }

    private
    {
        OpenGL _gl;
        GLuint  _handle;
        GLuint _target;
        bool _initialized;    
        int _textureUnit;
    }
}
