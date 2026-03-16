#pragma once

#include <QThread>
#include <QString>

class ConsoleHandler : public QThread
{
    Q_OBJECT

public:
    explicit ConsoleHandler(QObject* parent = nullptr);

    void stop();

signals:
    void commandReceived(const QString& command);

protected:
    void run() override;

private:
    bool m_running = true;
};
