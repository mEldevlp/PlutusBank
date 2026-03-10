#include "ClientSession.h"
#include "RequestHandler.h"
#include "Logger.h"
#include "../shared/NetworkProtocol.h"

#include <QJsonObject>

ClientSession::ClientSession(qintptr socketDescriptor, RequestHandler* handler, QObject* parent)
    : QObject(parent)
    , m_handler(handler)
{
    m_socket = new QTcpSocket(this);

    if (!m_socket->setSocketDescriptor(socketDescriptor))
    {
        Logger::instance().error("Не удалось установить дескриптор сокета");
        deleteLater();
        return;
    }

    m_tag = QString("%1:%2")
                .arg(m_socket->peerAddress().toString())
                .arg(m_socket->peerPort());

    connect(m_socket, &QTcpSocket::readyRead,    this, &ClientSession::onReadyRead);
    connect(m_socket, &QTcpSocket::disconnected,  this, &ClientSession::onDisconnected);

    Logger::instance().info("Клиент подключён", m_tag);
}

ClientSession::~ClientSession()
{
    Logger::instance().info("Сессия удалена", m_tag);
}

bool ClientSession::isConnected() const
{
    return m_socket && m_socket->state() == QAbstractSocket::ConnectedState;
}

void ClientSession::disconnectClient()
{
    if (m_socket)
        m_socket->disconnectFromHost();
}

void ClientSession::onReadyRead()
{
    m_buffer.append(m_socket->readAll());

    QJsonObject msg;
    while (Protocol::tryExtract(m_buffer, msg))
    {
        processMessage(msg);
    }
}

void ClientSession::onDisconnected()
{
    Logger::instance().info("Клиент отключился", m_tag);
    emit disconnected(this);
    deleteLater();
}

void ClientSession::processMessage(const QJsonObject& msg)
{
    QString method = msg["method"].toString();
    Logger::instance().debug("Запрос: " + method, m_tag);

    QJsonObject response = m_handler->handle(msg, m_tag);

    // Запоминаем userId при логине
    if (method == "loginUser" && response["success"].toBool())
    {
        QJsonObject result = response["result"].toObject();
        int uid = result["userId"].toInt();
        if (uid > 0)
            m_userId = uid;
    }

    send(response);
}

void ClientSession::send(const QJsonObject& json)
{
    if (!m_socket || m_socket->state() != QAbstractSocket::ConnectedState)
        return;

    QByteArray frame = Protocol::pack(json);
    m_socket->write(frame);
    m_socket->flush();
}
