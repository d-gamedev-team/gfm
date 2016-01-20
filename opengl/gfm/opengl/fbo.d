module gfm.opengl.fbo;

import std.string;

import derelict.opengl3.gl3;

import std.experimental.logger;

import gfm.opengl.opengl,
       gfm.opengl.texture,
       gfm.opengl.renderbuffer;

/// OpenGL FrameBuffer Object wrapper.
final class GLFBO
{
    public
    {
        /// FBO usage.
        enum Usage
        {
            DRAW, /// This FBO will be used for drawing.
            READ  /// This FBO will be used for reading.
        }

        /// Creates one FBO, with specified usage. OpenGL must have been loaded.
        /// $(D ARB_framebuffer_object) must be supported.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl, Usage usage = Usage.DRAW)
        {
            _gl = gl;
            glGenFramebuffers(1, &_handle);
            _gl.runtimeCheck();

            _colors.length = _gl.maxColorAttachments();
            for(int i = 0; i < _colors.length; ++i)
                _colors[i] = new GLFBOAttachment(this, GL_COLOR_ATTACHMENT0 + i);

            _depth = new GLFBOAttachment(this, GL_DEPTH_ATTACHMENT);
            _stencil = new GLFBOAttachment(this, GL_STENCIL_ATTACHMENT);
            _depthStencil = new GLFBOAttachment(this, GL_DEPTH_STENCIL_ATTACHMENT);

            setUsage(usage);

            _initialized = true;
            _isBound = false;
        }

        auto usage() pure const nothrow @nogc
        {
            return _usage;
        }

        void setUsage(Usage usage) nothrow @nogc
        {
            _usage = usage;
            final switch(usage)
            {
                case Usage.DRAW:
                    _target = GL_DRAW_FRAMEBUFFER;
                    break;
                case Usage.READ:
                    _target = GL_READ_FRAMEBUFFER;
            }
        }

        /// Releases the OpenGL FBO resource.
        ~this()
        {
            if (_initialized)
            {
                ensureNotInGC("GLFBO");
                glBindFramebuffer(_target, _handle);

                // detach all
                for(int i = 0; i < _colors.length; ++i)
                    _colors[i].close();

                _depth.close();
                _stencil.close();

                glDeleteFramebuffers(1, &_handle);
                _initialized = false;
            }
        }

        /// Binds this FBO.
        /// Throws: $(D OpenGLException) on error.
        void use()
        {
            glBindFramebuffer(_target, _handle);

            _gl.runtimeCheck();
            _isBound = true;

            for(int i = 0; i < _colors.length; ++i)
                _colors[i].updateAttachment();
        }

        /// Unbinds this FBO.
        /// Throws: $(D OpenGLException) on error.
        void unuse()
        {
            _isBound = false;
            glBindFramebuffer(_target, 0);

            _gl.runtimeCheck();
        }

       /// Returns: A FBO color attachment.
       /// Params:
       ///     i = Index of color attachment.
       GLFBOAttachment color(int i)
       {
           return _colors[i];
       }

       /// Returns: FBO depth attachment.
       GLFBOAttachment depth()
       {
           return _depth;
       }

       /// Returns: FBO stencil attachment.
       GLFBOAttachment stencil()
       {
           return _stencil;
       }
    }

    private
    {
        OpenGL _gl;
        GLuint  _handle;
        bool _initialized, _isBound;

        // attachements
        GLFBOAttachment[] _colors;
        GLFBOAttachment _depth, _stencil, _depthStencil;

        Usage _usage;
        GLenum _target; // redundant

        void checkStatus()
        {
            GLenum status = void;
            status = glCheckFramebufferStatus(_target);

            switch(status)
            {
                case GL_FRAMEBUFFER_COMPLETE:
                    return;

                case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT");

                case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT");

                case GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_EXT:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_EXT");

                case GL_FRAMEBUFFER_INCOMPLETE_FORMATS_EXT:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_FORMATS_EXT");

                case GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER");

                case GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER");

                case GL_FRAMEBUFFER_UNSUPPORTED:
                    throw new OpenGLException("GL_FRAMEBUFFER_UNSUPPORTED");

                default: throw new OpenGLException("Unknown FBO error");
            }
        }
    }
}

/// Defines one FBO attachment.
final class GLFBOAttachment
{
    public
    {
        /// Attaches a 1D texture to the FBO.
        /// Throws: $(D OpenGLException) on error.
        void attach(GLTexture1D tex, int level = 0)
        {
            _newCall = Call(this, Call.Type.TEXTURE_1D, tex, null, level, 0);
            updateAttachment();
        }

        /// Attaches a 2D texture to the FBO.
        /// Throws: $(D OpenGLException) on error.
        void attach(GLTexture2D tex, int level = 0)
        {
            _newCall = Call(this, Call.Type.TEXTURE_2D, tex, null, level, 0);
            updateAttachment();
        }

        /// Attaches a 3D texture to the FBO.
        /// Throws: $(D OpenGLException) on error.
        void attach(GLTexture3D tex, int layer, int level)
        {
            _newCall = Call(this, Call.Type.TEXTURE_3D, tex, null, level, layer);
            updateAttachment();
        }

        /// Attaches a 1D texture array to the FBO.
        /// Throws: $(D OpenGLException) on error.
        void attach(GLTexture1DArray tex, int layer)
        {
            _newCall = Call(this, Call.Type.TEXTURE_3D, tex, null, 0, layer);
            updateAttachment();
        }

        /// Attaches a 2D texture array to the FBO.
        /// Throws: $(D OpenGLException) on error.
        void attach(GLTexture2DArray tex, int layer)
        {
            _newCall = Call(this, Call.Type.TEXTURE_3D, tex, null, 0, layer);
            updateAttachment();
        }

        /// Attaches a rectangle texture to the FBO.
        /// Throws: $(D OpenGLException) on error.
        void attach(GLTextureRectangle tex)
        {
            _newCall = Call(this, Call.Type.TEXTURE_2D, tex, null, 0, 0);
            updateAttachment();
        }

        /// Attaches a multisampled 2D texture to the FBO.
        /// Throws: $(D OpenGLException) on error.
        void attach(GLTexture2DMultisample tex)
        {
            _newCall = Call(this, Call.Type.TEXTURE_2D, tex, null, 0, 0);
            updateAttachment();
        }

        /// Attaches a multisampled 2D texture array to the FBO.
        /// Throws: $(D OpenGLException) on error.
        void attach(GLTexture2DMultisampleArray tex, int layer)
        {
            _newCall = Call(this, Call.Type.TEXTURE_3D, tex, null, 0, layer);
            updateAttachment();
        }

        /// Attaches a renderbuffer to the FBO.
        /// Throws: $(D OpenGLException) on error.
        void attach(GLRenderBuffer buffer)
        {
            _newCall = Call(this, Call.Type.RENDERBUFFER, null, buffer, 0, 0);
            updateAttachment();
        }
    }

    private
    {
        this(GLFBO fbo, GLenum attachment)
        {
            _fbo = fbo;
            _gl = fbo._gl;
            _attachment = attachment;
            _lastCall = _newCall = Call(this, Call.Type.DISABLED, null, null, 0, 0);
        }

        // guaranteed to be called once
        void close()
        {
            _lastCall.detach();
        }

        OpenGL _gl;
        GLFBO _fbo;
        GLenum _attachment;
        Call _lastCall;
        Call _newCall;

        void updateAttachment()
        {
            if (_newCall != _lastCall && _fbo._isBound)
            {
                try
                {
                    // trying to detach existing attachment
                    // would that help?
                    _lastCall.detach();
                }
                catch(OpenGLException e)
                {
                    // ignoring errors here
                }

                _newCall.attach();
                _lastCall = _newCall;
            }
        }

        struct Call
        {
            public
            {
                enum Type
                {
                    DISABLED,
                    TEXTURE_1D,
                    TEXTURE_2D,
                    TEXTURE_3D,
                    RENDERBUFFER
                }

                GLFBOAttachment _outer;
                Type _type;
                GLTexture _texture;
                GLRenderBuffer _renderbuffer;
                GLint _level;
                GLint _layer;

                void attach()
                {
                    GLuint textureHandle = _texture !is null ? _texture.handle() : 0;
                    GLuint renderBufferHandle = _renderbuffer !is null ? _renderbuffer.handle() : 0;
                    attachOrDetach(textureHandle, renderBufferHandle);
                }

                void detach()
                {
                    attachOrDetach(0, 0);
                }

                void attachOrDetach(GLuint textureHandle, GLuint renderBufferHandle)
                {
                    final switch(_type)
                    {
                        case Type.DISABLED:
                            return; // do nothing

                        case Type.TEXTURE_1D:
                            glFramebufferTexture1D(_outer._fbo._target, _outer._attachment, _texture._target, textureHandle, _level);
                            break;

                        case Type.TEXTURE_2D:
                            glFramebufferTexture2D(_outer._fbo._target, _outer._attachment, _texture._target, textureHandle, _level);
                            break;

                        case Type.TEXTURE_3D:
                            glFramebufferTexture3D(_outer._fbo._target, _outer._attachment, _texture._target, textureHandle, _level, _layer);
                            break;

                        case Type.RENDERBUFFER:
                            glFramebufferRenderbuffer(_outer._fbo._target, _outer._attachment, GL_RENDERBUFFER, renderBufferHandle);
                            break;
                    }
                    _outer._gl.runtimeCheck();
                }
            }
        }
    }
}
