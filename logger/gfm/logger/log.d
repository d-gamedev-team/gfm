module gfm.logger.log;

import std.string;
import std.stdio;

import std.experimental.logger;

import colorize;

/// Coloured console logger.
class ConsoleLogger : Logger
{
    public
    {
        this()
        {
            super(LogLevel.info);
        }

        override protected void writeLogMsg(ref LogEntry payload) @trusted
        {
            LogLevel logLevel;

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

                case LogLevel.trace:
                default:
                    foregroundColor = fg.white;
            }

            import colorize.cwrite;
            stderr.cwritef( color("%s: %s\n", foregroundColor), logLevelToString(payload.logLevel), payload.msg);
        }
    }

    private
    {
        static pure string logLevelToString(const LogLevel lv)
        {
            switch(lv)
            {
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
