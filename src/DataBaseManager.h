#pragma once

#include <QObject>
#include <QString>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariantList>
#include <QVariantMap>
#include <QRandomGenerator>

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

    int loginUser(const QString& phone, const QString& password);

    QVariantMap getUserData(int userId);                    // Получить данные пользователя
    QVariantList getUserCards(int userId);                  // Получить карты пользователя
    double getTotalDebitBalance(int userId);                // Общий баланс дебетовых карт
    int getUserAccountId(int userId);                       // Получить account_id пользователя

    QVariantList getUserAccounts(int userId);
    double getAccountBalance(int accountId);

    int createAccount(int userId, const QString& accountType);  // Создать счёт
    QString generateCardNumber(const QString& brand);           // Генерировать номер
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