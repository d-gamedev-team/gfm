module gfm.assimp.assimp;

import std.conv;
import std.string;
import std.array : join;
import derelict.assimp.assimp;
import derelict.util.exception;
import gfm.common.log;
import gfm.common.text;

class AssimpException : Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
        }
    }
}

final class Assimp
{
    public
    {
        this(Log log)
        {
            _log = log;

            try
            {
                DerelictASSIMP.load();
            }
            catch(DerelictException e)
            {
                throw new AssimpException(e.msg);
            }

            _libInitialized = true;

            _log.infof("Assimp %s initialized.", getVersion());
            _log.infof("%s.", getLegalString());
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_libInitialized)
            {
                DerelictASSIMP.unload();
                _libInitialized = false;
            }
        }

        alias nothrow uint function() da_aiGetVersionMinor;
        alias nothrow uint function() da_aiGetVersionMajor;
        alias nothrow uint function() da_aiGetVersionRevision;
        alias nothrow uint function() da_aiGetCompileFlags;

        string getVersion()
        {
            string compileFlags()
            {
                string[] res;
                uint flags = aiGetCompileFlags();
                if ((flags & ASSIMP_CFLAGS_SHARED) != 0)
                    res ~= "shared";
                if ((flags & ASSIMP_CFLAGS_STLPORT) != 0)
                    res ~= "stl-port";
                if ((flags & ASSIMP_CFLAGS_DEBUG) != 0)
                    res ~= "debug";
                if ((flags & ASSIMP_CFLAGS_NOBOOST) != 0)
                    res ~= "no-boost";
                if ((flags & ASSIMP_CFLAGS_SINGLETHREADED) != 0)
                    res ~= "single-threaded";
                return join(res, ", ");
            }
            return format("v%s.%s_r%s (%s)", aiGetVersionMajor(), aiGetVersionMinor(), aiGetVersionRevision(), compileFlags());
        }

        string getLegalString()
        {
            const(char)* legalZ = aiGetLegalString();
            return sanitizeUTF8(legalZ);
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
