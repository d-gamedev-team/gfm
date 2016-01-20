module gfm.assimp.scene;

import std.string;

import derelict.assimp3.assimp;

import gfm.assimp.assimp;

/// ASSIMP scene wrapper.
class AssimpScene
{
    public
    {
        /// Import mesh from a file.
        /// The ASSIMP library must have been loaded.
        /// Throws: AssimpException on error.
        this(Assimp assimp, string path, uint postProcessFlags = 0)
        {
            _assimp = assimp;
            _scene = aiImportFile(toStringz(path), postProcessFlags);
            if (_scene is null)
                assimp.throwAssimpException("aiImportFile");
        }

        /// Import mesh from a memory area.
        /// The ASSIMP library must have been loaded.
        /// Throws: AssimpException on error.
        this(Assimp assimp, ubyte[] data, uint postProcessFlags = 0)
        {
            _assimp = assimp;
            _scene = aiImportFileFromMemory(cast(const(char)*)(data.ptr),
                                            cast(uint)data.length,
                                            postProcessFlags,
                                            null);
            if (_scene is null)
                assimp.throwAssimpException("aiImportFileFromMemory");
        }

        /// Import mesh from a memory area using specified import properties.
        /// The ASSIMP library must have been loaded.
        /// Throws: AssimpException on error.
        this(Assimp assimp, ubyte[] data, aiPropertyStore* props, uint postProcessFlags = 0)
        {
            _assimp = assimp;
            _scene = aiImportFileFromMemoryWithProperties(cast(const(char)*)(data.ptr),
                                                          cast(uint)data.length,
                                                          postProcessFlags,
                                                          null,
                                                          props);
            if (_scene is null)
                assimp.throwAssimpException("aiImportFileFromMemoryWithProperties");
        }

        /// Releases the ASSIMP scene resource.
        ~this()
        {
            if (_scene !is null)
            {
                debug ensureNotInGC("AssimpScene");
                aiReleaseImport(_scene);
                _scene = null;
            }
        }

        /// Apply post-processing separately, to separate loading from post-processing.
        /// Throws: AssimpException on error.
        void applyPostProcessing(uint postProcessFlags)
        {
            const(aiScene)* newScene = aiApplyPostProcessing(_scene, postProcessFlags);
            if (newScene is null)
                _assimp.throwAssimpException("aiApplyPostProcessing");
            _scene = newScene;
        }

        /// Returns: Wrapped ASSIMP scene handle.
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
