#include "NetworkClient.h"
#include "../shared/NetworkProtocol.h"

#include <QEventLoop>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDebug>

static constexpr int REQUEST_TIMEOUT_MS = 15000;

NetworkClient& NetworkClient::instance()
{
    static NetworkClient inst;
    return inst;
}

NetworkClient::NetworkClient()
{
    m_socket = new QTcpSocket(this);

    connect(m_socket, &QTcpSocket::disconnected, this, [this]()
    {
        qWarning() << "Соединение с сервером потеряно";
        emit connectionLost();
    });
}

NetworkClient::~NetworkClient()
{
    disconnectFromServer();
}

bool NetworkClient::connectToServer(const QString& host, quint16 port)
{
    m_lastHost = host;        // запоминаем
    m_lastPort = port;

    if (m_socket->state() == QAbstractSocket::ConnectedState)
        return true;

    m_socket->connectToHost(host, port);
    if (!m_socket->waitForConnected(5000))
    {
        qWarning() << "Не удалось подключиться к серверу:" << m_socket->errorString();
        emit error("Не удалось подключиться к серверу");
        return false;
    }

    qDebug() << "Подключено к серверу" << host << ":" << port;
    return true;
}

void NetworkClient::disconnectFromServer()
{
    if (m_socket->state() != QAbstractSocket::UnconnectedState)
    {
        m_socket->disconnectFromHost();
        if (m_socket->state() != QAbstractSocket::UnconnectedState)
            m_socket->waitForDisconnected(2000);
    }
}

bool NetworkClient::isConnected() const
{
    return m_socket && m_socket->state() == QAbstractSocket::ConnectedState;
}

// Главный метод: отправка запроса и ожидание ответа 
QJsonObject NetworkClient::sendRequest(const QString& method, const QJsonObject& params)
{
    // Ленивое переподключение, если сокет отвалился
    if (!isConnected())
    {
        if (m_lastPort == 0)
            return { {"success", false}, {"error", "Адрес сервера не задан"} };

        qDebug() << "Сокет не подключён, пробуем переподключиться...";
        if (!connectToServer(m_lastHost, m_lastPort))
            return { {"success", false}, {"error", "Нет подключения к серверу"} };
    }

    if (!isConnected())
    {
        return {{"success", false}, {"error", "Нет подключения к серверу"}};
    }

    qint64 id = m_nextId.fetch_add(1);
    QJsonObject request = Protocol::makeRequest(method, params, id);
    QByteArray frame = Protocol::pack(request);

    m_socket->write(frame);
    m_socket->flush();

    // Ожидаем ответ с нашим id через QEventLoop
    QJsonObject response;
    bool received = false;

    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);

    auto readConn = connect(m_socket, &QTcpSocket::readyRead, this, [&]()
    {
        m_buffer.append(m_socket->readAll());
        QJsonObject msg;
        while (Protocol::tryExtract(m_buffer, msg))
        {
            if (msg["id"].toInteger() == id)
            {
                response = msg;
                received = true;
                loop.quit();
                return;
            }
            // Другие сообщения (не наш id) — пока пропускаем
        }
    });

    auto timerConn = connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    auto discConn  = connect(m_socket, &QTcpSocket::disconnected, &loop, &QEventLoop::quit);

    timer.start(REQUEST_TIMEOUT_MS);
    loop.exec();

    disconnect(readConn);
    disconnect(timerConn);
    disconnect(discConn);

    if (!received)
    {
        qWarning() << "Таймаут запроса:" << method;
        return {{"success", false}, {"error", "Таймаут ответа от сервера"}};
    }

    return response;
}

// Auth
bool NetworkClient::registerUser(
    const QString& firstName, const QString& lastName,
    const QString& middleName, const QString& dateOfBirth,
    const QString& passportSeries, const QString& passportNumber,
    const QString& email, const QString& phone, const QString& password)
{
    QJsonObject params;
    params["firstName"]      = firstName;
    params["lastName"]       = lastName;
    params["middleName"]     = middleName;
    params["dateOfBirth"]    = dateOfBirth;
    params["passportSeries"] = passportSeries;
    params["passportNumber"] = passportNumber;
    params["email"]          = email;
    params["phone"]          = phone;
    params["password"]       = password;

    auto resp = sendRequest("registerUser", params);
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["ok"].toBool();
}

int NetworkClient::loginUser(const QString& phone, const QString& password, QVariantMap& outUserData)
{
    QJsonObject params;
    params["phone"]    = phone;
    params["password"] = password;

    auto resp = sendRequest("loginUser", params);
    if (!resp["success"].toBool()) return 0;

    QJsonObject result = resp["result"].toObject();
    int userId = result["userId"].toInt();
    if (userId > 0)
        outUserData = result["userData"].toObject().toVariantMap();

    return userId;
}

// User data
QVariantMap NetworkClient::getUserData(int userId)
{
    auto resp = sendRequest("getUserData", {{"userId", userId}});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject().toVariantMap();
}

QVariantList NetworkClient::getUserCards(int userId)
{
    auto resp = sendRequest("getUserCards", {{"userId", userId}});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["cards"].toArray().toVariantList();
}

double NetworkClient::getTotalDebitBalance(int userId)
{
    auto resp = sendRequest("getTotalDebitBalance", {{"userId", userId}});
    if (!resp["success"].toBool()) return 0;
    return resp["result"].toObject()["balance"].toDouble();
}

int NetworkClient::getUserAccountId(int userId)
{
    auto resp = sendRequest("getUserAccountId", {{"userId", userId}});
    if (!resp["success"].toBool()) return -1;
    return resp["result"].toObject()["accountId"].toInt();
}

QVariantList NetworkClient::getUserAccounts(int userId)
{
    auto resp = sendRequest("getUserAccounts", {{"userId", userId}});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["accounts"].toArray().toVariantList();
}

double NetworkClient::getAccountBalance(int accountId)
{
    auto resp = sendRequest("getAccountBalance", {{"accountId", accountId}});
    if (!resp["success"].toBool()) return 0;
    return resp["result"].toObject()["balance"].toDouble();
}

double NetworkClient::getDailyIncome(int userId)
{
    auto resp = sendRequest("getDailyIncome", {{"userId", userId}});
    if (!resp["success"].toBool()) return 0;
    return resp["result"].toObject()["income"].toDouble();
}

double NetworkClient::getDailyExpense(int userId)
{
    auto resp = sendRequest("getDailyExpense", {{"userId", userId}});
    if (!resp["success"].toBool()) return 0;
    return resp["result"].toObject()["expense"].toDouble();
}

QVariantList NetworkClient::getTransactionHistory(int userId, int limit, int offset)
{
    QJsonObject params;
    params["userId"] = userId;
    params["limit"]  = limit;
    params["offset"] = offset;

    auto resp = sendRequest("getTransactionHistory", params);
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["history"].toArray().toVariantList();
}

// Cards
int NetworkClient::createAccount(int userId, const QString& accountType)
{
    QJsonObject params;
    params["userId"]      = userId;
    params["accountType"] = accountType;

    auto resp = sendRequest("createAccount", params);
    if (!resp["success"].toBool()) return -1;
    return resp["result"].toObject()["accountId"].toInt();
}

QString NetworkClient::generateCardNumber(const QString& brand)
{
    auto resp = sendRequest("generateCardNumber", {{"brand", brand}});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["cardNumber"].toString();
}

bool NetworkClient::createCard(int accountId, const QString& cardNumber,
                               const QString& cardHolderName, const QDate& expiryDate,
                               const QString& cvcHash, const QString& pinHash,
                               const QString& cardType, const QString& cardBrand)
{
    QJsonObject params;
    params["accountId"]      = accountId;
    params["cardNumber"]     = cardNumber;
    params["cardHolderName"] = cardHolderName;
    params["expiryDate"]     = expiryDate.toString("yyyy-MM-dd");
    params["cvcHash"]        = cvcHash;
    params["pinHash"]        = pinHash;
    params["cardType"]       = cardType;
    params["cardBrand"]      = cardBrand;

    auto resp = sendRequest("createCard", params);
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["ok"].toBool();
}

bool NetworkClient::blockCard(int cardId)
{
    auto resp = sendRequest("blockCard", {{"cardId", cardId}});
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["ok"].toBool();
}

bool NetworkClient::freezeCard(int cardId)
{
    auto resp = sendRequest("freezeCard", {{"cardId", cardId}});
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["ok"].toBool();
}

bool NetworkClient::unfreezeCard(int cardId)
{
    auto resp = sendRequest("unfreezeCard", {{"cardId", cardId}});
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["ok"].toBool();
}

QVariantMap NetworkClient::getCardFullDetails(int cardId)
{
    auto resp = sendRequest("getCardFullDetails", {{"cardId", cardId}});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject().toVariantMap();
}

QVariantList NetworkClient::getCardTransactions(int accountId, int limit, int offset)
{
    QJsonObject params;
    params["accountId"] = accountId;
    params["limit"]     = limit;
    params["offset"]    = offset;

    auto resp = sendRequest("getCardTransactions", params);
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["transactions"].toArray().toVariantList();
}

bool NetworkClient::isAccountFrozenOrBlocked(int accountId)
{
    auto resp = sendRequest("isAccountFrozenOrBlocked", {{"accountId", accountId}});
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["frozen"].toBool();
}

// Transfers
bool NetworkClient::transferBetweenAccounts(int fromAccountId, int toAccountId, double amount)
{
    QJsonObject params;
    params["fromAccountId"] = fromAccountId;
    params["toAccountId"]   = toAccountId;
    params["amount"]        = amount;

    auto resp = sendRequest("transferBetweenAccounts", params);
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["ok"].toBool();
}

bool NetworkClient::transferToUser(int fromAccountId, const QString& recipientPhone, double amount)
{
    QJsonObject params;
    params["fromAccountId"]  = fromAccountId;
    params["recipientPhone"] = recipientPhone;
    params["amount"]         = amount;

    auto resp = sendRequest("transferToUser", params);
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["ok"].toBool();
}

int NetworkClient::findAccountByPhone(const QString& phone, const QString& accountType)
{
    QJsonObject params;
    params["phone"]       = phone;
    params["accountType"] = accountType;

    auto resp = sendRequest("findAccountByPhone", params);
    if (!resp["success"].toBool()) return -1;
    return resp["result"].toObject()["accountId"].toInt();
}

QString NetworkClient::getAccountOwnerName(int accountId)
{
    auto resp = sendRequest("getAccountOwnerName", {{"accountId", accountId}});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["name"].toString();
}

QVariantList NetworkClient::getUserDebitAccounts(int userId)
{
    auto resp = sendRequest("getUserDebitAccounts", {{"userId", userId}});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["accounts"].toArray().toVariantList();
}

// Top-up
bool NetworkClient::topUpAccount(int accountId, double amount)
{
    QJsonObject params;
    params["accountId"] = accountId;
    params["amount"]    = amount;

    auto resp = sendRequest("topUpAccount", params);
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["ok"].toBool();
}

// Primary account
bool NetworkClient::setPrimaryAccount(int userId, int accountId)
{
    QJsonObject params;
    params["userId"]    = userId;
    params["accountId"] = accountId;

    auto resp = sendRequest("setPrimaryAccount", params);
    if (!resp["success"].toBool()) return false;
    return resp["result"].toObject()["ok"].toBool();
}

int NetworkClient::getPrimaryAccountId(int userId)
{
    auto resp = sendRequest("getPrimaryAccountId", {{"userId", userId}});
    if (!resp["success"].toBool()) return -1;
    return resp["result"].toObject()["accountId"].toInt();
}

// Loans
QVariantList NetworkClient::loadLoanProducts()
{
    auto resp = sendRequest("loadLoanProducts", {});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["products"].toArray().toVariantList();
}

NetworkClient::LoanResult NetworkClient::applyForLoan(
    int userId, int productId, double amount, int months, int targetAccountId)
{
    QJsonObject params;
    params["userId"]          = userId;
    params["productId"]       = productId;
    params["amount"]          = amount;
    params["months"]          = months;
    params["targetAccountId"] = targetAccountId;

    auto resp = sendRequest("applyForLoan", params);
    if (!resp["success"].toBool())
        return {false, 0, resp["error"].toString()};

    QJsonObject result = resp["result"].toObject();
    if (!result["ok"].toBool())
        return {false, 0, result["error"].toString()};

    return {true, result["loanId"].toInt(), {}};
}

QVariantList NetworkClient::loadUserLoans(int userId)
{
    auto resp = sendRequest("loadUserLoans", {{"userId", userId}});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["loans"].toArray().toVariantList();
}

NetworkClient::ClosedLoansResult NetworkClient::loadClosedLoans(int userId)
{
    auto resp = sendRequest("loadClosedLoans", {{"userId", userId}});
    if (!resp["success"].toBool()) return {{}, 0};
    QJsonObject result = resp["result"].toObject();
    return {
        result["loans"].toArray().toVariantList(),
        result["totalPaidAll"].toDouble()
    };
}

QVariantList NetworkClient::loadLoanSchedule(int loanId)
{
    auto resp = sendRequest("loadLoanSchedule", {{"loanId", loanId}});
    if (!resp["success"].toBool()) return {};
    return resp["result"].toObject()["schedule"].toArray().toVariantList();
}

NetworkClient::PaymentResult NetworkClient::makeLoanPayment(int userId, int loanId)
{
    QJsonObject params;
    params["userId"] = userId;
    params["loanId"] = loanId;

    auto resp = sendRequest("makeLoanPayment", params);
    if (!resp["success"].toBool())
        return {false, false, 0, resp["error"].toString()};

    QJsonObject result = resp["result"].toObject();
    if (!result["ok"].toBool())
        return {false, false, 0, result["error"].toString()};

    return {true, result["closed"].toBool(), result["paymentAmount"].toDouble(), {}};
}
