#pragma once

#include <QString>
#include <QSettings>

struct ServerConfig
{
    // [Server]
    QString serverHost  = "0.0.0.0";
    quint16 serverPort  = 9500;

    // [Database]
    QString dbDriver    = "QPSQL";
    QString dbHost      = "127.0.0.1";
    int     dbPort      = 5433;
    QString dbName      = "plutusbank";
    QString dbUser      = "postgres";
    QString dbPassword  = "root";

    // [Logging]
    QString logFile;
    QString logLevel    = "debug";
    bool    logTimestamps = true;

    static ServerConfig load(const QString& path)
    {
        QSettings ini(path, QSettings::IniFormat);
        ServerConfig cfg;

        ini.beginGroup("Server");
        cfg.serverHost = ini.value("host", cfg.serverHost).toString();
        cfg.serverPort = ini.value("port", cfg.serverPort).toUInt();
        ini.endGroup();

        ini.beginGroup("Database");
        cfg.dbDriver   = ini.value("driver",   cfg.dbDriver).toString();
        cfg.dbHost     = ini.value("host",     cfg.dbHost).toString();
        cfg.dbPort     = ini.value("port",     cfg.dbPort).toInt();
        cfg.dbName     = ini.value("name",     cfg.dbName).toString();
        cfg.dbUser     = ini.value("user",     cfg.dbUser).toString();
        cfg.dbPassword = ini.value("password", cfg.dbPassword).toString();
        ini.endGroup();

        ini.beginGroup("Logging");
        cfg.logFile       = ini.value("file",       cfg.logFile).toString();
        cfg.logLevel      = ini.value("level",      cfg.logLevel).toString();
        cfg.logTimestamps = ini.value("timestamps", cfg.logTimestamps).toBool();
        ini.endGroup();

        return cfg;
    }
};
