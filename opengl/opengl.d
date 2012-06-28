module gfm.opengl.opengl;

import std.string;
import std.conv;
import std.array;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;
import gfm.common.log;
import gfm.opengl.exception;


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

        // for errors that could happen and are not logic errors
        void runtimeCheck()
        {
            GLint r = glGetError();
            if (r != GL_NO_ERROR)
            {
                string errorString = getErrorString(r);

                // flush out and logs others errors
                do
                {
                    _log.errorf("OpenGL error: %s", errorString);
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
                return to!string(sZ);
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
                default:                   return "Unknown OpenGL error";
            }
        }
    }

    private
    {
        string[] _extensions;
    }
}

