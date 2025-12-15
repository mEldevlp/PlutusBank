#include "CardController.h"
#include "UserSession.h"
#include <QCryptographicHash>
#include <QRandomGenerator>
#include <QDateTime>
#include <QDebug>

CardController::CardController(QObject* parent)
    : QObject(parent)
    , m_db(DatabaseManager::instance())
{}

QString CardController::generateCVC()
{
    int cvc = QRandomGenerator::global()->bounded(100, 1000);  // 100-999
    return QString::number(cvc);
}

QString CardController::generatePIN()
{
    int pin = QRandomGenerator::global()->bounded(1000, 10000);  // 1000-9999
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

    // Шаг 1: Создаём новый счёт
    emit creationProgress("Создание нового счёта...");

    int accountId = m_db.createAccount(userId, cardType);
    if (accountId <= 0) {
        emit cardCreationFailed("Не удалось создать счёт");
        return;
    }

    qDebug() << u"✓ Счёт создан. Account ID:" << accountId;

    // Шаг 2: Генерируем данные карты
    emit creationProgress("Генерация номера карты...");

    QString cardNumber = m_db.generateCardNumber(cardBrand);
    if (cardNumber.isEmpty()) {
        emit cardCreationFailed("Не удалось сгенерировать номер карты");
        return;
    }

    qDebug() << u"✓ Номер карты сгенерирован:" << cardNumber;

    // Генерируем CVC и PIN
    QString cvc = generateCVC();
    QString pin = generatePIN();

    qDebug() << u"✓ CVC:" << cvc << u"PIN:" << pin;

    // Шаг 3: Вычисляем дату истечения (+5 лет)
    QDate expiryDate = QDate::currentDate().addYears(5);

    // Шаг 4: Формируем имя держателя карты (латиницей)
    QString cardHolderName = session.lastName().toUpper() + " " +
        session.firstName().toUpper();

    // Шаг 5: Создаём карту в БД
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

    qDebug() << u"✓ Карта создана успешно!";

    // Шаг 6: Обновляем данные пользователя
    session.loadCards();
    session.refreshBalance();

    // Шаг 7: Возвращаем данные карты в QML
    QVariantMap cardData;
    cardData["cardNumber"] = cardNumber;
    cardData["cardHolder"] = cardHolderName;
    cardData["expiryDate"] = expiryDate.toString("MM/yy");
    cardData["cvc"] = cvc;  // НЕ хешированный для показа пользователю
    cardData["pin"] = pin;  // НЕ хешированный для показа пользователю
    cardData["cardType"] = cardType;
    cardData["cardBrand"] = cardBrand;

    emit cardCreated(cardData);
}