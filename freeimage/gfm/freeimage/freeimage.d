module gfm.freeimage.freeimage;

import std.conv,
       std.string;

import derelict.freeimage.freeimage,
       derelict.util.exception;

import std.experimental.logger;

import gfm.core.text;

/// The one exception type thrown in this wrapper.
/// A failing FreeImage function should <b>always</b> throw an FreeImageException.
class FreeImageException : Exception
{
    public
    {
        @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super(message, file, line, next);
        }
    }
}

/// FreeImage library wrapper.
final class FreeImage
{
    public
    {
        /// Loads the FreeImage library and logs some information.
        /// Throws: FreeImageException on error.
        this(Logger logger, bool useExternalPlugins = false)
        {
            _logger = logger is null ? new NullLogger() : logger;

            try
            {
                DerelictFI.load();
            }
            catch(DerelictException e)
            {
                throw new FreeImageException(e.msg);
            }

            //FreeImage_Initialise(useExternalPlugins ? TRUE : FALSE); // documentation says it's useless
            _libInitialized = true;

            _logger.infof("FreeImage %s initialized.", getVersion());
            _logger.infof("%s.", getCopyrightMessage());
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_libInitialized)
            {
                //FreeImage_DeInitialise(); // documentation says it's useless
                DerelictFI.unload();
                _libInitialized = false;
            }
        }

        string getVersion()
        {
            const(char)* versionZ = FreeImage_GetVersion();
            return sanitizeUTF8(versionZ, _logger, "FreeImage_GetVersion");
        }

        string getCopyrightMessage()
        {
            const(char)* copyrightZ = FreeImage_GetCopyrightMessage();
            return sanitizeUTF8(copyrightZ, _logger, "FreeImage_GetCopyrightMessage");
        }
    }

    package
    {
        Logger _logger;
    }

    private
    {
        bool _libInitialized;
    }
}
