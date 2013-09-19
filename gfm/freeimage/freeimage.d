module gfm.freeimage.freeimage;

import std.conv,
       std.string;

import derelict.freeimage.freeimage,
       derelict.util.exception;

import gfm.common.log,
       gfm.common.text;

class FreeImageException : Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
        }
    }
}

final class FreeImage
{
    public
    {
        this(Log log, bool useExternalPlugins = false)
        {
            _log = log is null ? new NullLog() : log;

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

            _log.infof("FreeImage %s initialized.", getVersion());
            _log.infof("%s.", getCopyrightMessage());
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
            return sanitizeUTF8(versionZ, _log, "FreeImage_GetVersion");
        }

        string getCopyrightMessage()
        {
            const(char)* copyrightZ = FreeImage_GetCopyrightMessage();
            return sanitizeUTF8(copyrightZ, _log, "FreeImage_GetCopyrightMessage");
        }
    }

    package
    {
        Log _log;
    }

    private
    {
        bool _libInitialized;
    }
}
