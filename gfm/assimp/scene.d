module gfm.assimp.scene;

import std.string;

import derelict.assimp.assimp;

import gfm.assimp.assimp;

class AssimpScene
{
    public
    {
        /// Import mesh from a file
        this(Assimp assimp, string path, uint postProcessFlags = 0)
        {
            _assimp = assimp;
            _scene = aiImportFile(toStringz(path), postProcessFlags);
            if (_scene is null)
                assimp.throwAssimpException("aiImportFile");
        }

        /// Import mesh from a memory area
        this(Assimp assimp, ubyte[] data, uint postProcessFlags = 0)
        {
            _assimp = assimp;
            _scene = aiImportFileFromMemory(cast(const(char)*)(data.ptr),
                                            data.length,
                                            postProcessFlags,
                                            null);
            if (_scene is null)
                assimp.throwAssimpException("aiImportFileFromMemory");
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_scene !is null)
            {
                aiReleaseImport(_scene);
                _scene = null;
            }
        }

        /// To separate loading from post-processing
        void applyPostProcessing(uint postProcessFlags)
        {
            const(aiScene)* newScene = aiApplyPostProcessing(_scene, postProcessFlags);
            if (newScene is null)
                _assimp.throwAssimpException("aiApplyPostProcessing");
            _scene = newScene;
        }

        /// Get ASSIMP scene handle
        const(aiScene)* scene()
        {
            return _scene;
        }
    }

    private
    {
        Assimp _assimp;
        const(aiScene)* _scene;
    }
}