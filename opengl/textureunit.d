module gfm.opengl.textureunit;

import derelict.opengl3.gl3;

import gfm.common.log;
import gfm.opengl.opengl;

// Cache state of OpenGL texture units
// Use deprecated image units!
final class TextureUnits
{
    public
    {
        this(OpenGL gl)
        {
            _gl = gl;
            _activeTexture = -1; // default is unknown

            int imageUnits = gl.maxTextureUnits();
            int textureImageUnits = gl.maxTextureImageUnits();

            // use the min for more safety: the specification of 4.2 Compatibility profile is 
            // not very clear
            int units = imageUnits < textureImageUnits ? imageUnits : textureImageUnits;

            _textureUnits.length = units;
            for (int i = 0; i < units; ++i)
            {
                bool fixedPipelineCompatible = true;
                _textureUnits[i] = new TextureUnit(gl, i, fixedPipelineCompatible);
            }
        }

        // set "active texture" which is actually active texture unit
        void setActiveTexture(int texture)
        {
            if (_textureUnits.length == 1)
                return;

            if (glActiveTexture is null)
                return;

            if (_activeTexture != texture)
            {
                glActiveTexture(GL_TEXTURE0 + texture);
                _activeTexture = texture;
            }
        }

        TextureUnit unit(int i)
        {
            return _textureUnits[i];
        }

        TextureUnit current()
        {
            if (_activeTexture == -1)
                setActiveTexture(0);

            return _textureUnits[_activeTexture];
        }
    }

    private
    {
        OpenGL _gl;
        int _activeTexture;         // index of currently active texture unit
        TextureUnit[] _textureUnits; // all texture units
    }
}

// Cache state of OpenGL of a single OpenGL texture units
final class TextureUnit
{
    public
    {
        this(OpenGL gl, int index, bool fixedPipelineCompatible)
        {
            _gl = gl;
            _index = index;
            _fixedPipelineCompatible = fixedPipelineCompatible;

            _currentBinding[] = -1; // default is unknown
        }

        void bind(GLenum target, GLuint texture)
        {
            size_t index = targetToIndex(cast(Target)target);
            if(_currentBinding[index] != texture)
            {
                glBindTexture(target, texture);
                _gl.runtimeCheck();
                _currentBinding[index] = texture;
            }
        }
    }

    private
    {
        enum Target : GLenum
        {
            TEXTURE_1D = GL_TEXTURE_1D, 
            TEXTURE_2D = GL_TEXTURE_2D, 
            TEXTURE_3D = GL_TEXTURE_3D, 
            TEXTURE_1D_ARRAY = GL_TEXTURE_1D_ARRAY, 
            TEXTURE_2D_ARRAY = GL_TEXTURE_2D_ARRAY, 
            TEXTURE_RECTANGLE = GL_TEXTURE_RECTANGLE, 
            TEXTURE_BUFFER = GL_TEXTURE_BUFFER, 
            TEXTURE_CUBE_MAP = GL_TEXTURE_CUBE_MAP,
            TEXTURE_CUBE_MAP_ARRAY = GL_TEXTURE_CUBE_MAP_ARRAY, 
            TEXTURE_2D_MULTISAMPLE = GL_TEXTURE_2D_MULTISAMPLE, 
            TEXTURE_2D_MULTISAMPLE_ARRAY = GL_TEXTURE_2D_MULTISAMPLE_ARRAY 
        }

        size_t targetToIndex(Target target)
        {
            final switch(target)
            {
                case Target.TEXTURE_1D: return 0;
                case Target.TEXTURE_2D: return 1;
                case Target.TEXTURE_3D: return 2;
                case Target.TEXTURE_1D_ARRAY: return 3;
                case Target.TEXTURE_2D_ARRAY: return 4;
                case Target.TEXTURE_RECTANGLE: return 5;
                case Target.TEXTURE_BUFFER: return 6;
                case Target.TEXTURE_CUBE_MAP: return 7;
                case Target.TEXTURE_CUBE_MAP_ARRAY: return 8;
                case Target.TEXTURE_2D_MULTISAMPLE: return 9;
                case Target.TEXTURE_2D_MULTISAMPLE_ARRAY: return 10;
            }
        }

        OpenGL _gl;
        int _index;
        bool _fixedPipelineCompatible;

        GLuint[Target.max + 1] _currentBinding;
    }
}
