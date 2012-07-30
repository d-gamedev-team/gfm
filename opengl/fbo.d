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
                    _colors[i].detach();

                _depth.detach();
                _stencil.detach();

                glDeleteFramebuffers(1, &_handle);                
                _initialized = false;
            }
        }

        void use()
        {
            glBindFramebuffer(_target, _handle);
            _gl.runtimeCheck();        
        }

        void unuse()
        {
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
        bool _initialized;

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
            _texture = tex;
            _level = level;
            _call = Call.TEXTURE_1D;
            actualAttach();
        }

        void attach(GLTexture2D tex, int level = 0)
        {
            _texture = tex;
            _level = level;
            _call = Call.TEXTURE_2D;
            actualAttach();
        }

        void attach(GLTexture3D tex, int layer, int level)
        {
            _texture = tex;
            _level = level;
            _layer = layer;
            _call = Call.TEXTURE_3D;
            actualAttach();
        }

        void attach(GLTexture1DArray tex, int layer)
        {
            _texture = tex;
            _level = 0;
            _layer = layer;
            _call = Call.TEXTURE_3D;
            actualAttach();
        }

        void attach(GLTexture2DArray tex, int layer)
        {
            _texture = tex;
            _level = 0;
            _layer = layer;
            _call = Call.TEXTURE_3D;
            actualAttach();
        }

        void attach(GLTextureRectangle tex)
        {
            _texture = tex;
            _call = Call.TEXTURE_2D;
            _level = 0;
            actualAttach();
        }

        void attach(GLTexture2DMultisample tex)
        {
            _texture = tex;
            _level = 0;
            _call = Call.TEXTURE_2D;
            actualAttach();
        }

        void attach(GLTexture2DMultisampleArray tex, int layer)
        {
            _texture = tex;
            _level = 0;
            _layer = layer;
            _call = Call.TEXTURE_3D;
            actualAttach();
        }

        void attach(GLRenderBuffer buffer)
        {
            _renderbuffer = buffer;
            _call = Call.RENDERBUFFER;
            actualAttach();
        }

        bool isUsed()
        {
            return _call != 0;
        }
    }

    private
    {
        this(GLFBO fbo, GLenum attachment)
        {
            _fbo = fbo;
            _gl = fbo._gl;
            _attachment = attachment;
            _call = Call.DISABLED;
        }

        OpenGL _gl;
        GLFBO _fbo;
        GLenum _attachment;

        enum Call
        {
            DISABLED,
            TEXTURE_1D,
            TEXTURE_2D,
            TEXTURE_3D,
            RENDERBUFFER
        }

        Call _call;
        GLTexture _texture;
        GLRenderBuffer _renderbuffer;
        GLint _level;
        GLint _layer;

        void actualAttach()
        {
            final switch(_call)
            {
                case Call.DISABLED:
                    // do nothing
                    break;

                case Call.TEXTURE_1D:
                    glFramebufferTexture1D(_fbo._target, _attachment, _texture._target, _texture._handle, _level);
                    _gl.runtimeCheck();
                    break;

                case Call.TEXTURE_2D: 
                    glFramebufferTexture2D(_fbo._target, _attachment, _texture._target, _texture._handle, _level);
                    _gl.runtimeCheck();
                    break;

                case Call.TEXTURE_3D: 
                    glFramebufferTexture3D(_fbo._target, _attachment, _texture._target, _texture._handle, _level, _layer);
                    _gl.runtimeCheck();
                    break;

                case Call.RENDERBUFFER: 
                    glFramebufferRenderbuffer(_fbo._target, _attachment, GL_RENDERBUFFER, _renderbuffer._handle);
                    _gl.runtimeCheck();
                    break;
            }
        }

        void detach()
        {
            final switch(_call)
            {
                case Call.DISABLED:
                    // do nothing
                    break;

                case Call.TEXTURE_1D:
                    glFramebufferTexture1D(_fbo._target, _attachment, 0, 0, _level);
                    _gl.runtimeCheck();
                    break;

                case Call.TEXTURE_2D: 
                    glFramebufferTexture2D(_fbo._target, _attachment, 0, 0, _level);
                    _gl.runtimeCheck();
                    break;

                case Call.TEXTURE_3D: 
                    glFramebufferTexture3D(_fbo._target, _attachment, 0, 0, _level, _layer);
                    _gl.runtimeCheck();
                    break;

                case Call.RENDERBUFFER: 
                    glFramebufferRenderbuffer(_fbo._target, _attachment, GL_RENDERBUFFER, 0);
                    _gl.runtimeCheck();
                    break;
            }
            _call = Call.DISABLED;
        }
    }
}
