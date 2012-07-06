module gfm.opengl.texture;

import std.string;

import derelict.opengl3.gl3;

import gfm.common.log;
import gfm.opengl.opengl, gfm.opengl.exception, gfm.opengl.textureunit;

// define one texture type for each sort of texture

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

        // warning: can stall the pipeline
        // there is no good reason to call it unless for debugging
        final int getParam(GLenum paramName)
        {
            int res;
            bind();
            glGetTexParameteriv(_target, paramName, &res);
            _gl.runtimeCheck();
            return res;
        }

        // warning: can stall the pipeline
        // there is no good reason to call it unless for debugging
        final int getLevelParam(GLenum paramName, int level)
        {
            int res;
            bind();
            glGetTexLevelParameteriv(_target, level, paramName, &res);
            _gl.runtimeCheck();
            return res;
        }

        // texture parameters

        final void setBaseLevel(int level)
        {
            glTexParameteri(_target, GL_TEXTURE_BASE_LEVEL, level);
        }

        final void setMaxLevel(int level)
        {
            glTexParameteri(_target, GL_TEXTURE_MAX_LEVEL, level);
        }

        // texture "sampler" parameters which are now in Sampler Objects too
        // but are also here legacy cards

        final void setMinLOD(float lod)
        {
            glTexParameterf(_target, GL_TEXTURE_MIN_LOD, lod);
        }

        final void setMaxLOD(float lod)
        {
            glTexParameterf(_target, GL_TEXTURE_MAX_LOD, lod);
        }

        final void setLODBias(float lodBias)
        {
            glTexParameterf(_target, GL_TEXTURE_LOD_BIAS, lodBias);
        }

        final void setWrapS(GLenum wrapS)
        {
            glTexParameteri(_target, GL_TEXTURE_WRAP_S, wrapS);
        }

        final void setWrapT(GLenum wrapT)
        {
            glTexParameteri(_target, GL_TEXTURE_WRAP_T, wrapT);
        }

        final void setWrapR(GLenum wrapR)
        {
            glTexParameteri(_target, GL_TEXTURE_WRAP_R, wrapR);
        }

        final void setMinFilter(GLenum minFilter)
        {
            glTexParameteri(_target, GL_TEXTURE_MIN_FILTER, minFilter);
        }

        final void setMagFilter(GLenum magFilter)
        {
            glTexParameteri(_target, GL_TEXTURE_MAG_FILTER, magFilter);
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

final class GLTexture1D : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_1D);
        }
    }

}

final class GLTexture2D : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_2D);
        }
    }

}

final class GLTexture3D : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_3D);
        }
    }

}

final class GLTexture1DArray : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_1D_ARRAY);
        }
    }
}

final class GLTexture2DArray : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_2D_ARRAY);
        }
    }
}

final class GLTextureRectangle : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_RECTANGLE);
        }
    }

}

final class GLTextureBuffer : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_BUFFER);
        }
    }
}

final class GLTextureCubeMap : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_CUBE_MAP);
        }
    }
}

final class GLTextureCubeMapArray : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_CUBE_MAP_ARRAY);
        }
    }
}

final class GLTexture2DMultisample : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_2D_MULTISAMPLE);
        }
    }
}

final class GLTexture2DMultisampleArray : GLTexture
{
    public
    {
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_2D_MULTISAMPLE_ARRAY);
        }
    }
}
