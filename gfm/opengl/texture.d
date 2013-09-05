module gfm.opengl.texture;

import std.string;

import derelict.opengl3.gl3;

import gfm.common.log,
       gfm.opengl.opengl, 
       gfm.opengl.textureunit;

// define one texture type for each sort of texture
// TODO: - support partial updates
//       - support glStorage throught pseudo-code given in the spec 

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
            _gl.textureUnits().setActiveTexture(textureUnit);
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
            bind();
            glTexParameteri(_target, GL_TEXTURE_BASE_LEVEL, level);
        }

        final void setMaxLevel(int level)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_MAX_LEVEL, level);
        }

        // texture "sampler" parameters which are now in Sampler Objects too
        // but are also here legacy cards

        final void setMinLOD(float lod)
        {
            bind();
            glTexParameterf(_target, GL_TEXTURE_MIN_LOD, lod);
        }

        final void setMaxLOD(float lod)
        {
            bind();
            glTexParameterf(_target, GL_TEXTURE_MAX_LOD, lod);
        }

        final void setLODBias(float lodBias)
        {
            bind();
            glTexParameterf(_target, GL_TEXTURE_LOD_BIAS, lodBias);
        }

        final void setWrapS(GLenum wrapS)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_WRAP_S, wrapS);
        }

        final void setWrapT(GLenum wrapT)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_WRAP_T, wrapT);
        }

        final void setWrapR(GLenum wrapR)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_WRAP_R, wrapR);
        }

        final void setMinFilter(GLenum minFilter)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_MIN_FILTER, minFilter);
        }

        final void setMagFilter(GLenum magFilter)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_MAG_FILTER, magFilter);
        }

        // anisotropy level
        final void setMaxAnisotropy(float f)
        {
            assert(f >= 1.0f);
            if (!EXT_texture_filter_anisotropic())
                return;

            auto maxAniso = _gl.maxTextureMaxAnisotropy();

            if (f >= maxAniso)
                f = maxAniso;

            glTexParameterf(_target, GL_TEXTURE_MAX_ANISOTROPY_EXT, f);
        }

        GLuint handle() pure const nothrow
        {
          return _handle;
        }
    }

    package
    {
        GLuint _target;
    }

    private
    {
        OpenGL _gl;
        GLuint _handle;
        bool _initialized;
        int _textureUnit;

        void bind()
        {
            // Bind on whatever the current texture unit is!
            // consequently, do not ever change texture parameters if you want 
            // to rely on a texture being bound to a texture unit
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

        void setImage(int level, GLint internalFormat, int width, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage1D(_target, level, internalFormat, width, border, format, type, data);
            _gl.runtimeCheck();
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

        void setImage(int level, GLint internalFormat, int width, int height, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage2D(_target, level, internalFormat, width, height, border, format, type, data);
            _gl.runtimeCheck();
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

        void setImage(int level, GLint internalFormat, int width, int height, int depth, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage3D(_target, level, internalFormat, width, height, depth, border, format, type, data);
            _gl.runtimeCheck();
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

        void setImage(int level, GLint internalFormat, int width, int height, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage2D(_target, level, internalFormat, width, height, border, format, type, null);
            _gl.runtimeCheck();
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

        void setImage(int level, GLint internalFormat, int width, int height, int depth, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage3D(_target, level, internalFormat, width, height, depth, border, format, type, data);
            _gl.runtimeCheck();
        }

        void setSubImage(int level, int xoffset, int yoffset, int zoffset, int width, int height, int depth, GLenum format, GLenum type, void* data)
        {
            glTexSubImage3D(_target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, data);
            _gl.runtimeCheck();
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

        void setImage(int level, GLint internalFormat, int width, int height, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage2D(_target, level, internalFormat, width, height, border, format, type, null);
            _gl.runtimeCheck();
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

        void setImage(int level, int samples, GLint internalFormat, int width, int height, bool fixedsamplelocations)
        {
            glTexImage2DMultisample(_target, samples, internalFormat, width, height, fixedsamplelocations ? GL_TRUE : GL_FALSE);
            _gl.runtimeCheck();
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

        void setImage(int level, int samples, GLint internalFormat, int width, int height, int depth, bool fixedsamplelocations)
        {
            glTexImage3DMultisample(_target, samples, internalFormat, width, height, depth, fixedsamplelocations ? GL_TRUE : GL_FALSE);
            _gl.runtimeCheck();
        }
    }
}


