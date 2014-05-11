/// This module defines one texture type for each sort of OpenGL texture.
module gfm.opengl.texture;

import std.string;

import derelict.opengl3.gl3;

import gfm.core.log,
       gfm.opengl.opengl, 
       gfm.opengl.textureunit;

/// OpenGL Texture wrapper.
///
/// TODO:
/// $(UL
///     $(LI Support partial updates.)
///     $(LI Support glStorage through pseudo-code given in OpenGL specification.)
///  )
class GLTexture
{
    public
    {
        /// Creates a texture. You should create a child class instead of calling
        /// this constructor directly.
        /// Throws: $(D OpenGLException) on error.
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

         /// Releases the OpenGL texture resource.
        final void close()
        {
            if (_initialized)
            {
                glDeleteTextures(1, &_handle);
                _initialized = false;
            }
        }

        /// Use this texture, binding it to a texture unit.
        /// Params:
        ///     textureUnit = Index of the texture unit to use.
        final void use(int textureUnit = 0)
        {
            _gl.textureUnits().setActiveTexture(textureUnit);
            bind();
        }

        /// Unuse this texture.
        final void unuse()
        {
          // do nothing: texture unit binding is as needed
        }
        
        /// Returns: Requested texture parameter.
        /// Throws: $(D OpenGLException) on error.
        /// Warning: Calling $(D glGetTexParameteriv) is generally not recommended
        ///          since it could stall the OpenGL pipeline.
        final int getParam(GLenum paramName)
        {
            int res;
            bind();
            glGetTexParameteriv(_target, paramName, &res);
            _gl.runtimeCheck();
            return res;
        }

        /// Returns: Requested texture level parameter.
        /// Throws: $(D OpenGLException) on error.
        /// Warning: Calling $(D glGetTexLevelParameteriv) is generally not recommended
        ///          since it could stall the OpenGL pipeline.
        final int getLevelParam(GLenum paramName, int level)
        {
            int res;
            bind();
            glGetTexLevelParameteriv(_target, level, paramName, &res);
            _gl.runtimeCheck();
            return res;
        }

        /// Sets the texture base level.
        /// Throws: $(D OpenGLException) on error.
        final void setBaseLevel(int level)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_BASE_LEVEL, level);
            _gl.runtimeCheck();
        }

        /// Sets the texture maximum level.
        /// Throws: $(D OpenGLException) on error.
        final void setMaxLevel(int level)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_MAX_LEVEL, level);
            _gl.runtimeCheck();
        }

        // Texture "sampler" parameters which are now in Sampler Objects too
        // but are also here for legacy cards.

        /// Sets the texture minimum LOD.
        /// Throws: $(D OpenGLException) on error.
        final void setMinLOD(float lod)
        {
            bind();
            glTexParameterf(_target, GL_TEXTURE_MIN_LOD, lod);
            _gl.runtimeCheck();
        }

        /// Sets the texture maximum LOD.
        /// Throws: $(D OpenGLException) on error.
        final void setMaxLOD(float lod)
        {
            bind();
            glTexParameterf(_target, GL_TEXTURE_MAX_LOD, lod);
            _gl.runtimeCheck();
        }

        /// Sets the texture LOD bias.
        /// Throws: $(D OpenGLException) on error.
        final void setLODBias(float lodBias)
        {
            bind();
            glTexParameterf(_target, GL_TEXTURE_LOD_BIAS, lodBias);
            _gl.runtimeCheck();
        }

        /// Sets the wrap mode for 1st texture coordinate.
        /// Throws: $(D OpenGLException) on error.
        final void setWrapS(GLenum wrapS)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_WRAP_S, wrapS);
            _gl.runtimeCheck();
        }

        /// Sets the wrap mode for 2nd texture coordinate.
        /// Throws: $(D OpenGLException) on error.
        final void setWrapT(GLenum wrapT)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_WRAP_T, wrapT);
            _gl.runtimeCheck();
        }

        /// Sets the wrap mode for 3rd texture coordinate.
        /// Throws: $(D OpenGLException) on error.
        final void setWrapR(GLenum wrapR)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_WRAP_R, wrapR);
            _gl.runtimeCheck();
        }

        /// Sets the texture minification filter mode.
        /// Throws: $(D OpenGLException) on error.
        final void setMinFilter(GLenum minFilter)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_MIN_FILTER, minFilter);
            _gl.runtimeCheck();
        }

        /// Sets the texture magnification filter mode.
        /// Throws: $(D OpenGLException) on error.
        final void setMagFilter(GLenum magFilter)
        {
            bind();
            glTexParameteri(_target, GL_TEXTURE_MAG_FILTER, magFilter);
            _gl.runtimeCheck();
        }

        /// Sets the texture anisotropic filter level.
        /// If texture anisotropy isn't supported, fail silently.
        /// Throws: $(D OpenGLException) on error.
        final void setMaxAnisotropy(float f)
        {
            assert(f >= 1.0f);
            if (!EXT_texture_filter_anisotropic())
                return;

            auto maxAniso = _gl.maxTextureMaxAnisotropy();

            if (f >= maxAniso)
                f = maxAniso;

            glTexParameterf(_target, GL_TEXTURE_MAX_ANISOTROPY_EXT, f);
            _gl.runtimeCheck();
        }

        /// Gets the texture data.
        /// Throws: $(D OpenGLException) on error.
        final void getTexImage(int level, GLenum format, GLenum type, void* data)
        {
            bind();
            glGetTexImage(_target, level, format, type, data);
            _gl.runtimeCheck();
        }

        /// Returns: Wrapped OpenGL resource handle.
        GLuint handle() pure const nothrow
        {
          return _handle;
        }

        GLuint target() pure const nothrow
        {
            return _target;
        }
		
        /// Regenerates the mipmapped levels.
        /// Throws: $(D OpenGLException) on error.
        void generateMipmap()
        {
            bind();
            glGenerateMipmap(_target);
            _gl.runtimeCheck();
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

/// Wrapper for 1D texture.
final class GLTexture1D : GLTexture
{
    public
    {
        /// Creates a 1D texture.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_1D);
        }

        /// Sets texture content.
        /// Throws: $(D OpenGLException) on error.
        void setImage(int level, GLint internalFormat, int width, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage1D(_target, level, internalFormat, width, border, format, type, data);
            _gl.runtimeCheck();
        }
    }

}

/// Wrapper for 2D texture.
final class GLTexture2D : GLTexture
{
    public
    {
        /// Creates a 2D texture.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_2D);
        }

        /// Sets texture content.
        /// Throws: $(D OpenGLException) on error.
        void setImage(int level, GLint internalFormat, int width, int height, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage2D(_target, level, internalFormat, width, height, border, format, type, data);
            _gl.runtimeCheck();
        }
    }

}

/// Wrapper for 3D texture.
final class GLTexture3D : GLTexture
{
    public
    {
        /// Creates a 3D texture.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_3D);
        }

        /// Sets texture content.
        /// Throws: $(D OpenGLException) on error.
        void setImage(int level, GLint internalFormat, int width, int height, int depth, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage3D(_target, level, internalFormat, width, height, depth, border, format, type, data);
            _gl.runtimeCheck();
        }
    }
}

/// Wrapper for 1D texture array.
final class GLTexture1DArray : GLTexture
{
    public
    {
        /// Creates a 1D texture array.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_1D_ARRAY);
        }

        /// Sets texture content.
        /// Throws: $(D OpenGLException) on error.
        void setImage(int level, GLint internalFormat, int width, int height, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage2D(_target, level, internalFormat, width, height, border, format, type, null);
            _gl.runtimeCheck();
        }
    }
}

/// Wrapper for 2D texture array.
final class GLTexture2DArray : GLTexture
{
    public
    {
        /// Creates a 2D texture array.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_2D_ARRAY);
        }

        /// Sets texture content.
        /// Throws: $(D OpenGLException) on error.
        void setImage(int level, GLint internalFormat, int width, int height, int depth, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage3D(_target, level, internalFormat, width, height, depth, border, format, type, data);
            _gl.runtimeCheck();
        }

        /// Sets partial texture content.
        /// Throws: $(D OpenGLException) on error.
        void setSubImage(int level, int xoffset, int yoffset, int zoffset, int width, int height, int depth, GLenum format, GLenum type, void* data)
        {
            glTexSubImage3D(_target, level, xoffset, yoffset, zoffset, width, height, depth, format, type, data);
            _gl.runtimeCheck();
        }
    }
}

/// Wrapper for texture rectangle.
final class GLTextureRectangle : GLTexture
{
    public
    {
        /// Creates a texture rectangle.
        /// Throws: $(D OpenGLException) on error.        
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_RECTANGLE);
        }

        /// Sets texture content.
        /// Throws: $(D OpenGLException) on error.
        void setImage(int level, GLint internalFormat, int width, int height, int border, GLenum format, GLenum type, void* data)
        {
            glTexImage2D(_target, level, internalFormat, width, height, border, format, type, null);
            _gl.runtimeCheck();
        }
    }
}

/// Wrapper for 2D multisampled texture.
final class GLTexture2DMultisample : GLTexture
{
    public
    {
        /// Creates a 2D multisampled texture.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_2D_MULTISAMPLE);
        }

        /// Sets texture content.
        /// Throws: $(D OpenGLException) on error.
        void setImage(int level, int samples, GLint internalFormat, int width, int height, bool fixedsamplelocations)
        {
            glTexImage2DMultisample(_target, samples, internalFormat, width, height, fixedsamplelocations ? GL_TRUE : GL_FALSE);
            _gl.runtimeCheck();
        }
    }
}

/// Wrapper for 2D multisampled texture array.
final class GLTexture2DMultisampleArray : GLTexture
{
    public
    {
        /// Creates a 2D multisampled texture array.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl)
        {
            super(gl, GL_TEXTURE_2D_MULTISAMPLE_ARRAY);
        }

        /// Sets texture content.
        /// Throws: $(D OpenGLException) on error.
        void setImage(int level, int samples, GLint internalFormat, int width, int height, int depth, bool fixedsamplelocations)
        {
            glTexImage3DMultisample(_target, samples, internalFormat, width, height, depth, fixedsamplelocations ? GL_TRUE : GL_FALSE);
            _gl.runtimeCheck();
        }
    }
}


