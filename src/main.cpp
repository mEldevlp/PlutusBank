#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <iostream>
#include "DatabaseManager.h"
#include "AuthController.h"

#ifdef Q_OS_WIN
#include <windows.h>
#endif

int main(int argc, char* argv[])
{
#ifdef Q_OS_WIN
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif

    QGuiApplication app(argc, argv);

    // Подключение к базе данных
    if (!DatabaseManager::instance().connect()) 
    {
        qWarning() << "Не удалось подключиться к БД. Продолжаем без БД...";
    }

    // Создаём контроллер авторизации
    AuthController authController;

    QQmlApplicationEngine engine;

    // Регистрируем контроллер в QML контексте
    engine.rootContext()->setContextProperty("authController", &authController);

    const QUrl url = QUrl::fromLocalFile(
        QDir(QCoreApplication::applicationDirPath())
        .filePath("qml/Main.qml"));

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject* obj, const QUrl& objUrl) 
        {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    engine.load(url);

    int result = app.exec();

    // Отключение от БД при завершении
    DatabaseManager::instance().disconnect();

    return result;
}
