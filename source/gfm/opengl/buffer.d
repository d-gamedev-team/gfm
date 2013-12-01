module gfm.opengl.buffer;

import derelict.opengl3.gl3;

import gfm.opengl.opengl;

final class GLBuffer
{
    public
    {
        this(OpenGL gl, GLuint target, GLuint storage, GLuint usage)
        {
            _gl = gl;
            _storage = storage;
            _usage = usage;
            _target = target;
            _firstLoad = true;

            glGenBuffers(1, &_buffer);
            _initialized = true;
            _size = 0;
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_initialized)
            {
                glDeleteBuffers(1, &_buffer);
                _initialized = false;
            }
        }

        /// Return size in bytes.
        size_t size() pure const nothrow
        {
            return _size;
        }

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

        void setSubData(size_t offset, size_t size, void* data)
        {
            bind();
            glBufferSubData(_target, offset, size, data);
            _gl.runtimeCheck();
        }

        /// Get a sub-part of a buffer.
        void getSubData(size_t offset, size_t size, void* data)
        {
            bind();
            glGetBufferSubData(_target, offset, size, data);
            _gl.runtimeCheck();
        }

        /// Get a whole-buffer in a newly allocated array.
        /// Debugging-purpose.
        ubyte[] getBytes()
        {
            auto buffer = new ubyte[_size];
            getSubData(0, _size, buffer.ptr);
            return buffer;
        }

        void bind()
        {
            glBindBuffer(_target, _buffer);
            _gl.runtimeCheck();
        }

        void unbind()
        {
            glBindBuffer(_target, 0);
        }

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
        GLuint _storage;
        GLuint _usage;
        bool _firstLoad;
        bool _initialized;
    }
}
