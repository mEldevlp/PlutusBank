#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>

#include "DatabaseManager.h"
#include "AuthController.h"
#include "UserSession.h"
#include "CardController.h"

#ifdef Q_OS_WIN
    #include <windows.h>
#endif

#ifdef Q_OS_WIN
    // Обработчик сообщений Qt для корректного вывода кириллицы в Windows консоль
    void windowsMessageHandler(QtMsgType type, const QMessageLogContext& context, const QString& msg);
#endif

int main(int argc, char* argv[])
{
#ifdef Q_OS_WIN
    // Устанавливаем обработчик сообщений
    qInstallMessageHandler(windowsMessageHandler);
#endif

    QGuiApplication app(argc, argv);

    // Подключение к базе данных
    DatabaseManager& db = DatabaseManager::instance();
    if (!db.connect()) 
    {
        qCritical() << u"Не удалось подключиться к базе данных!";
        return -1;
    }

    // Создание контроллеров
    AuthController authController;
    UserSession& userSession = UserSession::instance();
    CardController cardController;

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("authController", &authController);
    engine.rootContext()->setContextProperty("userSession", &userSession);
    engine.rootContext()->setContextProperty("cardController", &cardController);

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

#ifdef Q_OS_WIN
void windowsMessageHandler(QtMsgType type, const QMessageLogContext& context, const QString& msg)
{
    // Форматируем сообщение стандартным способом Qt (включая время, тип, файл:строка)
    QString formattedMsg = qFormatLogMessage(type, context, msg);

    // Определяем, в какой поток писать (qDebug/qInfo/qWarning -> stderr, остальное тоже stderr)
    DWORD stdHandle = STD_ERROR_HANDLE;

    HANDLE hConsole = GetStdHandle(stdHandle);

    // Проверяем, что handle валидный
    if (hConsole == INVALID_HANDLE_VALUE || hConsole == NULL)
    {
        return;
    }

    // Проверяем, является ли вывод реальной консолью или перенаправлен в файл/пайп
    DWORD fileType = GetFileType(hConsole);
    bool isRealConsole = (fileType == FILE_TYPE_CHAR);

    if (isRealConsole)
    {
        // Это реальная консоль - пишем через WriteConsoleW (UTF-16)
        // Добавляем перенос строки
        formattedMsg += "\n";

        // Конвертируем QString в wchar_t* (UTF-16)
        const wchar_t* wideMsg = reinterpret_cast<const wchar_t*>(formattedMsg.utf16());
        DWORD written;
        WriteConsoleW(hConsole, wideMsg, formattedMsg.length(), &written, NULL);
    }
    else
    {
        // Вывод перенаправлен в файл или пайп - пишем UTF-8 через WriteFile
        formattedMsg += "\n";
        QByteArray utf8Msg = formattedMsg.toUtf8();
        DWORD written;
        WriteFile(hConsole, utf8Msg.constData(), utf8Msg.size(), &written, NULL);
    }

    // Для qFatal завершаем приложение
    if (type == QtFatalMsg)
    {
        abort();
    }
}
#endif