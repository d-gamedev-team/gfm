module gfm.opengl.opengl;

import std.string;
import std.conv;
import std.array;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;
import gfm.common.log;
import gfm.common.text;
import gfm.opengl.textureunit;

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
            _log = log;
            DerelictGL3.load(); // load latest available version

            DerelictGL.load(); // load deprecated functions too

            _log.infof("OpenGL loaded, version %s", DerelictGL3.loadedVersion());
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
                    _log.errorf("OpenGL error: %s", getErrorString(r));
                    assert(false); // break here
                }
            }
        }

        // throw OpenGLException in case of error
        void runtimeCheck(bool warning = false)
        {
            GLint r = glGetError();
            if (r != GL_NO_ERROR)
            {
                string errorString = getErrorString(r);

                // flush out and logs others errors
                int timeout = 0;
                do
                {
                    // avoid infinite loop in a no-driver situation
                    if (++timeout > 5)
                        break;

                    r = glGetError();
                }
                while(r != GL_NO_ERROR);

                throw new OpenGLException(errorString);
            }
        }

        string getString(GLenum name)
        {
            const(char)* sZ = glGetString(name);
            if (sZ is null)
                return "(unknown)";
            else
                return sanitizeUTF8(sZ);
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

        int getInteger(GLenum pname)
        {
            GLint res;
            glGetIntegerv(pname, &res);
            runtimeCheck();
            return res;
        }

        int getInteger(GLenum pname, GLint defaultValue, bool logging)
        {
            try
            {
                return getInteger(pname);
            }
            catch(OpenGLException e)
            {
                if (logging)
                    _log.warn(e.msg);
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

        int maxTextureUnits() pure const nothrow
        {
            return _maxTextureUnits;
        }

        int maxTextureImageUnits() pure const nothrow
        {
            return _maxTextureImageUnits;
        }

        int maxColorAttachments() pure const nothrow
        {
            return _maxColorAttachments;
        }

        TextureUnits textureUnits() pure nothrow
        {
            return textureUnits();
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
        int _maxTextureImageUnits;
        int _maxColorAttachments;
        float _maxTextureMaxAnisotropy;

        void getLimits(bool logging)
        {
            _majorVersion = getInteger(GL_MAJOR_VERSION, 1, logging);
            _minorVersion = getInteger(GL_MINOR_VERSION, 1, logging);
            _maxTextureSize = getInteger(GL_MAX_TEXTURE_SIZE, 512, logging);
            _maxTextureUnits = getInteger(GL_MAX_TEXTURE_UNITS, 2, logging);
            _maxTextureImageUnits = getInteger(GL_MAX_TEXTURE_IMAGE_UNITS, 2, logging);
            _maxColorAttachments = getInteger(GL_MAX_COLOR_ATTACHMENTS, 4, logging);

            if (EXT_texture_filter_anisotropic())
                _maxTextureMaxAnisotropy = getFloat(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, 1.0f, logging);
            else
                _maxTextureMaxAnisotropy = 1.0f;
        }
    }
}

