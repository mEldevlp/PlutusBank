#include "CardController.h"
#include "UserSession.h"
#include <QCryptographicHash>
#include <QRandomGenerator>
#include <QDateTime>
#include <QDebug>
#include <QGuiApplication>
#include <QClipboard>

CardController::CardController(QObject* parent)
    : QObject(parent)
    , m_db(DatabaseManager::instance())
{
}

QString CardController::generateCVC()
{
    int cvc = QRandomGenerator::global()->bounded(100, 1000);
    return QString::number(cvc);
}

QString CardController::generatePIN()
{
    int pin = QRandomGenerator::global()->bounded(1000, 10000);
    return QString::number(pin);
}

QString CardController::hashData(const QString& data)
{
    return QString(QCryptographicHash::hash(
        data.toUtf8(),
        QCryptographicHash::Sha256
    ).toHex());
}

void CardController::createCard(const QString& cardType, const QString& cardBrand)
{
    qDebug() << u"Создание карты:" << cardType << cardBrand;

    UserSession& session = UserSession::instance();
    int userId = session.userId();

    if (userId <= 0) {
        emit cardCreationFailed("Пользователь не авторизован");
        return;
    }

    emit creationProgress("Создание нового счёта...");

    int accountId = m_db.createAccount(userId, cardType);
    if (accountId <= 0) {
        emit cardCreationFailed("Не удалось создать счёт");
        return;
    }

    emit creationProgress("Генерация номера карты...");

    QString cardNumber = m_db.generateCardNumber(cardBrand);
    if (cardNumber.isEmpty()) {
        emit cardCreationFailed("Не удалось сгенерировать номер карты");
        return;
    }

    QString cvc = generateCVC();
    QString pin = generatePIN();

    QDate expiryDate = QDate::currentDate().addYears(5);

    QString cardHolderName = session.lastName().toUpper() + " " +
        session.firstName().toUpper();

    emit creationProgress("Сохранение карты...");

    bool success = m_db.createCard(
        accountId,
        cardNumber,
        cardHolderName,
        expiryDate,
        hashData(cvc),
        hashData(pin),
        cardType,
        cardBrand
    );

    if (!success) {
        emit cardCreationFailed("Не удалось создать карту в базе данных");
        return;
    }

    session.loadCards();
    session.refreshBalance();

    QVariantMap cardData;
    cardData["cardNumber"] = cardNumber;
    cardData["cardHolder"] = cardHolderName;
    cardData["expiryDate"] = expiryDate.toString("MM/yy");
    cardData["cvc"] = cvc;
    cardData["pin"] = pin;
    cardData["cardType"] = cardType;
    cardData["cardBrand"] = cardBrand;

    emit cardCreated(cardData);
}

void CardController::blockCard(int cardId)
{
    if (m_db.blockCard(cardId)) {
        UserSession::instance().loadCards();
        emit cardBlocked();
    }
    else {
        emit cardBlockFailed("Не удалось заблокировать карту");
    }
}

void CardController::freezeCard(int cardId)
{
    if (m_db.freezeCard(cardId)) {
        // После toggle читаем актуальное состояние
        auto details = m_db.getCardFullDetails(cardId);
        bool isActive = details.value("is_active").toBool();
        UserSession::instance().loadCards();
        emit cardFrozen(!isActive);  // isFrozen = !is_active
    }
    else {
        emit cardFreezeFailed("Не удалось заморозить карту");
    }
}

QVariantMap CardController::getCardDetails(int cardId)
{
    return m_db.getCardFullDetails(cardId);
}

void CardController::loadCardTransactions(int accountId)
{
    m_isLoading = true;
    emit loadingChanged();

    m_cardTransactions = m_db.getCardTransactions(accountId, 50, 0);

    m_isLoading = false;
    emit loadingChanged();
    emit cardTransactionsChanged();
}

void CardController::copyToClipboard(const QString& text)
{
    QClipboard* clipboard = QGuiApplication::clipboard();
    if (clipboard)
        clipboard->setText(text);
}

bool CardController::topUpAccounts(const QVariantList& accountIds, double amount)
{
    if (accountIds.isEmpty()) {
        emit topUpFailed("Не выбрано ни одной карты");
        return false;
    }
    if (amount <= 0) {
        emit topUpFailed("Сумма должна быть больше нуля");
        return false;
    }

    int successCount = 0;
    int frozenCount = 0;
    for (const QVariant& v : accountIds) {
        int accId = v.toInt();

        // Проверка заморозки/блокировки
        if (m_db.isAccountFrozenOrBlocked(accId)) {
            ++frozenCount;
            continue;
        }

        if (m_db.topUpAccount(accId, amount)) {
            ++successCount;
        }
    }

    if (successCount == 0) {
        if (frozenCount > 0) {
            emit topUpFailed("Выбранные карты заморожены или заблокированы");
        }
        else {
            emit topUpFailed("Не удалось пополнить ни одну карту");
        }
        return false;
    }

    UserSession::instance().loadCards();
    UserSession::instance().refreshBalance();
    emit topUpSuccess(amount * successCount, successCount);
    return true;
}