module gfm.opengl.opengl;

import std.string;
import derelict.opengl3.gl3;
import gfm.common.log;
import gfm.opengl.exception;


// wrapper class to ensure library loading
class OpenGL
{
    public
    {
        this(Log log)
        {
            _log = log;
            DerelictGL3.load(); // load latest available version

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
        }

        void close()
        {
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
                _log.errorf("OpenGL error: %s", errorString);
                throw new OpenGLException(errorString);
            }
        }
    }

    package
    {
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
        Log _log;
    }
}
