module gfm.opengl.program;

import std.conv, 
       std.string, 
       std.regex, 
       std.algorithm;

import derelict.opengl3.gl3;

import gfm.common.log,
       gfm.common.text,
       gfm.math.vector, 
       gfm.math.matrix,
       gfm.opengl.opengl, 
       gfm.opengl.shader, 
       gfm.opengl.uniform;

final class GLProgram
{
    public
    {
        /**
         * Create an empty program.
         */
        this(OpenGL gl)
        {
            _gl = gl;
            _program = glCreateProgram();
            if (_program == 0)
                throw new OpenGLException("glCreateProgram failed");
            _initialized = true;
        }

        /**
         * Create a program from a set of compiled shaders.
         */
        this(OpenGL gl, GLShader[] shaders...)
        {
            this(gl);
            attach(shaders);
            link();
        }

        /**
         * Compiles N times the same GLSL source and link to a program.
         * The same input is compiled 1 to 5 times, each time prepended
         * with #defines specific to a shader type.
         * 
         * - VERTEX_SHADER
         * - FRAGMENT_SHADER
         * - GEOMETRY_SHADER
         * - TESS_CONTROL_SHADER
         * - TESS_EVALUATION_SHADER
         *
         * Each of these defines is alternatively set to 1 while the others are
         * set to zero.
         *            
         * If such a macro isn't used in any preprocessor directives of your source,
         * the shader is considered unused.
         *
         * For conformance reasons, any #version on the first line will stay at the top.
         * 
         * THIS FUNCTION REWRITES YOUR SHADER A BIT.
         * Expect slightly wrong lines in GLSL compiler's error messages.
         *
         * Example of such a source:
         * 
         *      #version 110
         *      uniform vec4 color;
         *
         *      #if VERTEX_SHADER
         *
         *      void main()
         *      {
         *          gl_Vertex = ftransform();
         *      }
         *      
         *      #elif FRAGMENT_SHADER
         *      
         *      void main()
         *      {
         *          gl_FragColor = color;
         *      }
         *      
         *      #endif
         *
         * LIMITATIONS: all your #preprocessor directives should not have whitespaces 
         *              before the #
         *              source elements should be individual lines!
         */
        this(OpenGL gl, string[] source)
        {
            bool present[5];
            enum string[5] defines = 
            [ 
              "VERTEX_SHADER",
              "FRAGMENT_SHADER",
              "GEOMETRY_SHADER",
              "TESS_CONTROL_SHADER",
              "TESS_EVALUATION_SHADER"
            ];

            enum GLenum[5] shaderTypes =
            [ 
                GL_VERTEX_SHADER,
                GL_FRAGMENT_SHADER,
                GL_GEOMETRY_SHADER,
                GL_TESS_CONTROL_SHADER,
                GL_TESS_EVALUATION_SHADER
            ];

            // from GLSL spec: "Each number sign (#) can be preceded in its line only by 
            //                  spaces or horizontal tabs."
            enum directiveRegexp = ctRegex!(r"^[ \t]*#");
            enum versionRegexp = ctRegex!(r"^[ \t]*#[ \t]*version");

            present[] = false;
            int versionLine = -1;

            // scan source for #version and usage of shader macros in preprocessor lines
            foreach(int lineIndex, string line; source)
            {
                // if the line is a preprocessor directive
                if (match(line, directiveRegexp))
                {
                    foreach (int i, string define; defines)
                        if (!present[i] && countUntil(line, define) != -1)
                            present[i] = true;
                   
                    if (match(line, versionRegexp))
                    {
                        if (versionLine != -1)
                        {
                            string message = "Your shader program has several #version directives, you are looking for problems.";
                            debug
                                throw new OpenGLException(message);
                            else
                                gl._log.warn(message);
                        }
                        else
                        {
                            if (lineIndex != 0)
                                gl._log.warn("For maximum compatibility, #version directive should be the first line of your shader.");

                            versionLine = lineIndex;
                        }
                    }
                }
            }

            GLShader[] shaders;

            foreach (int i, string define; defines)
            {
                if (present[i])
                {
                    string[] newSource;

                    // add #version line
                    if (versionLine != -1)
                        newSource ~= source[versionLine];

                    // add each #define with the right value
                    foreach (int j, string define2; defines)
                        if (present[j])
                            newSource ~= format("#define %s %d\n", define2, i == j ? 1 : 0);

                    // add all lines except the #version one
                    foreach (int l, string line; source)
                        if (l != versionLine)
                            newSource ~= line;

                    shaders ~= new GLShader(_gl, shaderTypes[i]);
                }
            }
            this(gl, shaders);
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
                    string name = sanitizeUTF8(buffer.ptr);
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
            return sanitizeUTF8(log.ptr);
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


