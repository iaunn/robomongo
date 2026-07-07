#pragma once

#include <QObject>
#include <QString>
#include <string>

#ifdef MONGO_VERSION_GE_44
#include <mongo/log/log_severity.h>
namespace mongo {
namespace logger {
    class LogSeverity {
    public:
        LogSeverity(::mongo::logv2::LogSeverity s) : _s(s) {}
        static LogSeverity Info() { return LogSeverity(::mongo::logv2::LogSeverity::Info()); }
        static LogSeverity Warning() { return LogSeverity(::mongo::logv2::LogSeverity::Warning()); }
        static LogSeverity Error() { return LogSeverity(::mongo::logv2::LogSeverity::Error()); }
        static LogSeverity Log() { return LogSeverity(::mongo::logv2::LogSeverity::Debug(1)); }

        struct StringWrapper {
            std::string s;
            std::string toString() const { return s; }
        };

        StringWrapper toStringData() const {
            return StringWrapper{_s.toString()};
        }

        ::mongo::logv2::LogSeverity get() const { return _s; }
        bool operator==(const LogSeverity& other) const { return _s == other._s; }
    private:
        ::mongo::logv2::LogSeverity _s;
    };
}
}
#else
#include <mongo/logger/log_severity.h>
#endif

#include "robomongo/core/events/MongoEvents.h"
#include "robomongo/core/utils/SingletonPattern.hpp"

namespace Robomongo
{  
    class Logger : public QObject, public Patterns::LazySingleton<Logger>
    {
        Q_OBJECT
        friend class Patterns::LazySingleton<Logger>;

    public:
        void print(const char *msg, mongo::logger::LogSeverity level, bool notify);
        void print(const std::string &msg, mongo::logger::LogSeverity level, bool notify);
        void print(const QString &msg, mongo::logger::LogSeverity level, bool notify);

    Q_SIGNALS:
        void printed(const QString &msg, mongo::logger::LogSeverity level);

    private:
        Logger();
        ~Logger();
    };

    // Use in main thread
    template<typename T>
    inline void LOG_MSG(const T &msg, mongo::logger::LogSeverity level, bool notify = true)
    {
        return Logger::instance().print(msg, level, notify);
    }
    
    // Use in worker threads (e.g. MongoWorker) to log anything 
    // Sends LogEvent to main thread (App class) 
    void sendLog(
        QObject *sender, LogEvent::LogLevel const& severity,
        std::string const& msg, bool const informUser = false
    );

    void debugLog(std::string_view msg);
}