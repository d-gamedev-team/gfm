module gfm.opengl.program;

import core.stdc.string;
import std.conv, std.string;

import derelict.opengl3.gl3;

import gfm.common.log, gfm.common.memory;
import gfm.math.smallvector, gfm.math.smallmatrix;
import gfm.opengl.opengl, gfm.opengl.exception, gfm.opengl.shader;

static assert(is(GLint == int));
static assert(is(GLuint == uint));
static assert(is(GLfloat == float));
static assert(is(GLdouble == double));

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
                   _activeUniforms[name] = new GLUniform(_gl._log, _program, type, name, size);
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
                uniform.use(_gl._log);            
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
            _gl.runtimeCheck();
            return to!string(log.ptr);
        }

        // set uniform variable
        string setUniform(T)(string uniformName, T value)
        {

        }

        GLUniform uniform(string name)
        {
            GLUniform* u = name in _activeUniforms;

            if (u is null)
            {
                // no such variable found, either it's a type or the OpenGL driver discarded an unused uniform
                // create a fake disabled GLUniform to allow the show to proceed
                _activeUniforms[name] = new GLUniform(_gl._log, name);
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

// Represent an OpenGL program uniform. Owned by a GLProgram.
// Both uniform locations and values are cached, to minimize OpenGL calls.
final class GLUniform
{
    public
    {
        this(Log log, GLuint program, GLenum type, string name, GLsizei size)
        {
            _type = type;
            _size = size;
            _name = name;
            
            _location = glGetUniformLocation(program, toStringz(name));
            if (_location == -1)
            {
                // probably rare: the driver said explicitely this variable was active, and there it's not.
                throw new OpenGLException(format("can't get uniform %s location", name));
            }

            size_t cacheSize = sizeOfUniformType(type) * size;
            if (cacheSize > 0)
            {
                _value = new ubyte[sizeOfUniformType(type) * size]; // relying on zero initialization here
                _valueChanged = false;

                _firstSet = true;
                _disabled = false;
            }
            else
            {
                log.warnf("uniform %s is unrecognized or has size 0, disabled", _name);
                _disabled = true;
            }
        }

        // create fake disabled uniform variables, designed to cope with variables that are detected useless
        // by the OpenGL driver and do not exist
        this(Log log, string name)
        {
            _disabled = true;
            log.warnf("creating fake uniform '%s' which either does not exist in the shader program, or was discarded by the driver as unused", name);            
        }


        // T should be the exact type needed, checked at runtime
        void set(T)(T[] newValue...)
        {
            if (_disabled)
                return;

            if (!typeIsCompliant!T(_type))
                throw new OpenGLException(format("using type %s for setting uniform '%s' which has type %s", T.stringof, _name, _type.stringof));

            if (newValue.length != _size)
                throw new OpenGLException(format("cannot set uniform '%s' of size %s with a value of size %s", _name, _size, newValue.length));
            
            // if first time or different value incoming
            if (_firstSet || (0 != memcmp(&newValue, _value.ptr, T.sizeof)))
            {
                memcpy(_value.ptr, &newValue, T.sizeof);
                _valueChanged = true;
            }

            _firstSet = false;
        }

        void use(Log log)
        {
            if (_disabled)
                return;

            // safety check to prevent defaults values in uniforms
            if (_firstSet)
            {
                log.warnf("uniform '%s' left to default value, driver will probably zero it", _name);
                _firstSet = false;
            }

            // has value changed? 
            // if so, set OpenGL value
            if (_valueChanged)
            {
                //setUniform(_type, _value, _size);
                _valueChanged = false;
            }
        }
    }

    private
    {
        GLint _location;
        GLenum _type;
        size_t _size;
        ubyte[] _value;
        bool _valueChanged;
        bool _firstSet; // force update to ensure we do not relie on the driver initializing uniform to zero
        bool _disabled; // allow transparent usage while not doing anything
        string _name;

        static bool typeIsCompliant(T)(GLenum type)
        {
            switch (type)
            {
                case GL_FLOAT:      return is(T == float);
                case GL_FLOAT_VEC2: return is(T == vec2f);
                case GL_FLOAT_VEC3: return is(T == vec3f);
                case GL_FLOAT_VEC4: return is(T == vec4f);
                case GL_DOUBLE:      return is(T == double);
                case GL_DOUBLE_VEC2: return is(T == vec2d);
                case GL_DOUBLE_VEC3: return is(T == vec3d);
                case GL_DOUBLE_VEC4: return is(T == vec4d);
                case GL_INT:      return is(T == int);
                case GL_INT_VEC2: return is(T == vec2i);
                case GL_INT_VEC3: return is(T == vec3i);
                case GL_INT_VEC4: return is(T == vec4i);
                case GL_UNSIGNED_INT:      return is(T == uint);
                case GL_UNSIGNED_INT_VEC2: return is(T == vec2ui);
                case GL_UNSIGNED_INT_VEC3: return is(T == vec3ui);
                case GL_UNSIGNED_INT_VEC4: return is(T == vec4ui);
                case GL_BOOL:      return is(T == int); // int because bool type is 1 byte
                case GL_BOOL_VEC2: return is(T == vec2i);
                case GL_BOOL_VEC3: return is(T == vec3i);
                case GL_BOOL_VEC4: return is(T == vec4i);
                case GL_FLOAT_MAT2: return is(T == mat2f);
                case GL_FLOAT_MAT3: return is(T == mat3f);
                case GL_FLOAT_MAT4: return is(T == mat4f);
                case GL_FLOAT_MAT2x3: return is(T == mat2x3f);
                case GL_FLOAT_MAT2x4: return is(T == mat2x4f);
                case GL_FLOAT_MAT3x2: return is(T == mat3x2f);
                case GL_FLOAT_MAT3x4: return is(T == mat3x4f);
                case GL_FLOAT_MAT4x2: return is(T == mat4x2f);
                case GL_FLOAT_MAT4x3: return is(T == mat4x3f);
                case GL_DOUBLE_MAT2: return is(T == mat2d);
                case GL_DOUBLE_MAT3: return is(T == mat3d);
                case GL_DOUBLE_MAT4: return is(T == mat4d);
                case GL_DOUBLE_MAT2x3: return is(T == mat2x3d);
                case GL_DOUBLE_MAT2x4: return is(T == mat2x4d);
                case GL_DOUBLE_MAT3x2: return is(T == mat3x2d);
                case GL_DOUBLE_MAT3x4: return is(T == mat3x4d);
                case GL_DOUBLE_MAT4x2: return is(T == mat4x2d);
                case GL_DOUBLE_MAT4x3: return is(T == mat4x3d);

                // image samplers
                case GL_IMAGE_1D: .. case GL_UNSIGNED_INT_IMAGE_2D_MULTISAMPLE_ARRAY:
                    return is(T == int);

                case GL_UNSIGNED_INT_ATOMIC_COUNTER: 
                    return is(T == uint);

                case GL_SAMPLER_1D:
                case GL_SAMPLER_2D:
                case GL_SAMPLER_3D:
                case GL_SAMPLER_CUBE:
                case GL_SAMPLER_1D_SHADOW:
                case GL_SAMPLER_2D_SHADOW:
                case GL_SAMPLER_1D_ARRAY:
                case GL_SAMPLER_2D_ARRAY:
                case GL_SAMPLER_1D_ARRAY_SHADOW:
                case GL_SAMPLER_2D_ARRAY_SHADOW:
                case GL_SAMPLER_2D_MULTISAMPLE:
                case GL_SAMPLER_2D_MULTISAMPLE_ARRAY:
                case GL_SAMPLER_CUBE_SHADOW:
                case GL_SAMPLER_BUFFER:
                case GL_SAMPLER_2D_RECT:
                case GL_SAMPLER_2D_RECT_SHADOW:        
                case GL_INT_SAMPLER_1D:
                case GL_INT_SAMPLER_2D:
                case GL_INT_SAMPLER_3D:
                case GL_INT_SAMPLER_CUBE:
                case GL_INT_SAMPLER_1D_ARRAY:
                case GL_INT_SAMPLER_2D_ARRAY:
                case GL_INT_SAMPLER_2D_MULTISAMPLE:
                case GL_INT_SAMPLER_2D_MULTISAMPLE_ARRAY:
                case GL_INT_SAMPLER_BUFFER:
                case GL_INT_SAMPLER_2D_RECT:
                case GL_UNSIGNED_INT_SAMPLER_1D:
                case GL_UNSIGNED_INT_SAMPLER_2D:
                case GL_UNSIGNED_INT_SAMPLER_3D:
                case GL_UNSIGNED_INT_SAMPLER_CUBE:
                case GL_UNSIGNED_INT_SAMPLER_1D_ARRAY:
                case GL_UNSIGNED_INT_SAMPLER_2D_ARRAY:
                case GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE:
                case GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY:
                case GL_UNSIGNED_INT_SAMPLER_BUFFER:
                case GL_UNSIGNED_INT_SAMPLER_2D_RECT:
                    return is(T == int);

                default:
                    // unrecognized type, in release mode return true
                    debug
                    {
                        assert(false);
                    }
                    else
                    {                        
                        return true;
                    }
            }
        }

        static size_t sizeOfUniformType(GLenum type)
        {
            switch (type)
            {
                case GL_FLOAT:      return float.sizeof;
                case GL_FLOAT_VEC2: return vec2f.sizeof;
                case GL_FLOAT_VEC3: return vec3f.sizeof;
                case GL_FLOAT_VEC4: return vec4f.sizeof;
                case GL_DOUBLE:      return double.sizeof;
                case GL_DOUBLE_VEC2: return vec2d.sizeof;
                case GL_DOUBLE_VEC3: return vec3d.sizeof;
                case GL_DOUBLE_VEC4: return vec4d.sizeof;
                case GL_INT:      return int.sizeof;
                case GL_INT_VEC2: return vec2i.sizeof;
                case GL_INT_VEC3: return vec3i.sizeof;
                case GL_INT_VEC4: return vec4i.sizeof;
                case GL_UNSIGNED_INT:      return uint.sizeof;
                case GL_UNSIGNED_INT_VEC2: return vec2ui.sizeof;
                case GL_UNSIGNED_INT_VEC3: return vec3ui.sizeof;
                case GL_UNSIGNED_INT_VEC4: return vec4ui.sizeof;
                case GL_BOOL:      return int.sizeof; // int because D bool type is 1 byte
                case GL_BOOL_VEC2: return vec2i.sizeof;
                case GL_BOOL_VEC3: return vec3i.sizeof;
                case GL_BOOL_VEC4: return vec4i.sizeof;
                case GL_FLOAT_MAT2: return mat2f.sizeof;
                case GL_FLOAT_MAT3: return mat3f.sizeof;
                case GL_FLOAT_MAT4: return mat4f.sizeof;
                case GL_FLOAT_MAT2x3: return mat2x3f.sizeof;
                case GL_FLOAT_MAT2x4: return mat2x4f.sizeof;
                case GL_FLOAT_MAT3x2: return mat3x2f.sizeof;
                case GL_FLOAT_MAT3x4: return mat3x4f.sizeof;
                case GL_FLOAT_MAT4x2: return mat4x2f.sizeof;
                case GL_FLOAT_MAT4x3: return mat4x3f.sizeof;
                case GL_DOUBLE_MAT2: return mat2d.sizeof;
                case GL_DOUBLE_MAT3: return mat3d.sizeof;
                case GL_DOUBLE_MAT4: return mat4d.sizeof;
                case GL_DOUBLE_MAT2x3: return mat2x3d.sizeof;
                case GL_DOUBLE_MAT2x4: return mat2x4d.sizeof;
                case GL_DOUBLE_MAT3x2: return mat3x2d.sizeof;
                case GL_DOUBLE_MAT3x4: return mat3x4d.sizeof;
                case GL_DOUBLE_MAT4x2: return mat4x2d.sizeof;
                case GL_DOUBLE_MAT4x3: return mat4x3d.sizeof;

                    // image samplers
                case GL_IMAGE_1D: .. case GL_UNSIGNED_INT_IMAGE_2D_MULTISAMPLE_ARRAY:
                    return is(T == int);

                case GL_UNSIGNED_INT_ATOMIC_COUNTER: 
                    return is(T == uint);

                case GL_SAMPLER_1D:
                case GL_SAMPLER_2D:
                case GL_SAMPLER_3D:
                case GL_SAMPLER_CUBE:
                case GL_SAMPLER_1D_SHADOW:
                case GL_SAMPLER_2D_SHADOW:
                case GL_SAMPLER_1D_ARRAY:
                case GL_SAMPLER_2D_ARRAY:
                case GL_SAMPLER_1D_ARRAY_SHADOW:
                case GL_SAMPLER_2D_ARRAY_SHADOW:
                case GL_SAMPLER_2D_MULTISAMPLE:
                case GL_SAMPLER_2D_MULTISAMPLE_ARRAY:
                case GL_SAMPLER_CUBE_SHADOW:
                case GL_SAMPLER_BUFFER:
                case GL_SAMPLER_2D_RECT:
                case GL_SAMPLER_2D_RECT_SHADOW:        
                case GL_INT_SAMPLER_1D:
                case GL_INT_SAMPLER_2D:
                case GL_INT_SAMPLER_3D:
                case GL_INT_SAMPLER_CUBE:
                case GL_INT_SAMPLER_1D_ARRAY:
                case GL_INT_SAMPLER_2D_ARRAY:
                case GL_INT_SAMPLER_2D_MULTISAMPLE:
                case GL_INT_SAMPLER_2D_MULTISAMPLE_ARRAY:
                case GL_INT_SAMPLER_BUFFER:
                case GL_INT_SAMPLER_2D_RECT:
                case GL_UNSIGNED_INT_SAMPLER_1D:
                case GL_UNSIGNED_INT_SAMPLER_2D:
                case GL_UNSIGNED_INT_SAMPLER_3D:
                case GL_UNSIGNED_INT_SAMPLER_CUBE:
                case GL_UNSIGNED_INT_SAMPLER_1D_ARRAY:
                case GL_UNSIGNED_INT_SAMPLER_2D_ARRAY:
                case GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE:
                case GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY:
                case GL_UNSIGNED_INT_SAMPLER_BUFFER:
                case GL_UNSIGNED_INT_SAMPLER_2D_RECT:                
                    return int.sizeof;

                default:
                    // unrecognized type
                    // in debug mode assert, in release mode return 0 to disable this uniform
                    debug
                    {
                        assert(false);
                    }
                    else
                    {                        
                        return 0;
                    }
            }
        }
    }
}

