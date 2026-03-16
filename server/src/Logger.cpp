#include "Logger.h"
#include <QDateTime>
#include <QTextStream>
#include <iostream>

Logger& Logger::instance()
{
    static Logger inst;
    return inst;
}

Logger::~Logger()
{
    if (m_fileOpen)
        m_file.close();
}

void Logger::init(const QString& filePath, const QString& level, bool timestamps)
{
    m_timestamps = timestamps;

    if (level == "info")         m_level = Info;
    else if (level == "warning") m_level = Warning;
    else if (level == "error")   m_level = Error;
    else                         m_level = Debug;

    if (!filePath.isEmpty())
    {
        m_file.setFileName(filePath);
        m_fileOpen = m_file.open(QIODevice::Append | QIODevice::Text);
        if (!m_fileOpen)
            std::cerr << "Logger: не удалось открыть файл " << filePath.toStdString() << std::endl;
    }
}

void Logger::debug(const QString& msg, const QString& clientTag)
{
    write(Debug, msg, clientTag);
}

void Logger::info(const QString& msg, const QString& clientTag)
{
    write(Info, msg, clientTag);
}

void Logger::warning(const QString& msg, const QString& clientTag)
{
    write(Warning, msg, clientTag);
}

void Logger::error(const QString& msg, const QString& clientTag)
{
    write(Error, msg, clientTag);
}

void Logger::userAction(const QString& clientTag, int userId, const QString& action)
{
    QString msg = QString("[USER %1] %2").arg(userId).arg(action);
    write(Info, msg, clientTag);
}

void Logger::write(Level lvl, const QString& msg, const QString& clientTag)
{
    if (lvl < m_level)
        return;

    QMutexLocker lock(&m_mutex);

    QString line;

    if (m_timestamps)
        line += QDateTime::currentDateTime().toString("[yyyy-MM-dd HH:mm:ss] ");

    line += QString("[%1] ").arg(levelToString(lvl));

    if (!clientTag.isEmpty())
        line += QString("(%1) ").arg(clientTag);

    line += msg;

    // Консоль
    QTextStream out(stdout);
    out << line << "\n";
    out.flush();

    // Файл
    if (m_fileOpen)
    {
        QTextStream fout(&m_file);
        fout << line << "\n";
        fout.flush();
    }
}

QString Logger::levelToString(Level lvl) const
{
    switch (lvl)
    {
        case Debug:   return "DEBUG";
        case Info:    return "INFO";
        case Warning: return "WARN";
        case Error:   return "ERROR";
    }
    return "?????";
}
