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

    // Доходы/расходы за сутки
    double getDailyIncome(int userId);
    double getDailyExpense(int userId);

    // История транзакций
    QVariantList getTransactionHistory(int userId, int limit = 50, int offset = 0);

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

    // Переводы
    bool transferBetweenAccounts(int fromAccountId, int toAccountId, double amount);
    bool transferToUser(int fromAccountId, const QString& recipientPhone, double amount);
    int findAccountByPhone(const QString& phone, const QString& accountType = "debit");
    QString getAccountOwnerName(int accountId);
    QVariantList getUserDebitAccounts(int userId);  // Только дебетовые для переводов

    // Операции с картами
    bool blockCard(int cardId);
    bool freezeCard(int cardId);
    bool unfreezeCard(int cardId);
    QVariantMap getCardFullDetails(int cardId);
    QVariantList getCardTransactions(int accountId, int limit = 50, int offset = 0);

    bool isAccountFrozenOrBlocked(int accountId);

    // Пополнение
    bool topUpAccount(int accountId, double amount);

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