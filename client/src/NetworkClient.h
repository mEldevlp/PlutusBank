#pragma once

#include <QObject>
#include <QTcpSocket>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantList>
#include <QVariantMap>
#include <QByteArray>
#include <QDate>
#include <atomic>

/*
    NetworkClient — сетевой клиент для взаимодействия с PlutusBankServer.
    Заменяет прямое обращение к DatabaseManager.
    API максимально повторяет интерфейс DatabaseManager.

    Все вызовы синхронные (блокируют через QEventLoop),
    чтобы контроллеры менялись минимально.
*/

class NetworkClient : public QObject
{
    Q_OBJECT

public:
    static NetworkClient& instance();

    bool connectToServer(const QString& host, quint16 port);
    void disconnectFromServer();
    bool isConnected() const;

    // ---- Auth ----
    bool registerUser(
        const QString& firstName, const QString& lastName,
        const QString& middleName, const QString& dateOfBirth,
        const QString& passportSeries, const QString& passportNumber,
        const QString& email, const QString& phone, const QString& password
    );

    // Возвращает userId > 0 при успехе, 0 при ошибке. userData заполняется.
    int loginUser(const QString& phone, const QString& password, QVariantMap& outUserData);

    // ---- User data ----
    QVariantMap  getUserData(int userId);
    QVariantList getUserCards(int userId);
    double       getTotalDebitBalance(int userId);
    int          getUserAccountId(int userId);
    QVariantList getUserAccounts(int userId);
    double       getAccountBalance(int accountId);
    double       getDailyIncome(int userId);
    double       getDailyExpense(int userId);
    QVariantList getTransactionHistory(int userId, int limit = 50, int offset = 0);

    // ---- Cards ----
    int     createAccount(int userId, const QString& accountType);
    QString generateCardNumber(const QString& brand);
    bool    createCard(int accountId, const QString& cardNumber,
                       const QString& cardHolderName, const QDate& expiryDate,
                       const QString& cvcHash, const QString& pinHash,
                       const QString& cardType, const QString& cardBrand);

    bool         blockCard(int cardId);
    bool         freezeCard(int cardId);
    bool         unfreezeCard(int cardId);
    QVariantMap  getCardFullDetails(int cardId);
    QVariantList getCardTransactions(int accountId, int limit = 50, int offset = 0);
    bool         isAccountFrozenOrBlocked(int accountId);

    // ---- Transfers ----
    bool    transferBetweenAccounts(int fromAccountId, int toAccountId, double amount);
    bool    transferToUser(int fromAccountId, const QString& recipientPhone, double amount);
    int     findAccountByPhone(const QString& phone, const QString& accountType = "debit");
    QString getAccountOwnerName(int accountId);
    QVariantList getUserDebitAccounts(int userId);

    // ---- Top-up ----
    bool topUpAccount(int accountId, double amount);

    // ---- Primary account ----
    bool setPrimaryAccount(int userId, int accountId);
    int  getPrimaryAccountId(int userId);

    // ---- Loans ----
    QVariantList loadLoanProducts();

    struct LoanResult { bool ok; int loanId; QString error; };
    LoanResult applyForLoan(int userId, int productId, double amount, int months, int targetAccountId);

    QVariantList loadUserLoans(int userId);

    struct ClosedLoansResult { QVariantList loans; double totalPaidAll; };
    ClosedLoansResult loadClosedLoans(int userId);

    QVariantList loadLoanSchedule(int loanId);

    struct PaymentResult { bool ok; bool closed; double paymentAmount; QString error; };
    PaymentResult makeLoanPayment(int userId, int loanId);

    // ---- Crypto ----
    QVariantList getCryptocurrencies();
    QVariantList getUserWallets(int userId);

    struct CryptoBuyResult { bool ok; QString error; double coinAmount; double rubAmount; double price; };
    struct CryptoSellResult { bool ok; QString error; double coinAmount; double rubAmount; double price; };
    struct CryptoTransferResult { bool ok; QString error; double coinAmount; QString recipientName; };

    CryptoBuyResult  buyCrypto(int userId, int currencyId, double rubAmount, int cardId);
    CryptoSellResult sellCrypto(int userId, int currencyId, double coinAmount, int cardId);
    CryptoTransferResult transferCrypto(int userId, int currencyId, double coinAmount, const QString& recipientAddress);

    QVariantList getCryptoHistory(int userId, int limit = 50, int offset = 0);

signals:
    void connectionLost();
    void error(const QString& message);

private:
    NetworkClient();
    ~NetworkClient();
    NetworkClient(const NetworkClient&) = delete;
    NetworkClient& operator=(const NetworkClient&) = delete;

    // Отправить запрос и дождаться ответа (синхронно, через QEventLoop)
    QJsonObject sendRequest(const QString& method, const QJsonObject& params);

    QTcpSocket*      m_socket  = nullptr;
    QByteArray       m_buffer;
    std::atomic<qint64> m_nextId{1};

    QString m_lastHost;
    quint16 m_lastPort = 0;
};
