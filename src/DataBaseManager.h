#pragma once

#include <QObject>
#include <QString>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantList>

class DatabaseManager : public QObject
{
    Q_OBJECT

public:
    static DatabaseManager& instance();

    bool connect();
    void disconnect();
    bool isConnected() const;

    // Регистрация с полными данными
    bool registerUser(
        const QString& firstName,
        const QString& lastName,
        const QString& middleName,
        const QString& dateOfBirth,
        const QString& passportSeries,
        const QString& passportNumber,
        const QString& email,
        const QString& phone,
        const QString& password
    );

    bool loginUser(const QString& phone, const QString& password);

    QVariantList getUserAccounts(int userId);
    double getAccountBalance(int accountId);

signals:
    void connected();
    void disconnected();
    void error(const QString& message);

private:
    DatabaseManager();
    ~DatabaseManager();
    DatabaseManager(const DatabaseManager&) = delete;
    DatabaseManager& operator=(const DatabaseManager&) = delete;

    QString hashPassword(const QString& password);
    bool verifyPassword(const QString& password, const QString& hash);

    QSqlDatabase m_db;
    bool m_connected;
};