#pragma once

#include <QObject>
#include <QTcpSocket>
#include <QJsonObject>
#include <QByteArray>
#include <atomic>

/*
    TestClient — самостоятельный синхронный TCP-клиент, повторяющий тот же
    проводной протокол, что и production-овский NetworkClient (см.
    shared/NetworkProtocol.h):

        [4 байта BE uint32 длина] + [JSON UTF-8 payload]

    Не зависит ни от Qt Quick, ни от Qt GUI — только Core + Network.

    Метод call() — синхронный (блокируется через QEventLoop) и при любой
    ошибке (нет соединения / таймаут / сокет разорван) возвращает
    стандартный ответ-ошибку:
        { "id": ..., "success": false, "error": "..." }
*/

class TestClient : public QObject
{
    Q_OBJECT

public:
    explicit TestClient(QObject* parent = nullptr);
    ~TestClient() override;

    bool connectToServer(const QString& host, quint16 port);
    void disconnectFromServer();
    bool isConnected() const;

    // Полный объект ответа, как пришёл от сервера (или makeError при ошибке транспорта)
    QJsonObject call(const QString& method, const QJsonObject& params);

private:
    static constexpr int CONNECT_TIMEOUT_MS = 5000;
    static constexpr int WRITE_TIMEOUT_MS   = 2000;
    static constexpr int REQUEST_TIMEOUT_MS = 15000;

    TestClient(const TestClient&) = delete;
    TestClient& operator=(const TestClient&) = delete;

    QTcpSocket*         m_socket = nullptr;
    QByteArray          m_buffer;
    std::atomic<qint64> m_nextId{ 1 };
};
