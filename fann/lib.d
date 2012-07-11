module gfm.fann.lib;

import std.conv;
import derelict.fann.fann;

final class FANNLib
{
    public
    {
        this()
        {
            DerelictFANN.load();
        }

        ~this()
        {
            close();
        }

        void close()
        {
            DerelictFANN.unload();
        }

        void runtimeCheck()
        {
            FANN_ERROR lastErrDat;
            fann_errno_enum lastErrno = fann_get_errno(&lastErrDat);
            if (FANN_E_NO_ERROR != lastErrno)
            {
                const(char)* msg = fann_get_errstr(&lastErrDat);
                throw new FANNException(to!string(msg));
            }
        }
    }
}

class FANNException : Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
        }
    }
}
