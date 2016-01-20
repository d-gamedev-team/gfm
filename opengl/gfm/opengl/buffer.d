module gfm.opengl.buffer;

import derelict.opengl3.gl3;

import gfm.opengl.opengl;

/// OpenGL Buffer wrapper.
final class GLBuffer
{
    public
    {
        /// Creates an empty buffer.
        /// Throws: $(D OpenGLException) on error.
        this(OpenGL gl, GLuint target, GLuint usage)
        {
            _gl = gl;
            _usage = usage;
            _target = target;
            _firstLoad = true;

            glGenBuffers(1, &_buffer);
            gl.runtimeCheck();
            _initialized = true;
            _size = 0;
        }

        /// Creates a buffer already filled with data.
        /// Throws: $(D OpenGLException) on error.
        this(T)(OpenGL gl, GLuint target, GLuint usage, T[] buffer)
        {
            this(gl, target, usage);
            setData(buffer);
        }

        /// Releases the OpenGL buffer resource.
        ~this()
        {
            if (_initialized)
            {
                debug ensureNotInGC("GLBuffer");
                glDeleteBuffers(1, &_buffer);
                _initialized = false;
            }
        }

        /// Returns: Size of buffer in bytes.
        @property size_t size() pure const nothrow
        {
            return _size;
        }

        /// Returns: Copy bytes to the buffer.
        /// Throws: $(D OpenGLException) on error.
        void setData(T)(T[] buffer)
        {
            setData(buffer.length * T.sizeof, buffer.ptr);
        }

        /// Returns: Copy bytes to the buffer.
        /// Throws: $(D OpenGLException) on error.
        void setData(size_t size, void * data)
        {
            bind();
            _size = size;

            // discard previous data
            if (!_firstLoad)
            {
                glBufferData(_target, size, null, _usage);
                glBufferSubData(_target, 0, size, data);
            }
            else
                glBufferData(_target, size, data, _usage);

            _gl.runtimeCheck();

            _firstLoad = false;
        }

        /// Copies bytes to a sub-part of the buffer. You can't adress data beyond the buffer's size.
        /// Throws: $(D OpenGLException) on error.
        void setSubData(size_t offset, size_t size, void* data)
        {
            bind();
            glBufferSubData(_target, offset, size, data);
            _gl.runtimeCheck();
        }

        /// Gets a sub-part of a buffer.
        /// Throws: $(D OpenGLException) on error.
        void getSubData(size_t offset, size_t size, void* data)
        {
            bind();
            glGetBufferSubData(_target, offset, size, data);
            _gl.runtimeCheck();
        }

        /// Gets the whole buffer content in a newly allocated array.
        /// <b>This is intended for debugging purposes.</b>
        /// Throws: $(D OpenGLException) on error.
        ubyte[] getBytes()
        {
            auto buffer = new ubyte[_size];
            getSubData(0, _size, buffer.ptr);
            return buffer;
        }

        /// Binds this buffer.
        /// Throws: $(D OpenGLException) on error.
        void bind()
        {
            glBindBuffer(_target, _buffer);
            _gl.runtimeCheck();
        }

        /// Unbinds this buffer.
        /// Throws: $(D OpenGLException) on error.
        void unbind()
        {
            glBindBuffer(_target, 0);
        }

        /// Returns: Wrapped OpenGL resource handle.
        GLuint handle() pure const nothrow
        {
            return _buffer;
        }
    }

    private
    {
        OpenGL _gl;
        GLuint _buffer;
        size_t _size;
        GLuint _target;
        GLuint _usage;
        bool _firstLoad;
        bool _initialized;
    }
}
