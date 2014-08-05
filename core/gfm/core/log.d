module gfm.core.log;

import std.stream,
       std.string;

import std.logger;
import colorize;

// Because default std.logger logger is a bit verbose, and lacks colors.
class ConsoleLogger : Logger
{
    public
    {
        this()
        {
            super("", LogLevel.info);
        }

        override void writeLogMsg(ref LoggerPayload payload) @trusted
        {
            LogLevel logLevel;
            
            synchronized(this)
            {
                auto foregroundColor = fg.white;
                switch(payload.logLevel)
                {
                    case LogLevel.info:
                        foregroundColor = fg.light_white;
                        break;

                    case LogLevel.warning:
                        foregroundColor = fg.light_yellow;
                        break;

                    case LogLevel.error:
                    case LogLevel.critical:
                    case LogLevel.fatal:
                        foregroundColor = fg.light_red;
                        break;

                    case LogLevel.unspecific:
                    case LogLevel.trace:
                    default:
                        foregroundColor = fg.white;
                }

                import colorize.cwrite;
                cwritefln( color("%s: %s", foregroundColor), logLevelToString(payload.logLevel), payload.msg);
            }
        }

        ~this()
        {
        }

        deprecated("No need to call close() on ConsoleLogger anymore") void close()
        {
        }
    }

    private
    {
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
