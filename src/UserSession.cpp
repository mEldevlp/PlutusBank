#include "UserSession.h"
#include "DatabaseManager.h"
#include <QDebug>

UserSession& UserSession::instance()
{
    static UserSession instance;
    return instance;
}

UserSession::UserSession()
    : m_userId(0)
    , m_totalBalance(0.0)
{
}

QString UserSession::fullName() const
{
    if (m_middleName.isEmpty()) {
        return m_lastName + " " + m_firstName;
    }
    return m_lastName + " " + m_firstName + " " + m_middleName;
}

QString UserSession::shortName() const
{
    if (m_firstName.isEmpty() || m_lastName.isEmpty()) {
        return "Пользователь";
    }

    // "Кондрашов Д."
    QString initial = m_firstName.left(1).toUpper() + ".";
    return m_lastName + " " + initial;
}

void UserSession::setUserData(int userId, const QString& firstName, const QString& lastName,
    const QString& middleName, const QString& email, const QString& phone)
{
    m_userId = userId;
    m_firstName = firstName;
    m_lastName = lastName;
    m_middleName = middleName;
    m_email = email;
    m_phone = phone;

    qDebug() << u"✓ Данные пользователя установлены:" << shortName();
    emit userChanged();

    // Загружаем карты и баланс
    loadCards();
    refreshBalance();
}

void UserSession::setCards(const QVariantList& cards)
{
    m_cards = cards;
    qDebug() << u"✓ Карты загружены:" << m_cards.size();
    emit cardsChanged();
}

void UserSession::setTotalBalance(double balance)
{
    m_totalBalance = balance;
    qDebug() << u"✓ Баланс обновлён:" << m_totalBalance;
    emit balanceChanged();
}

void UserSession::loadUserData()
{
    if (m_userId <= 0) {
        qWarning() << u"Невозможно загрузить данные: пользователь не авторизован";
        return;
    }

    DatabaseManager& db = DatabaseManager::instance();

    // Загружаем данные пользователя
    auto userData = db.getUserData(m_userId);
    if (!userData.isEmpty()) {
        m_firstName = userData["first_name"].toString();
        m_lastName = userData["last_name"].toString();
        m_middleName = userData["middle_name"].toString();
        m_email = userData["email"].toString();
        m_phone = userData["phone"].toString();
        emit userChanged();
    }
}

void UserSession::loadCards()
{
    if (m_userId <= 0) {
        qWarning() << u"Невозможно загрузить карты: пользователь не авторизован";
        return;
    }

    DatabaseManager& db = DatabaseManager::instance();
    m_cards = db.getUserCards(m_userId);
    qDebug() << u"Загружено карт:" << m_cards.size();
    emit cardsChanged();
}

void UserSession::refreshBalance()
{
    if (m_userId <= 0) {
        qWarning() << u"Невозможно обновить баланс: пользователь не авторизован";
        return;
    }

    DatabaseManager& db = DatabaseManager::instance();
    m_totalBalance = db.getTotalDebitBalance(m_userId);
    qDebug() << u"Общий баланс по дебетовым картам:" << m_totalBalance;
    emit balanceChanged();
}

void UserSession::logout()
{
    m_userId = 0;
    m_firstName.clear();
    m_lastName.clear();
    m_middleName.clear();
    m_email.clear();
    m_phone.clear();
    m_totalBalance = 0.0;
    m_cards.clear();

    emit userChanged();
    emit balanceChanged();
    emit cardsChanged();
    emit loggedOut();

    qDebug() << u"✓ Пользователь вышел из системы";
}