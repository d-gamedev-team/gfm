module gfm.opengl.shader;

import std.string;
import std.conv;

import derelict.opengl3.gl3;

import gfm.common.log;
import gfm.common.text;
import gfm.opengl.opengl;


final class GLShader
{
    public
    {
        this(OpenGL gl, GLenum shaderType)
        {
            _gl = gl;
            _shader = glCreateShader(shaderType);
            if (_shader == 0)
                throw new OpenGLException("glCreateShader failed");
            _initialized = true;
        }

        // one step load/compile
        this(OpenGL gl, GLenum shaderType, string[] lines...)
        {
            this(gl, shaderType);
            load(lines);
            compile();
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_initialized)
            {
                glDeleteShader(_shader);
                _initialized = false;
            }
        }

        void load(string[] lines...)
        {
            size_t lineCount = lines.length;

            auto lengths = new GLint[lineCount];
            auto addresses = new immutable(GLchar)*[lineCount];
            auto localLines = new string[lineCount];

            for (size_t i = 0; i < lineCount; ++i)
            {
                localLines[i] = lines[i];
                if (localLines[i] is null)
                    localLines[i] = "";

                lengths[i] = localLines[i].length;
                addresses[i] = localLines[i].ptr;
            }

            glShaderSource(_shader,
                           cast(GLint)lineCount,
                           cast(const(char)**)addresses.ptr,
                           cast(const(int)*)(lengths.ptr));
            _gl.runtimeCheck();
        }

        void compile()
        {
            glCompileShader(_shader);
            _gl.runtimeCheck();

            // print info log
            _gl._log.info(getInfoLog());

            GLint compiled;
            glGetShaderiv(_shader, GL_COMPILE_STATUS, &compiled);

            if (compiled != GL_TRUE)
                throw new OpenGLException("shader did not compile");


        }

        string getInfoLog()
        {
            GLint logLength;
            glGetShaderiv(_shader, GL_INFO_LOG_LENGTH, &logLength);
            char[] log = new char[logLength + 1];
            GLint dummy;
            glGetShaderInfoLog(_shader, logLength, &dummy, log.ptr);
            _gl.runtimeCheck();
            return sanitizeUTF8(log.ptr);
        }
    }

    package
    {
        GLuint _shader;
    }

    private
    {
        OpenGL _gl;
        bool _initialized;
    }
}


