module gfm.opengl.opengl;

import std.string,
       std.conv,
       std.array;

import derelict.opengl3.gl3,
       derelict.opengl3.gl;

import gfm.common.log,
       gfm.common.text,
       gfm.opengl.textureunit;

class OpenGLException : Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
        }
    }
}

// wrapper class to ensure library loading
final class OpenGL
{
    public
    {
        this(Log log)
        {
            _log = log is null ? new NullLog() : log;
            DerelictGL3.load(); // load latest available version

            DerelictGL.load(); // load deprecated functions too

            _log.infof("OpenGL loaded, version %s", DerelictGL3.loadedVersion());

            // do not log here since unimportant errors might happen:
            // no context is necessarily created at this point
            getLimits(false); 

            _textureUnits = new TextureUnits(this);
        }

        ~this()
        {
            close();
        }

        // once an OpenGL context exist, reload to get the context you want
        void reload()
        {
            DerelictGL3.reload();
            _log.infof("OpenGL reloaded, version %s", DerelictGL3.loadedVersion());
            _log.infof("    Version: %s", getVersionString());
            _log.infof("    Renderer: %s", getRendererString());
            _log.infof("    Vendor: %s", getVendorString());
            _log.infof("    GLSL version: %s", getGLSLVersionString());

            // parse extensions
            _extensions = std.array.split(getExtensionsString());

            _log.infof("    Extensions: %s found", _extensions.length);
            _log.infof("    - EXT_texture_filter_anisotropic is%s supported", EXT_texture_filter_anisotropic() ? "": " not");
            _log.infof("    - EXT_framebuffer_object is%s supported", EXT_framebuffer_object() ? "": " not");
            getLimits(true);
            _textureUnits = new TextureUnits(this);
        }

        void close()
        {
            DerelictGL.unload();
            DerelictGL3.unload();
        }

        // for debug purpose, disabled on release build
        void debugCheck()
        {
            debug
            {
                GLint r = glGetError();
                if (r != GL_NO_ERROR)
                {
                    flushGLErrors(); // flush other errors if any
                    _log.errorf("OpenGL error: %s", getErrorString(r));
                    assert(false); // break here
                }
            }
        }

        /// throw OpenGLException in case of OpenGL error
        void runtimeCheck()
        {
            GLint r = glGetError();
            if (r != GL_NO_ERROR)
            {
                string errorString = getErrorString(r);
                flushGLErrors(); // flush other errors if any
                throw new OpenGLException(errorString);
            }
        }

        /// return false in case of OpenGL error
        bool runtimeCheckNothrow() nothrow
        {
            GLint r = glGetError();
            if (r != GL_NO_ERROR)
            {
                flushGLErrors(); // flush other errors if any
                return false;
            }
            return true;
        }

        string getString(GLenum name)
        {
            const(char)* sZ = glGetString(name);
            if (sZ is null)
                return "(unknown)";
            else
                return sanitizeUTF8(sZ, _log, "OpenGL");
        }

        string getVersionString()
        {
            return getString(GL_VERSION);
        }

        string getVendorString()
        {
            return getString(GL_VENDOR);
        }

        string getRendererString()
        {
            return getString(GL_RENDERER);
        }

        string getGLSLVersionString()
        {
            return getString(GL_SHADING_LANGUAGE_VERSION);
        }

        string getExtensionsString()
        {
            return getString(GL_EXTENSIONS);
        }

        bool getInteger(GLenum pname, out int result) nothrow
        {
            GLint param;
            glGetIntegerv(pname, &param);

            if (runtimeCheckNothrow())
            {
                result = param;
                return true;
            }
            else
                return false;
        }

        int getInteger(GLenum pname, GLint defaultValue, bool logging)
        {
            int result;

            if (getInteger(pname, result))
            {
                return result;
            }
            else
            {
                if (logging)
                    _log.warn("couldn't get OpenGL integer");
                return defaultValue;
            }
        }

        float getFloat(GLenum pname)
        {
            GLfloat res;
            glGetFloatv(pname, &res);
            runtimeCheck();
            return res;
        }

        float getFloat(GLenum pname, GLfloat defaultValue, bool logging)
        {
            try
            {
                return getFloat(pname);
            }
            catch(OpenGLException e)
            {
                if (logging)
                    _log.warn(e.msg);
                return defaultValue;
            }
        }
    }

    package
    {
        Log _log;

        static string getErrorString(GLint r) pure nothrow
        {
            switch(r)
            {
                case GL_NO_ERROR:          return "GL_NO_ERROR";
                case GL_INVALID_ENUM:      return "GL_INVALID_ENUM";
                case GL_INVALID_VALUE:     return "GL_INVALID_VALUE";
                case GL_INVALID_OPERATION: return "GL_INVALID_OPERATION";
                case GL_OUT_OF_MEMORY:     return "GL_OUT_OF_MEMORY";
                case GL_TABLE_TOO_LARGE:   return "GL_TABLE_TOO_LARGE";
                case GL_STACK_OVERFLOW:    return "GL_STACK_OVERFLOW";
                case GL_STACK_UNDERFLOW:   return "GL_STACK_UNDERFLOW";
                default:                   return "Unknown OpenGL error";
            }
        }

    }

    public
    {
        int maxTextureSize() pure const nothrow
        {
            return _maxTextureSize;
        }

        int maxTextureUnits() pure const nothrow
        {
            return _maxTextureUnits;
        }

        int maxFragmentTextureImageUnits() pure const nothrow
        {
            return _maxFragmentTextureImageUnits;
        }

        int maxVertexImageUnits() pure const nothrow
        {
            return _maxVertexTextureImageUnits;
        }

        int maxCombinedImageUnits() pure const nothrow
        {
            return _maxCombinedTextureImageUnits;
        }

        int maxColorAttachments() pure const nothrow
        {
            return _maxColorAttachments;
        }

        TextureUnits textureUnits() pure nothrow
        {
            return _textureUnits;
        }

        float maxTextureMaxAnisotropy() pure const nothrow
        {
            return _maxTextureMaxAnisotropy;
        }
    }

    private
    {
        string[] _extensions;
        TextureUnits _textureUnits;
        int _majorVersion;
        int _minorVersion;
        int _maxTextureSize;
        int _maxTextureUnits; // number of conventional units, deprecated
        int _maxFragmentTextureImageUnits; // max for fragment shader
        int _maxVertexTextureImageUnits; // max for vertex shader
        int _maxCombinedTextureImageUnits; // max total
        int _maxColorAttachments;
        float _maxTextureMaxAnisotropy;

        void getLimits(bool logging)
        {
            _majorVersion = getInteger(GL_MAJOR_VERSION, 1, logging);
            _minorVersion = getInteger(GL_MINOR_VERSION, 1, logging);
            _maxTextureSize = getInteger(GL_MAX_TEXTURE_SIZE, 512, logging);
            // For other textures, add calls to:
            // GL_MAX_ARRAY_TEXTURE_LAYERS​, GL_MAX_3D_TEXTURE_SIZE​
            _maxTextureUnits = getInteger(GL_MAX_TEXTURE_UNITS, 2, logging);

            _maxFragmentTextureImageUnits = getInteger(GL_MAX_TEXTURE_IMAGE_UNITS, 2, logging); // odd GL enum name because of legacy reasons (initially only fragment shader could access textures)
            _maxVertexTextureImageUnits = getInteger(GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS, 2, logging);
            _maxCombinedTextureImageUnits = getInteger(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, 2, logging);
            // Get texture unit max for other shader stages with:
            // GL_MAX_GEOMETRY_TEXTURE_IMAGE_UNITS, GL_MAX_TESS_CONTROL_TEXTURE_IMAGE_UNITS, GL_MAX_TESS_EVALUATION_TEXTURE_IMAGE_UNITS

            _maxColorAttachments = getInteger(GL_MAX_COLOR_ATTACHMENTS, 4, logging);

            if (EXT_texture_filter_anisotropic())
                _maxTextureMaxAnisotropy = getFloat(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, 1.0f, logging);
            else
                _maxTextureMaxAnisotropy = 1.0f;
        }

        /// flush out OpenGL errors
        void flushGLErrors() nothrow
        {            
            int timeout = 0;
            while (++timeout <= 5) // avoid infinite loop in a no-driver situation
            {
                GLint r = glGetError();
                if (r == GL_NO_ERROR)
                    break;
            }
        }

    }
}

