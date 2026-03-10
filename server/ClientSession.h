#pragma once

#include <QObject>
#include <QTcpSocket>
#include <QByteArray>
#include <QString>

class RequestHandler;

class ClientSession : public QObject
{
    Q_OBJECT

public:
    explicit ClientSession(qintptr socketDescriptor, RequestHandler* handler, QObject* parent = nullptr);
    ~ClientSession();

    QString tag() const { return m_tag; }
    int     userId() const { return m_userId; }
    void    setUserId(int id) { m_userId = id; }
    bool    isConnected() const;

    void    disconnectClient();

signals:
    void    disconnected(ClientSession* session);

private slots:
    void    onReadyRead();
    void    onDisconnected();

private:
    void    processMessage(const QJsonObject& msg);
    void    send(const QJsonObject& json);

    QTcpSocket*      m_socket  = nullptr;
    RequestHandler*  m_handler = nullptr;
    QByteArray       m_buffer;
    QString          m_tag;      // "IP:port" для логирования
    int              m_userId = 0;
};
