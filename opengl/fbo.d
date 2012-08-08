module gfm.opengl.fbo;

import std.string;

import derelict.opengl3.gl3;
import gfm.common.log;
import gfm.opengl.opengl;
import gfm.opengl.texture, gfm.opengl.renderbuffer;

// OpenGL FrameBuffer Object wrapper
// TODO: GL_EXT_framebuffer_object fallback
final class GLFBO
{
    public
    {
        enum Usage
        {
            DRAW,
            READ
        }

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

        void close()
        {
            if (_initialized)
            {
                // detach all
                for(int i = 0; i < _colors.length; ++i)
                    _colors[i].close();

                _depth.close();
                _stencil.close();

                glDeleteFramebuffers(1, &_handle);
                _initialized = false;
            }
        }

        void use()
        {
            glBindFramebuffer(_target, _handle);
            _gl.runtimeCheck();
            _isBound = true;

            for(int i = 0; i < _colors.length; ++i)
                _colors[i].updateAttachment();
        }

        void unuse()
        {
            _isBound = false;
            glBindFramebuffer(_target, 0);
            _gl.runtimeCheck();
        }

       // get color attachment
       GLFBOAttachment color(int i)
       {
           return _colors[i];
       }

       GLFBOAttachment depth()
       {
           return _depth;
       }

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
            GLenum status = glCheckFramebufferStatus(_target);
            switch(status)
            {
                case GL_FRAMEBUFFER_COMPLETE:
                    return;

                case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT");

                case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT");
/*
                case GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_EXT:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_EXT");

                case GL_FRAMEBUFFER_INCOMPLETE_FORMATS_EXT:
                    throw new OpenGLException("GL_FRAMEBUFFER_INCOMPLETE_FORMATS_EXT");
*/
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

// TODO make effective attachement lazy and cached
class GLFBOAttachment
{
    public
    {
        void attach(GLTexture1D tex, int level = 0)
        {
            _newCall = Call(this, Call.Type.TEXTURE_1D, tex, null, level, 0);
            updateAttachment();
        }

        void attach(GLTexture2D tex, int level = 0)
        {
            _newCall = Call(this, Call.Type.TEXTURE_2D, tex, null, level, 0);
            updateAttachment();
        }

        void attach(GLTexture3D tex, int layer, int level)
        {
            _newCall = Call(this, Call.Type.TEXTURE_3D, tex, null, level, layer);            
            updateAttachment();
        }

        void attach(GLTexture1DArray tex, int layer)
        {
            _newCall = Call(this, Call.Type.TEXTURE_3D, tex, null, 0, layer);
            updateAttachment();
        }

        void attach(GLTexture2DArray tex, int layer)
        {
            _newCall = Call(this, Call.Type.TEXTURE_3D, tex, null, 0, layer);
            updateAttachment();
        }

        void attach(GLTextureRectangle tex)
        {
            _newCall = Call(this, Call.Type.TEXTURE_2D, tex, null, 0, 0);
            updateAttachment();
        }

        void attach(GLTexture2DMultisample tex)
        {
            _newCall = Call(this, Call.Type.TEXTURE_2D, tex, null, 0, 0);
            updateAttachment();
        }

        void attach(GLTexture2DMultisampleArray tex, int layer)
        {
            _newCall = Call(this, Call.Type.TEXTURE_3D, tex, null, 0, layer);
            updateAttachment();
        }

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
                    final switch(_type)
                    {
                        case Type.DISABLED:
                            // do nothing
                            break;

                        case Type.TEXTURE_1D:
                            glFramebufferTexture1D(_outer._fbo._target, _outer._attachment, _texture._target, _texture._handle, _level);
                            _outer._gl.runtimeCheck();
                            break;

                        case Type.TEXTURE_2D: 
                            glFramebufferTexture2D(_outer._fbo._target, _outer._attachment, _texture._target, _texture._handle, _level);
                            _outer._gl.runtimeCheck();
                            break;

                        case Type.TEXTURE_3D: 
                            glFramebufferTexture3D(_outer._fbo._target, _outer._attachment, _texture._target, _texture._handle, _level, _layer);
                            _outer._gl.runtimeCheck();
                            break;

                        case Type.RENDERBUFFER: 
                            glFramebufferRenderbuffer(_outer._fbo._target, _outer._attachment, GL_RENDERBUFFER, _renderbuffer._handle);
                            _outer._gl.runtimeCheck();
                            break;
                    }
                }

                void detach()
                {
                    final switch(_type)
                    {
                        case Type.DISABLED:
                            // do nothing
                            break;

                        case Type.TEXTURE_1D:
                            glFramebufferTexture1D(_outer._fbo._target, _outer._attachment, 0, 0, _level);
                            _outer._gl.runtimeCheck();
                            break;

                        case Type.TEXTURE_2D: 
                            glFramebufferTexture2D(_outer._fbo._target, _outer._attachment, 0, 0, _level);
                            _outer._gl.runtimeCheck();
                            break;

                        case Type.TEXTURE_3D: 
                            glFramebufferTexture3D(_outer._fbo._target, _outer._attachment, 0, 0, _level, _layer);
                            _outer._gl.runtimeCheck();
                            break;

                        case Type.RENDERBUFFER: 
                            glFramebufferRenderbuffer(_outer._fbo._target, _outer._attachment, GL_RENDERBUFFER, 0);
                            _outer._gl.runtimeCheck();
                            break;
                    }
                }
            }
        }
    }
}
