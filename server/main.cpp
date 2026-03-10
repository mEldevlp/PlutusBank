#include <QCoreApplication>
#include <QDir>

#include "ServerConfig.h"
#include "Logger.h"
#include "DatabaseManager.h"
#include "BankServer.h"
#include "ConsoleHandler.h"
#include "ClientSession.h"

#ifdef Q_OS_WIN
#include <windows.h>
#endif

static void handleCommand(const QString& input, BankServer* server)
{
    QStringList parts = input.split(' ', Qt::SkipEmptyParts);
    if (parts.isEmpty()) return;

    QString cmd = parts[0].toLower();

    if (cmd == "help")
    {
        Logger::instance().info(
            "Доступные команды:\n"
            "  help              — список команд\n"
            "  status            — статус сервера\n"
            "  clients           — список подключённых клиентов\n"
            "  kick <ip:port>    — отключить клиента\n"
            "  kickall           — отключить всех клиентов\n"
            "  stop / quit       — остановить сервер"
        );
    }
    else if (cmd == "status")
    {
        Logger::instance().info(
            QString("Клиентов онлайн: %1  |  Сервер: %2:%3")
                .arg(server->clientCount())
                .arg(server->serverAddress().toString())
                .arg(server->serverPort()));
    }
    else if (cmd == "clients")
    {
        auto clients = server->clients();
        if (clients.isEmpty())
        {
            Logger::instance().info("Нет подключённых клиентов");
        }
        else
        {
            for (const auto* c : clients)
            {
                Logger::instance().info(
                    QString("  %1  userId=%2").arg(c->tag()).arg(c->userId()));
            }
        }
    }
    else if (cmd == "kick" && parts.size() >= 2)
    {
        server->kickClient(parts[1]);
    }
    else if (cmd == "kickall")
    {
        server->kickAll();
    }
    else if (cmd == "stop" || cmd == "quit" || cmd == "exit")
    {
        Logger::instance().info("Завершение работы сервера...");
        server->stop();
        QCoreApplication::quit();
    }
    else
    {
        Logger::instance().warning("Неизвестная команда: " + cmd + ". Введите 'help'.");
    }
}

int main(int argc, char* argv[])
{
#ifdef Q_OS_WIN
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif

    QCoreApplication app(argc, argv);
    app.setApplicationName("PlutusBankServer");
    app.setApplicationVersion("1.0.0");

    // Путь к settings.ini рядом с исполняемым файлом
    QString configPath = QDir(QCoreApplication::applicationDirPath())
                             .filePath("settings.ini");

    // Загрузка конфигурации
    ServerConfig cfg = ServerConfig::load(configPath);

    // Инициализация логера
    Logger::instance().init(cfg.logFile, cfg.logLevel, cfg.logTimestamps);

    Logger::instance().info("=== PlutusBank Server v1.0.0 ===");
    Logger::instance().info("Конфигурация: " + configPath);

    // Подключение к БД
    DatabaseManager& db = DatabaseManager::instance();
    db.setConnectionParams(cfg.dbDriver, cfg.dbHost, cfg.dbPort,
                           cfg.dbName, cfg.dbUser, cfg.dbPassword);

    if (!db.connect())
    {
        Logger::instance().error("Не удалось подключиться к базе данных!");
        return -1;
    }

    Logger::instance().info("Подключение к PostgreSQL — OK");

    // Запуск TCP-сервера
    BankServer server;
    if (!server.startListening(cfg.serverHost, cfg.serverPort))
        return -1;

    // Консольный ввод в отдельном потоке
    ConsoleHandler console;
    QObject::connect(&console, &ConsoleHandler::commandReceived,
                     &app, [&server](const QString& cmd)
    {
        handleCommand(cmd, &server);
    });
    console.start();

    Logger::instance().info("Сервер готов. Введите 'help' для списка команд.");

    int result = app.exec();

    // Корректное завершение
    console.stop();
    console.wait(2000);
    server.stop();
    db.disconnect();

    Logger::instance().info("Сервер остановлен.");
    return result;
}
