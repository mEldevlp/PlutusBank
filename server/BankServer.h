#pragma once

#include <QTcpServer>
#include <QList>

class ClientSession;
class RequestHandler;

class BankServer : public QTcpServer
{
    Q_OBJECT

public:
    explicit BankServer(QObject* parent = nullptr);
    ~BankServer();

    bool startListening(const QString& host, quint16 port);
    void stop();

    int clientCount() const;
    QList<ClientSession*> clients() const { return m_clients; }

    // Для консольных команд
    void kickAll();
    void kickClient(const QString& tag);

protected:
    void incomingConnection(qintptr socketDescriptor) override;

private slots:
    void onClientDisconnected(ClientSession* session);

private:
    RequestHandler*       m_handler = nullptr;
    QList<ClientSession*> m_clients;
};
