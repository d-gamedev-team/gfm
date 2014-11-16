module gfm.opengl.textureunit;

import derelict.opengl3.gl3;

import gfm.opengl.opengl;

/// Cache state of OpenGL texture units.
/// Use deprecated image units!
final class TextureUnits
{
    public
    {
        /// Creates a TextureUnits object.
        /// This is automatically done by loading OpenGL.
        this(OpenGL gl)
        {
            _gl = gl;

            // Gets the max total image units
            // Note: each shader stage has its own max to deal with
            _textureUnitsCount = gl.maxCombinedImageUnits();
        }

        /// Sets the "active texture" which is more precisely active texture unit.
        /// Throws: $(D OpenGLException) on error.
        void setActiveTexture(int texture)
        {
            if (_textureUnitsCount == 1)
                return;

            if (glActiveTexture is null)
                return;

            glActiveTexture(GL_TEXTURE0 + texture);
            _gl.runtimeCheck();
        }
    }

    private
    {
        OpenGL _gl;
        int _textureUnitsCount;
    }
}
