module gfm.opengl.texture;

import std.string;

import derelict.opengl3.gl3;

import gfm.common.log;
import gfm.opengl.opengl, gfm.opengl.exception, gfm.opengl.textureunit;

class GLTexture
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

        final void close()
        {
            if (_initialized)
            {
                glDeleteTextures(1, &_handle);
                _initialized = false;
            }
        }

        final void use(int textureUnit = 0)
        {
            bind();
        }

        final void unuse()
        {
          // do nothing: texture unit binding is as needed
        }

        final int getParam(GLenum paramName)
        {
            int res;
            bind();
            glGetTexParameteriv(_target, paramName, &res);
            _gl.runtimeCheck();
            return res;
        }

        final int getLevelParam(GLenum paramName, int level)
        {
            int res;
            bind();
            glGetTexLevelParameteriv(_target, level, paramName, &res);
            _gl.runtimeCheck();
            return res;
        }
    }

    private
    {
        OpenGL _gl;
        GLuint  _handle;
        GLuint _target;
        bool _initialized;    
        int _textureUnit;

        void bind()
        {
            // bind on whatever the current texture unit is
            _gl.textureUnits().current().bind(_target, _handle);
        }
    }
}
