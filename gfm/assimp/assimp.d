module gfm.assimp.assimp;

import std.conv,
       std.string,
       std.array : join;

import derelict.assimp.assimp,
       derelict.util.exception;

import gfm.common.log,
       gfm.common.text;

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
            _log = log is null ? new NullLog() : log;

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

            // enable verbose logging in debug-mode
            debug
                aiEnableVerboseLogging(AI_TRUE);
            else
                aiEnableVerboseLogging(AI_FALSE);

            // route Assimp logging to our own
            _logStream.callback = &loggingCallbackAssimp;
            _logStream.user = cast(char*)(cast(void*)this);
            aiAttachLogStream(&_logStream);
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_libInitialized)
            {
                aiDetachLogStream(&_logStream);
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
            return sanitizeUTF8(legalZ, _log, "Assimp legal string");
        }
    }

    package
    {
        Log _log;

        // exception mechanism that shall be used by every module here
        void throwAssimpException(string callThatFailed)
        {
            string message = format("%s failed: %s", callThatFailed, getErrorString());
            throw new AssimpException(message);
        }

        string getErrorString()
        {
            const(char)* errorZ = aiGetErrorString();
            return sanitizeUTF8(errorZ, _log, "Assimp error string");
        }
    }

    private
    {
        bool _libInitialized;
        aiLogStream _logStream;
    }
}

extern (C) private 
{
    void loggingCallbackAssimp(const(char)* message, char* user) nothrow
    {
        Assimp assimp = cast(Assimp)user;
        try
        {
            Log log = assimp._log;
            log.infof("assimp: %s", sanitizeUTF8(message, log, "Assimp logging"));
        }
        catch(Exception e)
        {
            // ignoring IO exceptions, format errors, etc... to be nothrow
            // making the whole Log interface nothrow is not that trivial
        }
    }
}