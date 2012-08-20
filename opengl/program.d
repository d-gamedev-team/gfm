module gfm.opengl.program;

import std.conv, std.string;

import derelict.opengl3.gl3;

import gfm.common.log;
import gfm.math.vector, gfm.math.matrix;
import gfm.opengl.opengl, gfm.opengl.shader, gfm.opengl.uniform;

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

        // one step attach/link
        this(OpenGL gl, GLShader[] shaders...)
        {
            this(gl);
            attach(shaders);
            link();
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

        void attach(GLShader[] shaders...)
        {
            foreach(shader; shaders)
            {
                glAttachShader(_program, shader._shader);
                _gl.runtimeCheck();
            }
        }

        void link()
        {
            glLinkProgram(_program);
            _gl.runtimeCheck();
            GLint res;
            glGetProgramiv(_program, GL_LINK_STATUS, &res);
            if (GL_TRUE != res)
                throw new OpenGLException("Cannot link program");

            // get active uniforms
            {
                GLint uniformNameMaxLength;
                glGetProgramiv(_program, GL_ACTIVE_UNIFORM_MAX_LENGTH, &uniformNameMaxLength);

                GLchar[] buffer = new GLchar[GL_ACTIVE_UNIFORM_MAX_LENGTH + 16];

                GLint numActiveUniforms;
                glGetProgramiv(_program, GL_ACTIVE_UNIFORMS, &numActiveUniforms);

                for (GLint i = 0; i < numActiveUniforms; ++i)
                {
                    GLint size;
                    GLenum type;
                    GLsizei length;
                    glGetActiveUniform(_program,
                                       cast(GLuint)i,
                                       cast(GLint)(buffer.length),
                                       &length,
                                       &size,
                                       &type,
                                       buffer.ptr);
                    _gl.runtimeCheck();
                    string name = to!string(buffer.ptr);
                   _activeUniforms[name] = new GLUniform(_gl, _program, type, name, size);
                }
            }
        }

        void use()
        {
            glUseProgram(_program);
            _gl.runtimeCheck();

            // upload uniform values then
            // this allow setting uniform at anytime without binding the program
            foreach(uniform; _activeUniforms)
                uniform.use();
        }

        void unuse()
        {
            foreach(uniform; _activeUniforms)
                uniform.unuse();
            glUseProgram(0);
        }

        string getLinkLog()
        {
            GLint logLength;
            glGetProgramiv(_program, GL_INFO_LOG_LENGTH, &logLength);
            char[] log = new char[logLength + 1];
            GLint dummy;
            glGetProgramInfoLog(_program, logLength, &dummy, log.ptr);
            _gl.runtimeCheck();
            return to!string(log.ptr);
        }

        GLUniform uniform(string name)
        {
            GLUniform* u = name in _activeUniforms;

            if (u is null)
            {
                // no such variable found, either it's really missing or the OpenGL driver discarded an unused uniform
                // create a fake disabled GLUniform to allow the show to proceed
                _gl._log.warnf("Faking uniform variable '%s'", name);
                _activeUniforms[name] = new GLUniform(_gl, name);
                return _activeUniforms[name];
            }
            return *u;
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
        GLUniform[string] _activeUniforms;
    }
}


