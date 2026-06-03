#include "TestClient.h"
#include "NetworkProtocol.h"

#include <QEventLoop>
#include <QTimer>

TestClient::TestClient(QObject* parent)
    : QObject(parent)
{
    m_socket = new QTcpSocket(this);
}

TestClient::~TestClient()
{
    disconnectFromServer();
}

bool TestClient::connectToServer(const QString& host, quint16 port)
{
    if (m_socket->state() == QAbstractSocket::ConnectedState)
        return true;

    m_socket->abort();
    m_buffer.clear();

    m_socket->connectToHost(host, port);
    if (!m_socket->waitForConnected(CONNECT_TIMEOUT_MS))
        return false;

    return true;
}

void TestClient::disconnectFromServer()
{
    if (m_socket && m_socket->state() != QAbstractSocket::UnconnectedState)
    {
        m_socket->disconnectFromHost();
        if (m_socket->state() != QAbstractSocket::UnconnectedState)
            m_socket->waitForDisconnected(1000);
    }
    m_buffer.clear();
}

bool TestClient::isConnected() const
{
    return m_socket && m_socket->state() == QAbstractSocket::ConnectedState;
}

QJsonObject TestClient::call(const QString& method, const QJsonObject& params)
{
    const qint64 id = m_nextId.fetch_add(1);

    if (!isConnected())
        return Protocol::makeError(id, QStringLiteral("Нет подключения к серверу"));

    const QJsonObject request = Protocol::makeRequest(method, params, id);
    const QByteArray  frame   = Protocol::pack(request);

    const qint64 written = m_socket->write(frame);
    if (written != frame.size())
        return Protocol::makeError(id, QStringLiteral("Не удалось записать запрос в сокет"));

    if (!m_socket->waitForBytesWritten(WRITE_TIMEOUT_MS))
        return Protocol::makeError(id, QStringLiteral("Таймаут отправки запроса"));

    QEventLoop loop;
    QTimer     timer;
    timer.setSingleShot(true);

    bool        gotResponse = false;
    QJsonObject response;

    auto tryConsume = [&]() -> bool
    {
        QJsonObject obj;
        while (Protocol::tryExtract(m_buffer, obj))
        {
            if (obj.value(QStringLiteral("id")).toVariant().toLongLong() == id)
            {
                response    = obj;
                gotResponse = true;
                return true;
            }
            // Ответы с другими id (теоретически невозможные при синхронном
            // протоколе) просто молча отбрасываем — не теряя кадр.
        }
        return false;
    };

    // Возможно данные уже накопились в буфере с прошлого вызова
    m_buffer.append(m_socket->readAll());
    if (tryConsume())
        return response;

    const QMetaObject::Connection readConn = QObject::connect(
        m_socket, &QTcpSocket::readyRead,
        &loop, [&]()
        {
            m_buffer.append(m_socket->readAll());
            if (tryConsume())
                loop.quit();
        });

    const QMetaObject::Connection discConn = QObject::connect(
        m_socket, &QTcpSocket::disconnected,
        &loop, &QEventLoop::quit);

    const QMetaObject::Connection timerConn = QObject::connect(
        &timer, &QTimer::timeout,
        &loop, &QEventLoop::quit);

    timer.start(REQUEST_TIMEOUT_MS);
    loop.exec();

    QObject::disconnect(readConn);
    QObject::disconnect(discConn);
    QObject::disconnect(timerConn);

    if (!gotResponse)
    {
        if (m_socket->state() != QAbstractSocket::ConnectedState)
            return Protocol::makeError(id, QStringLiteral("Соединение с сервером разорвано"));
        return Protocol::makeError(id, QStringLiteral("Таймаут ответа от сервера"));
    }

    return response;
}
