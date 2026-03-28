#pragma once

#include <QObject>
#include <QString>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantList>
#include <QVariantMap>
#include <QRandomGenerator>
#include <QCryptographicHash>
#include <QDate>
#include <QDebug>
#include "Logger.h"

class DatabaseManager : public QObject
{
    Q_OBJECT

public:
    static DatabaseManager& instance();

    // Установить параметры из settings.ini (вызвать до connect)
    void setConnectionParams(const QString& driver, const QString& host, int port,
                             const QString& dbName, const QString& user, const QString& password);

    bool connect();
    void disconnect();
    bool isConnected() const;

    QSqlDatabase& database() { return m_db; }

    // API
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

    int loginUser(const QString& phone, const QString& password);

    QVariantMap getUserData(int userId);
    QVariantList getUserCards(int userId);
    double getTotalDebitBalance(int userId);
    int getUserAccountId(int userId);

    QVariantList getUserAccounts(int userId);
    double getAccountBalance(int accountId);

    double getDailyIncome(int userId);
    double getDailyExpense(int userId);

    QVariantList getTransactionHistory(int userId, int limit = 50, int offset = 0);

    int createAccount(int userId, const QString& accountType);
    QString generateCardNumber(const QString& brand);
    bool createCard(
        int accountId,
        const QString& cardNumber,
        const QString& cardHolderName,
        const QDate& expiryDate,
        const QString& cvcHash,
        const QString& pinHash,
        const QString& cardType,
        const QString& cardBrand
    );

    bool transferBetweenAccounts(int fromAccountId, int toAccountId, double amount);
    bool transferToUser(int fromAccountId, const QString& recipientPhone, double amount);
    int findAccountByPhone(const QString& phone, const QString& accountType = "debit");
    QString getAccountOwnerName(int accountId);
    QVariantList getUserDebitAccounts(int userId);

    bool blockCard(int cardId);
    bool freezeCard(int cardId);
    bool unfreezeCard(int cardId);
    QVariantMap getCardFullDetails(int cardId);
    QVariantList getCardTransactions(int accountId, int limit = 50, int offset = 0);

    bool isAccountFrozenOrBlocked(int accountId);

    bool topUpAccount(int accountId, double amount);

    bool setPrimaryAccount(int userId, int accountId);
    int  getPrimaryAccountId(int userId);

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
    bool m_connected = false;

    // Параметры подключения (настраиваются из конфига)
    QString m_driver   = "QPSQL";
    QString m_host     = "127.0.0.1";
    int     m_port     = 5433;
    QString m_dbName   = "plutusbank";
    QString m_user     = "postgres";
    QString m_password = "root";
};
