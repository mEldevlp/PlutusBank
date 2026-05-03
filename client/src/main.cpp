#include <QQuickWindow>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QQuickStyle>
#include <QSettings>

#include "NetworkClient.h"
#include "AuthController.h"
#include "UserSession.h"
#include "CardController.h"
#include "TransferController.h"
#include "HistoryController.h"
#include "LoanController.h"
#include "CryptoController.h"

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
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    QQuickStyle::setStyle("Basic");
    QGuiApplication app(argc, argv);

    //auto connect_ini = QDir(QCoreApplication::applicationDirPath()).filePath("connection.ini");
    QSettings connCfg(":/connection.ini", QSettings::IniFormat);
    QString serverHost = connCfg.value("Server/host", "80.249.146.54").toString();
    quint16 serverPort = connCfg.value("Server/port", 9500).toUInt();

    NetworkClient& net = NetworkClient::instance();
    if (!net.connectToServer(serverHost, serverPort))
    {
        qWarning() << "Не удалось подключиться к серверу при старте:" << serverHost << ":" << serverPort;
        // НЕ выходим — даём UI отработать, попытаемся переподключиться при логине
    }
    qDebug() << "Server config used:" << serverHost << ":" << serverPort;

    // Создание контроллеров
    AuthController authController;
    UserSession& userSession = UserSession::instance();
    CardController cardController;
    HistoryController historyController;
    TransferController transferController;
    LoanController loanController;
    CryptoController cryptoController;

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("authController", &authController);
    engine.rootContext()->setContextProperty("userSession", &userSession);
    engine.rootContext()->setContextProperty("cardController", &cardController);
    engine.rootContext()->setContextProperty("historyController", &historyController);
    engine.rootContext()->setContextProperty("transferController", &transferController);
    engine.rootContext()->setContextProperty("loanController", &loanController);
    engine.rootContext()->setContextProperty("cryptoController", &cryptoController);

    const QUrl url = QUrl::fromLocalFile(
        QDir(QCoreApplication::applicationDirPath())
        .filePath("qml/Main.qml"));

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("PlutusBank", "Main");

    int result = app.exec();

    // Отключение от БД при завершении
    NetworkClient::instance().disconnectFromServer();

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