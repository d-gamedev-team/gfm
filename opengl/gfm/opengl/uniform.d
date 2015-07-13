module gfm.opengl.uniform;

import std.conv, 
       std.string,
       core.stdc.string;

import derelict.opengl3.gl3;

import gfm.math.vector, 
       gfm.math.matrix,
       gfm.opengl.opengl;


/// Represents an OpenGL program uniform. Owned by a GLProgram.
/// Both uniform locations and values are cached, to minimize OpenGL calls.
final class GLUniform
{
    public
    {
        /// Creates a GLUniform.
        /// This is done automatically after linking a GLProgram.
        /// See_also: GLProgram.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl, GLuint program, GLenum type, string name, GLsizei size)
        {
            _gl = gl;
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
                _value = new ubyte[cacheSize]; // relying on zero initialization here
                _valueChanged = false;

                _firstSet = true;
                _disabled = false;
            }
            else
            {
                _gl._logger.warningf("uniform %s is unrecognized or has size 0, disabled", _name);
                _disabled = true;
            }
        }

        /// Creates a fake disabled uniform variable, designed to cope with variables 
        /// that have been optimized out by the OpenGL driver, or those which do not exist.
        this(OpenGL gl, string name)
        {
            _gl = gl;
            _disabled = true;
            _gl._logger.warningf("Faking uniform '%s' which either does not exist in the shader program, or was discarded by the driver as unused", name);
        }

        /// Sets a uniform variable value.
        /// T should be the exact type needed, checked at runtime.
        /// Throws: $(D OpenGLException) on error.
        void set(T)(T newValue)
        {
            set!T(&newValue, 1u);
        }

        /// Sets multiple uniform variables.
        /// Throws: $(D OpenGLException) on error.
        void set(T)(T[] newValues)
        {
            set!T(newValues.ptr, newValues.length);
        }

        /// Sets multiple uniform variables.
        /// Throws: $(D OpenGLException) on error.
        void set(T)(T* newValues, size_t count)
        {
            if (_disabled)
                return;

            // special case so that GL_BOOL variable can be assigned when T is bool
            static if (is(T == bool))
            {
                assert(_type == GL_BOOL); // else we would have thrown
                assert(count == 1);  // else we would have thrown
                set!int( cast(int)(*newValues) );
                return;
            }
            else
            {
                if (!typeIsCompliant!T(_type))
                    throw new OpenGLException(format("using type %s for setting uniform '%s' which has GLSL type '%s'", 
                                                     T.stringof, _name, GLSLTypeNameArray(_type, _size)));

                if (count != _size)
                    throw new OpenGLException(format("cannot set uniform '%s' of size %s with a value of size %s", 
                                                     _name, _size, count));

                // if first time or different value incoming
                if (_firstSet || (0 != memcmp(newValues, _value.ptr, _value.length)))
                {
                    memcpy(_value.ptr, newValues, _value.length);
                    _valueChanged = true;

                    if (_shouldUpdateImmediately)
                        update();
                }

                _firstSet = false;
            }
        }
    
        /// Updates the uniform value.
        void use()
        {
            _shouldUpdateImmediately = true;
            update();
        }       

        /// Unuses this uniform.
        void unuse()
        {
            _shouldUpdateImmediately = false;
        }

        /// Returns: Uniform name.
        string name()
        {
            return _name;
        }
    }

    private
    {
        OpenGL _gl;
        GLint _location;
        GLenum _type;
        GLsizei _size;
        ubyte[] _value;
        bool _valueChanged;
        bool _firstSet; // force update to ensure we do not relie on the driver initializing uniform to zero
        bool _disabled; // allow transparent usage while not doing anything
        bool _shouldUpdateImmediately;
        string _name;

        void update()
        {
            if (_disabled)
                return;

            // safety check to prevent defaults values in uniforms
            if (_firstSet)
            {
                _gl._logger.warningf("uniform '%s' left to default value, driver will probably zero it", _name);
                _firstSet = false;
            }

            // has value changed?
            // if so, set OpenGL value
            if (_valueChanged)
            {
                setUniform();
                _valueChanged = false;
            }
        }

        void setUniform()
        {
            switch(_type)
            {
                case GL_FLOAT:      glUniform1fv(_location, _size, cast(GLfloat*)_value); break;
                case GL_FLOAT_VEC2: glUniform2fv(_location, _size, cast(GLfloat*)_value); break;
                case GL_FLOAT_VEC3: glUniform3fv(_location, _size, cast(GLfloat*)_value); break;
                case GL_FLOAT_VEC4: glUniform4fv(_location, _size, cast(GLfloat*)_value); break;
                case GL_DOUBLE:      glUniform1dv(_location, _size, cast(GLdouble*)_value); break;
                case GL_DOUBLE_VEC2: glUniform2dv(_location, _size, cast(GLdouble*)_value); break;
                case GL_DOUBLE_VEC3: glUniform3dv(_location, _size, cast(GLdouble*)_value); break;
                case GL_DOUBLE_VEC4: glUniform4dv(_location, _size, cast(GLdouble*)_value); break;
                case GL_INT:      glUniform1iv(_location, _size, cast(GLint*)_value); break;
                case GL_INT_VEC2: glUniform2iv(_location, _size, cast(GLint*)_value); break;
                case GL_INT_VEC3: glUniform3iv(_location, _size, cast(GLint*)_value); break;
                case GL_INT_VEC4: glUniform4iv(_location, _size, cast(GLint*)_value); break;
                case GL_UNSIGNED_INT:      glUniform1uiv(_location, _size, cast(GLuint*)_value); break;
                case GL_UNSIGNED_INT_VEC2: glUniform2uiv(_location, _size, cast(GLuint*)_value); break;
                case GL_UNSIGNED_INT_VEC3: glUniform3uiv(_location, _size, cast(GLuint*)_value); break;
                case GL_UNSIGNED_INT_VEC4: glUniform4uiv(_location, _size, cast(GLuint*)_value); break;
                case GL_BOOL:      glUniform1iv(_location, _size, cast(GLint*)_value); break;
                case GL_BOOL_VEC2: glUniform2iv(_location, _size, cast(GLint*)_value); break;
                case GL_BOOL_VEC3: glUniform3iv(_location, _size, cast(GLint*)_value); break;
                case GL_BOOL_VEC4: glUniform4iv(_location, _size, cast(GLint*)_value); break;
                case GL_FLOAT_MAT2:   glUniformMatrix2fv(_location, _size, GL_TRUE, cast(GLfloat*)_value); break;
                case GL_FLOAT_MAT3:   glUniformMatrix3fv(_location, _size, GL_TRUE, cast(GLfloat*)_value); break;
                case GL_FLOAT_MAT4:   glUniformMatrix4fv(_location, _size, GL_TRUE, cast(GLfloat*)_value); break;
                case GL_FLOAT_MAT2x3: glUniformMatrix2x3fv(_location, _size, GL_TRUE, cast(GLfloat*)_value); break;
                case GL_FLOAT_MAT2x4: glUniformMatrix3x2fv(_location, _size, GL_TRUE, cast(GLfloat*)_value); break;
                case GL_FLOAT_MAT3x2: glUniformMatrix2x4fv(_location, _size, GL_TRUE, cast(GLfloat*)_value); break;
                case GL_FLOAT_MAT3x4: glUniformMatrix4x2fv(_location, _size, GL_TRUE, cast(GLfloat*)_value); break;
                case GL_FLOAT_MAT4x2: glUniformMatrix3x4fv(_location, _size, GL_TRUE, cast(GLfloat*)_value); break;
                case GL_FLOAT_MAT4x3: glUniformMatrix4x3fv(_location, _size, GL_TRUE, cast(GLfloat*)_value); break;
                case GL_DOUBLE_MAT2:   glUniformMatrix2dv(_location, _size, GL_TRUE, cast(GLdouble*)_value); break;
                case GL_DOUBLE_MAT3:   glUniformMatrix3dv(_location, _size, GL_TRUE, cast(GLdouble*)_value); break;
                case GL_DOUBLE_MAT4:   glUniformMatrix4dv(_location, _size, GL_TRUE, cast(GLdouble*)_value); break;
                case GL_DOUBLE_MAT2x3: glUniformMatrix2x3dv(_location, _size, GL_TRUE, cast(GLdouble*)_value); break;
                case GL_DOUBLE_MAT2x4: glUniformMatrix3x2dv(_location, _size, GL_TRUE, cast(GLdouble*)_value); break;
                case GL_DOUBLE_MAT3x2: glUniformMatrix2x4dv(_location, _size, GL_TRUE, cast(GLdouble*)_value); break;
                case GL_DOUBLE_MAT3x4: glUniformMatrix4x2dv(_location, _size, GL_TRUE, cast(GLdouble*)_value); break;
                case GL_DOUBLE_MAT4x2: glUniformMatrix3x4dv(_location, _size, GL_TRUE, cast(GLdouble*)_value); break;
                case GL_DOUBLE_MAT4x3: glUniformMatrix4x3dv(_location, _size, GL_TRUE, cast(GLdouble*)_value); break;

                // image samplers
                case GL_IMAGE_1D: .. case GL_UNSIGNED_INT_IMAGE_2D_MULTISAMPLE_ARRAY:
                    glUniform1iv(_location, _size, cast(GLint*)_value);
                    break;

                case GL_UNSIGNED_INT_ATOMIC_COUNTER:
                    glUniform1uiv(_location, _size, cast(GLuint*)_value);
                    break;

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
                    glUniform1iv(_location, _size, cast(GLint*)_value);
                    break;

                default: 
                    break;
            }
            _gl.runtimeCheck();
        }

        public static bool typeIsCompliant(T)(GLenum type)
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
                case GL_BOOL:      return is(T == int) || is(T == bool); // int because bool type is 1 byte
                case GL_BOOL_VEC2: return is(T == vec2i);
                case GL_BOOL_VEC3: return is(T == vec3i);
                case GL_BOOL_VEC4: return is(T == vec4i);
                case GL_FLOAT_MAT2: return is(T == mat2f);
                case GL_FLOAT_MAT3: return is(T == mat3f);
                case GL_FLOAT_MAT4: return is(T == mat4f);
                case GL_FLOAT_MAT2x3: return is(T == mat3x2f);
                case GL_FLOAT_MAT2x4: return is(T == mat4x2f);
                case GL_FLOAT_MAT3x2: return is(T == mat2x3f);
                case GL_FLOAT_MAT3x4: return is(T == mat4x3f);
                case GL_FLOAT_MAT4x2: return is(T == mat2x4f);
                case GL_FLOAT_MAT4x3: return is(T == mat3x4f);
                case GL_DOUBLE_MAT2: return is(T == mat2d);
                case GL_DOUBLE_MAT3: return is(T == mat3d);
                case GL_DOUBLE_MAT4: return is(T == mat4d);
                case GL_DOUBLE_MAT2x3: return is(T == mat3x2d);
                case GL_DOUBLE_MAT2x4: return is(T == mat4x2d);
                case GL_DOUBLE_MAT3x2: return is(T == mat2x3d);
                case GL_DOUBLE_MAT3x4: return is(T == mat4x3d);
                case GL_DOUBLE_MAT4x2: return is(T == mat2x4d);
                case GL_DOUBLE_MAT4x3: return is(T == mat3x4d);

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

        public static size_t sizeOfUniformType(GLenum type)
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
                case GL_FLOAT_MAT2x3: return mat3x2f.sizeof;
                case GL_FLOAT_MAT2x4: return mat4x2f.sizeof;
                case GL_FLOAT_MAT3x2: return mat2x3f.sizeof;
                case GL_FLOAT_MAT3x4: return mat4x3f.sizeof;
                case GL_FLOAT_MAT4x2: return mat2x4f.sizeof;
                case GL_FLOAT_MAT4x3: return mat3x4f.sizeof;
                case GL_DOUBLE_MAT2: return mat2d.sizeof;
                case GL_DOUBLE_MAT3: return mat3d.sizeof;
                case GL_DOUBLE_MAT4: return mat4d.sizeof;
                case GL_DOUBLE_MAT2x3: return mat3x2d.sizeof;
                case GL_DOUBLE_MAT2x4: return mat4x2d.sizeof;
                case GL_DOUBLE_MAT3x2: return mat2x3d.sizeof;
                case GL_DOUBLE_MAT3x4: return mat4x3d.sizeof;
                case GL_DOUBLE_MAT4x2: return mat2x4d.sizeof;
                case GL_DOUBLE_MAT4x3: return mat3x4d.sizeof;

                    // image samplers
                case GL_IMAGE_1D: .. case GL_UNSIGNED_INT_IMAGE_2D_MULTISAMPLE_ARRAY:
                    return int.sizeof;

                case GL_UNSIGNED_INT_ATOMIC_COUNTER:
                    return uint.sizeof;

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

        static string GLSLTypeName(GLenum type)
        {
            switch (type)
            {
                case GL_FLOAT: return "float";
                case GL_FLOAT_VEC2: return "vec2";
                case GL_FLOAT_VEC3: return "vec3";
                case GL_FLOAT_VEC4: return "vec4";
                case GL_DOUBLE: return "double";
                case GL_DOUBLE_VEC2: return "dvec2";
                case GL_DOUBLE_VEC3: return "dvec3";
                case GL_DOUBLE_VEC4: return "dvec4";
                case GL_INT: return "int";
                case GL_INT_VEC2: return "ivec2";
                case GL_INT_VEC3: return "ivec3";
                case GL_INT_VEC4: return "ivec4";
                case GL_UNSIGNED_INT: return "uint";
                case GL_UNSIGNED_INT_VEC2: return "uvec2";
                case GL_UNSIGNED_INT_VEC3: return "uvec3";
                case GL_UNSIGNED_INT_VEC4: return "uvec4";
                case GL_BOOL: return "bool";
                case GL_BOOL_VEC2: return "bvec2";
                case GL_BOOL_VEC3: return "bvec3";
                case GL_BOOL_VEC4: return "bvec4";
                case GL_FLOAT_MAT2: return "mat2";
                case GL_FLOAT_MAT3: return "mat3";
                case GL_FLOAT_MAT4: return "mat4";
                case GL_FLOAT_MAT2x3: return "mat2x3";
                case GL_FLOAT_MAT2x4: return "mat2x4";
                case GL_FLOAT_MAT3x2: return "mat3x2";
                case GL_FLOAT_MAT3x4: return "mat3x4";
                case GL_FLOAT_MAT4x2: return "mat4x2";
                case GL_FLOAT_MAT4x3: return "mat4x3";
                case GL_DOUBLE_MAT2: return "dmat2";
                case GL_DOUBLE_MAT3: return "dmat3";
                case GL_DOUBLE_MAT4: return "dmat4";
                case GL_DOUBLE_MAT2x3: return "dmat2x3";
                case GL_DOUBLE_MAT2x4: return "dmat2x4";
                case GL_DOUBLE_MAT3x2: return "dmat3x2";
                case GL_DOUBLE_MAT3x4: return "dmat3x4";
                case GL_DOUBLE_MAT4x2: return "dmat4x2";
                case GL_DOUBLE_MAT4x3: return "dmat4x3";
                case GL_SAMPLER_1D: return "sampler1D";
                case GL_SAMPLER_2D: return "sampler2D";
                case GL_SAMPLER_3D: return "sampler3D";
                case GL_SAMPLER_CUBE: return "samplerCube";
                case GL_SAMPLER_1D_SHADOW: return "sampler1DShadow";
                case GL_SAMPLER_2D_SHADOW: return "sampler2DShadow";
                case GL_SAMPLER_1D_ARRAY: return "sampler1DArray";
                case GL_SAMPLER_2D_ARRAY: return "sampler2DArray";
                case GL_SAMPLER_1D_ARRAY_SHADOW: return "sampler1DArrayShadow";
                case GL_SAMPLER_2D_ARRAY_SHADOW: return "sampler2DArrayShadow";
                case GL_SAMPLER_2D_MULTISAMPLE: return "sampler2DMS";
                case GL_SAMPLER_2D_MULTISAMPLE_ARRAY: return "sampler2DMSArray";
                case GL_SAMPLER_CUBE_SHADOW: return "samplerCubeShadow";
                case GL_SAMPLER_BUFFER: return "samplerBuffer";
                case GL_SAMPLER_2D_RECT: return "sampler2DRect";
                case GL_SAMPLER_2D_RECT_SHADOW: return "sampler2DRectShadow";
                case GL_INT_SAMPLER_1D: return "isampler1D";
                case GL_INT_SAMPLER_2D: return "isampler2D";
                case GL_INT_SAMPLER_3D: return "isampler3D";
                case GL_INT_SAMPLER_CUBE: return "isamplerCube";
                case GL_INT_SAMPLER_1D_ARRAY: return "isampler1DArray";
                case GL_INT_SAMPLER_2D_ARRAY: return "isampler2DArray";
                case GL_INT_SAMPLER_2D_MULTISAMPLE: return "isampler2DMS";
                case GL_INT_SAMPLER_2D_MULTISAMPLE_ARRAY: return "isampler2DMSArray";
                case GL_INT_SAMPLER_BUFFER: return "isamplerBuffer";
                case GL_INT_SAMPLER_2D_RECT: return "isampler2DRect";
                case GL_UNSIGNED_INT_SAMPLER_1D: return "usampler1D";
                case GL_UNSIGNED_INT_SAMPLER_2D: return "usampler2D";
                case GL_UNSIGNED_INT_SAMPLER_3D: return "usampler3D";
                case GL_UNSIGNED_INT_SAMPLER_CUBE: return "usamplerCube";
                case GL_UNSIGNED_INT_SAMPLER_1D_ARRAY: return "usampler2DArray";
                case GL_UNSIGNED_INT_SAMPLER_2D_ARRAY: return "usampler2DArray";
                case GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE: return "usampler2DMS";
                case GL_UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY: return "usampler2DMSArray";
                case GL_UNSIGNED_INT_SAMPLER_BUFFER: return "usamplerBuffer";
                case GL_UNSIGNED_INT_SAMPLER_2D_RECT: return "usampler2DRect";
                case GL_IMAGE_1D: return "image1D";
                case GL_IMAGE_2D: return "image2D";
                case GL_IMAGE_3D: return "image3D";
                case GL_IMAGE_2D_RECT: return "image2DRect";
                case GL_IMAGE_CUBE: return "imageCube";
                case GL_IMAGE_BUFFER: return "imageBuffer";
                case GL_IMAGE_1D_ARRAY: return "image1DArray";
                case GL_IMAGE_2D_ARRAY: return "image2DArray";
                case GL_IMAGE_2D_MULTISAMPLE: return "image2DMS";
                case GL_IMAGE_2D_MULTISAMPLE_ARRAY: return "image2DMSArray";
                case GL_INT_IMAGE_1D: return "iimage1D";
                case GL_INT_IMAGE_2D: return "iimage2D";
                case GL_INT_IMAGE_3D: return "iimage3D";
                case GL_INT_IMAGE_2D_RECT: return "iimage2DRect";
                case GL_INT_IMAGE_CUBE: return "iimageCube";
                case GL_INT_IMAGE_BUFFER: return "iimageBuffer";
                case GL_INT_IMAGE_1D_ARRAY: return "iimage1DArray";
                case GL_INT_IMAGE_2D_ARRAY: return "iimage2DArray";
                case GL_INT_IMAGE_2D_MULTISAMPLE: return "iimage2DMS";
                case GL_INT_IMAGE_2D_MULTISAMPLE_ARRAY: return "iimage2DMSArray";
                case GL_UNSIGNED_INT_IMAGE_1D: return "uimage1D";
                case GL_UNSIGNED_INT_IMAGE_2D: return "uimage2D";
                case GL_UNSIGNED_INT_IMAGE_3D: return "uimage3D";
                case GL_UNSIGNED_INT_IMAGE_2D_RECT: return "uimage2DRect";
                case GL_UNSIGNED_INT_IMAGE_CUBE: return "uimageCube";
                case GL_UNSIGNED_INT_IMAGE_BUFFER: return "uimageBuffer";
                case GL_UNSIGNED_INT_IMAGE_1D_ARRAY: return "uimage1DArray";
                case GL_UNSIGNED_INT_IMAGE_2D_ARRAY: return "uimage2DArray";
                case GL_UNSIGNED_INT_IMAGE_2D_MULTISAMPLE: return "uimage2DMS";
                case GL_UNSIGNED_INT_IMAGE_2D_MULTISAMPLE_ARRAY: return "uimage2DMSArray";
                case GL_UNSIGNED_INT_ATOMIC_COUNTER: return "atomic_uint";
                default:
                    return "unknown";
            }
        }

        static string GLSLTypeNameArray(GLenum type, size_t multiplicity)
        {
            assert(multiplicity > 0);
            if (multiplicity == 1)
                return GLSLTypeName(type);
            else
                return format("%s[%s]", GLSLTypeName(type), multiplicity);
        }
    }
}

static assert(is(GLint == int));
static assert(is(GLuint == uint));
static assert(is(GLfloat == float));
static assert(is(GLdouble == double));
