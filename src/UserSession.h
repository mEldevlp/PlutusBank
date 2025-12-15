#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

class UserSession : public QObject
{
    Q_OBJECT

        Q_PROPERTY(int userId READ userId NOTIFY userChanged)
        Q_PROPERTY(QString firstName READ firstName NOTIFY userChanged)
        Q_PROPERTY(QString lastName READ lastName NOTIFY userChanged)
        Q_PROPERTY(QString middleName READ middleName NOTIFY userChanged)
        Q_PROPERTY(QString email READ email NOTIFY userChanged)
        Q_PROPERTY(QString phone READ phone NOTIFY userChanged)
        Q_PROPERTY(QString fullName READ fullName NOTIFY userChanged)
        Q_PROPERTY(QString shortName READ shortName NOTIFY userChanged)  // "Кондрашов Д."
        Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY userChanged)
        Q_PROPERTY(double totalBalance READ totalBalance NOTIFY balanceChanged)
        Q_PROPERTY(QVariantList cards READ cards NOTIFY cardsChanged)
        Q_PROPERTY(bool hasCards READ hasCards NOTIFY cardsChanged)

public:
    static UserSession& instance();

    // Getters
    int userId() const { return m_userId; }
    QString firstName() const { return m_firstName; }
    QString lastName() const { return m_lastName; }
    QString middleName() const { return m_middleName; }
    QString email() const { return m_email; }
    QString phone() const { return m_phone; }
    QString fullName() const;
    QString shortName() const;  // "Кондрашов Д."
    bool isLoggedIn() const { return m_userId > 0; }
    double totalBalance() const { return m_totalBalance; }
    QVariantList cards() const { return m_cards; }
    bool hasCards() const { return !m_cards.isEmpty(); }

    // Setters
    void setUserData(int userId, const QString& firstName, const QString& lastName,
        const QString& middleName, const QString& email, const QString& phone);
    void setCards(const QVariantList& cards);
    void setTotalBalance(double balance);

    Q_INVOKABLE void loadUserData();      // Загрузить данные пользователя
    Q_INVOKABLE void loadCards();         // Загрузить карты
    Q_INVOKABLE void refreshBalance();    // Обновить баланс
    Q_INVOKABLE void logout();            // Выход

signals:
    void userChanged();
    void balanceChanged();
    void cardsChanged();
    void loggedOut();

private:
    UserSession();
    ~UserSession() = default;
    UserSession(const UserSession&) = delete;
    UserSession& operator=(const UserSession&) = delete;

    int m_userId;
    QString m_firstName;
    QString m_lastName;
    QString m_middleName;
    QString m_email;
    QString m_phone;
    double m_totalBalance;
    QVariantList m_cards;
};