module gfm.core.log;

import std.stream,
       std.stdio,
       std.string;

import std.logger;

version(Windows)
{
    import core.sys.windows.windows;
}

// Because default std.logger logger is a bit verbose, and lacks colors.
class ConsoleLogger : Logger
{
    public
    {
        this()
        {
            super("", LogLevel.info);

            version(Windows)
            {
                _console = GetStdHandle(STD_OUTPUT_HANDLE);

                // saves console attributes
                _savedInitialColor = (0 != GetConsoleScreenBufferInfo(_console, &consoleInfo));
            }
        }

        override void writeLogMsg(ref LoggerPayload payload) @trusted
        {
            LogLevel logLevel;
            synchronized(this)
            {
                version(Windows)
                {
                    switch(payload.logLevel)
                    {
                        case LogLevel.info:
                            SetConsoleTextAttribute(_console, 15);
                            break;

                        case LogLevel.warning:
                            SetConsoleTextAttribute(_console, 14);
                            break;

                        case LogLevel.error:
                        case LogLevel.critical:
                        case LogLevel.fatal:
                            SetConsoleTextAttribute(_console, 12);
                            break;

                        case LogLevel.unspecific:
                        case LogLevel.trace:
                        default:
                            SetConsoleTextAttribute(_console, 11); 
                    }
                }

                import std.stdio;
                writefln("%s: %s", logLevelToString(payload.logLevel), payload.msg);
            }
        }

        ~this()
        {
            close();
        }

        void close()
        {
            version(Windows)
            {
                // restore initial console attributes
                if (_savedInitialColor)
                {
                    SetConsoleTextAttribute(_console, consoleInfo.wAttributes);
                    _savedInitialColor = false;
                }
            }
        }
    }

    private
    {
        version(Windows)
        {
            HANDLE _console;
            bool _savedInitialColor;
            CONSOLE_SCREEN_BUFFER_INFO consoleInfo;
        }

        static pure string logLevelToString(const LogLevel lv)
        {
            switch(lv)
            {
                case LogLevel.unspecific:
                    return "";
                case LogLevel.trace:
                    return "trace";
                case LogLevel.info:
                    return "info";
                case LogLevel.warning:
                    return "warning";
                case LogLevel.error:
                    return "error";
                case LogLevel.critical:
                    return "critical";
                case LogLevel.fatal:
                    return "fatal";
                default:
                    assert(false);
            }
        }
    }
}
