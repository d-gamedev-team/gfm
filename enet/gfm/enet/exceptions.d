/// Defines any new ENet-related exceptions that may be thrown.

module gfm.enet.exceptions;

/// Writes a string along with the caller function and line number.
debug void writed(string msg, string caller = __FUNCTION__)
{
    import std.stdio : writefln;
    writefln("[%s]: %s", caller, msg);
}

/// General ENet exception thrown for all cases.
class ENetException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}
