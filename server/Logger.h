#pragma once

#include <QObject>
#include <QString>
#include <QFile>
#include <QTextStream>
#include <QMutex>

class Logger : public QObject
{
    Q_OBJECT

public:
    enum Level { Debug, Info, Warning, Error };

    static Logger& instance();

    void init(const QString& filePath, const QString& level, bool timestamps);

    void debug(const QString& msg,   const QString& clientTag = {});
    void info(const QString& msg,     const QString& clientTag = {});
    void warning(const QString& msg,  const QString& clientTag = {});
    void error(const QString& msg,    const QString& clientTag = {});

    // Лог действия пользователя (выводится всегда при level <= Info)
    void userAction(const QString& clientTag, int userId, const QString& action);

private:
    Logger() = default;
    ~Logger();
    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;

    void write(Level lvl, const QString& msg, const QString& clientTag);
    QString levelToString(Level lvl) const;

    QFile   m_file;
    QMutex  m_mutex;
    Level   m_level      = Debug;
    bool    m_timestamps = true;
    bool    m_fileOpen   = false;
};
