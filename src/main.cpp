#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDir>

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    // путь к qml/Main.qml рядом с исполняемым файлом
    const QUrl url = QUrl::fromLocalFile(
        QDir(QCoreApplication::applicationDirPath())
        .filePath("qml/Main.qml"));

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject* obj, const QUrl& objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection); 

    engine.load(url);
    return app.exec();
}
