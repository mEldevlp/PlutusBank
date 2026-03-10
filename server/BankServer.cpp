#include "BankServer.h"
#include "ClientSession.h"
#include "RequestHandler.h"
#include "Logger.h"

#include <QHostAddress>

BankServer::BankServer(QObject* parent)
    : QTcpServer(parent)
    , m_handler(new RequestHandler(this))
{
}

BankServer::~BankServer()
{
    stop();
}

bool BankServer::startListening(const QString& host, quint16 port)
{
    QHostAddress address;
    if (host == "0.0.0.0")
        address = QHostAddress::Any;
    else
        address = QHostAddress(host);

    if (!listen(address, port))
    {
        Logger::instance().error(
            QString("Не удалось запустить сервер на %1:%2 — %3")
                .arg(host).arg(port).arg(errorString()));
        return false;
    }

    Logger::instance().info(
        QString("Сервер запущен на %1:%2").arg(host).arg(port));
    return true;
}

void BankServer::stop()
{
    Logger::instance().info("Остановка сервера...");
    close();

    for (auto* client : m_clients)
        client->disconnectClient();

    m_clients.clear();
}

int BankServer::clientCount() const
{
    return m_clients.size();
}

void BankServer::kickAll()
{
    Logger::instance().info("Отключение всех клиентов...");
    for (auto* client : m_clients)
        client->disconnectClient();
}

void BankServer::kickClient(const QString& tag)
{
    for (auto* client : m_clients)
    {
        if (client->tag() == tag)
        {
            Logger::instance().info("Принудительное отключение клиента", tag);
            client->disconnectClient();
            return;
        }
    }
    Logger::instance().warning("Клиент не найден: " + tag);
}

void BankServer::incomingConnection(qintptr socketDescriptor)
{
    auto* session = new ClientSession(socketDescriptor, m_handler, this);

    connect(session, &ClientSession::disconnected,
            this,    &BankServer::onClientDisconnected);

    m_clients.append(session);
}

void BankServer::onClientDisconnected(ClientSession* session)
{
    m_clients.removeOne(session);
    Logger::instance().info(
        QString("Клиентов онлайн: %1").arg(m_clients.size()));
}
