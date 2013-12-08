module gfm.opengl.fbo;

import std.string;

import derelict.opengl3.gl3;

import gfm.core.log,
       gfm.opengl.opengl,
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
        /// $(D EXT_framebuffer_object) is used as a fallback if $(D ARB_framebuffer_object) is missing.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl, Usage usage = Usage.DRAW)
        {
            if (glGenFramebuffers !is null)
                _useEXTFallback = false;
            else if (EXT_framebuffer_object())
            {
                gl._log.warn("ARB_framebuffer_object missing, using EXT_framebuffer_object as fallback");
                _useEXTFallback = true;
            }
            else
                throw new OpenGLException("Neither ARB_framebuffer_object nor EXT_framebuffer_object are supported");

            if (_useEXTFallback && usage == Usage.READ)
                throw new OpenGLException("Unable to read FBO using EXT_framebuffer_object");

            _gl = gl;
            if (_useEXTFallback)
                glGenFramebuffersEXT(1, &_handle);
            else
                glGenFramebuffers(1, &_handle);
            _gl.runtimeCheck();

            _colors.length = _gl.maxColorAttachments();
            for(int i = 0; i < _colors.length; ++i)
                _colors[i] = new GLFBOAttachment(this, GL_COLOR_ATTACHMENT0 + i);

            _depth = new GLFBOAttachment(this, GL_DEPTH_ATTACHMENT);
            _stencil = new GLFBOAttachment(this, GL_STENCIL_ATTACHMENT);
            _depthStencil = new GLFBOAttachment(this, GL_DEPTH_STENCIL_ATTACHMENT);

            _usage = usage;
            final switch(usage)
            {
                case Usage.DRAW:
                    _target = GL_DRAW_FRAMEBUFFER;
                    break;
                case Usage.READ:
                    _target = GL_READ_FRAMEBUFFER;
            }
            _initialized = true;
            _isBound = false;
        }

        ~this()
        {
            close();
        }

        /// Releases the OpenGL FBO resource.
        void close()
        {
            if (_initialized)
            {
                // detach all
                for(int i = 0; i < _colors.length; ++i)
                    _colors[i].close();

                _depth.close();
                _stencil.close();

                if (_useEXTFallback)
                    glDeleteFramebuffersEXT(1, &_handle);
                else
                    glDeleteFramebuffers(1, &_handle);
                _initialized = false;
            }
        }

        /// Binds this FBO.
        /// Throws: $(D OpenGLException) on error.
        void use()
        {
            if (_useEXTFallback)
                glBindFramebufferEXT(_target, _handle);
            else
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
            if (_useEXTFallback)
                glBindFramebufferEXT(_target, 0);
            else
                glBindFramebuffer(_target, 0);

            _gl.runtimeCheck();
        }

       /// Gets a color attachment.
       /// Params:
       ///     i = index of color attachment.
       GLFBOAttachment color(int i)
       {
           return _colors[i];
       }

       /// Gets the depth attachment.
       GLFBOAttachment depth()
       {
           return _depth;
       }

       /// Gets the stencil attachment.
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
        bool _useEXTFallback;

        // attachements
        GLFBOAttachment[] _colors;
        GLFBOAttachment _depth, _stencil, _depthStencil;

        Usage _usage;
        GLenum _target; // redundant

        void checkStatus()
        {
            GLenum status = void;
            if (_useEXTFallback)
                status = glCheckFramebufferStatusEXT(_target);
            else
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
class GLFBOAttachment
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
            _lastCall.detach(_fbo._useEXTFallback);
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
                    _lastCall.detach(_fbo._useEXTFallback);
                }
                catch(OpenGLException e)
                {
                    // ignoring errors here
                }

                _newCall.attach(_fbo._useEXTFallback);
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

                void attach(bool useEXTFallback)
                {
                    attachOrDetach(useEXTFallback, _texture.handle(), _renderbuffer._handle);
                }

                void detach(bool useEXTFallback)
                {
                    attachOrDetach(useEXTFallback, 0, 0);
                }

                void attachOrDetach(bool useEXTFallback, GLuint textureHandle, GLuint renderBufferHandle)
                {
                    final switch(_type)
                    {
                        case Type.DISABLED:
                            return; // do nothing

                        case Type.TEXTURE_1D:
                            if (useEXTFallback)
                                glFramebufferTexture1DEXT(_outer._fbo._target, _outer._attachment, _texture._target, textureHandle, _level);
                            else
                                glFramebufferTexture1D(_outer._fbo._target, _outer._attachment, _texture._target, textureHandle, _level);
                            break;

                        case Type.TEXTURE_2D:
                            if (useEXTFallback)
                                glFramebufferTexture2DEXT(_outer._fbo._target, _outer._attachment, _texture._target, textureHandle, _level);
                            else
                                glFramebufferTexture2D(_outer._fbo._target, _outer._attachment, _texture._target, textureHandle, _level);
                            break;

                        case Type.TEXTURE_3D: 
                            if (useEXTFallback)
                                glFramebufferTexture3DEXT(_outer._fbo._target, _outer._attachment, _texture._target, textureHandle, _level, _layer);
                            else
                                glFramebufferTexture3D(_outer._fbo._target, _outer._attachment, _texture._target, textureHandle, _level, _layer);
                            break;

                        case Type.RENDERBUFFER: 
                            if (useEXTFallback)
                                glFramebufferRenderbufferEXT(_outer._fbo._target, _outer._attachment, GL_RENDERBUFFER, renderBufferHandle);
                            else
                                glFramebufferRenderbuffer(_outer._fbo._target, _outer._attachment, GL_RENDERBUFFER, renderBufferHandle);
                            break;
                    }
                    _outer._gl.runtimeCheck();
                }
            }
        }
    }
}
