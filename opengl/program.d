module gfm.opengl.program;

import std.conv;

import derelict.opengl3.gl3;

import gfm.common.log;
import gfm.opengl.opengl;
import gfm.opengl.exception;
import gfm.opengl.shader;

final class GLProgram
{
    public
    {
        this(OpenGL gl)
        {
            _gl = gl;
            _program = glCreateProgram();
            if (_program == 0)
                throw new OpenGLException("glCreateProgram failed");
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
                glDeleteProgram(_program);
                _initialized = false;
            }
        }

        void attach(GLShader shader)
        {
            glAttachShader(_program, shader._shader);
            _gl.runtimeCheck();
        }

        void link()
        {
            glLinkProgram(_program);
            _gl.runtimeCheck();
        }    

        void use()
        {
            glUseProgram(_program);
            _gl.runtimeCheck();
        }

        void unuse()
        {
            glUseProgram(0);
        }

        string getLinkLog()
        {
            GLint logLength;
            glGetProgramiv(_program, GL_INFO_LOG_LENGTH, &logLength);
            char[] log = new char[logLength + 1];
            GLint dummy;
            glGetProgramInfoLog(_program, logLength, &dummy, log.ptr);
            _gl.debugCheck();
            return to!string(log.ptr);
        }
    }

    package
    {
        GLuint _program;
    }

    private
    {
        OpenGL _gl;
        bool _initialized;
    }
}
