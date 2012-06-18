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

        void setData(size_t size, void * data)
        {
            bind();

            // discard previous data
            if (!_firstLoad)
            {
                glBufferData(_target, size, null, _usage);
                glBufferSubData(_target, 0, size, data);
            }
            else
                glBufferData(_target, size, data, _usage);
            
            _gl.debugCheck();

            _firstLoad = false;
        }

        void setSubData(size_t offset, size_t size, void* data)
        {
            bind();
            glBufferSubData(_target, offset, size, data);
            _gl.debugCheck();
        }

        void bind()
        {
            glBindBuffer(_target, _buffer);
            _gl.debugCheck();
        }

        void unbind()
        {
            glBindBuffer(_target, 0);
        }
    }

    package
    {
        GLuint _buffer;
    }

    private
    {
        OpenGL _gl;
        GLuint _target;
        GLuint _storage;
        GLuint _usage;
        bool _firstLoad;
        bool _initialized;
    }
}
