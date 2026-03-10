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
        Q_PROPERTY(QString shortName READ shortName NOTIFY userChanged)
        Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY userChanged)
        Q_PROPERTY(double totalBalance READ totalBalance NOTIFY balanceChanged)
        Q_PROPERTY(double dailyIncome READ dailyIncome NOTIFY balanceChanged)
        Q_PROPERTY(double dailyExpense READ dailyExpense NOTIFY balanceChanged)
        Q_PROPERTY(QVariantList cards READ cards NOTIFY cardsChanged)
        Q_PROPERTY(bool hasCards READ hasCards NOTIFY cardsChanged)
        Q_PROPERTY(bool isRefreshing READ isRefreshing NOTIFY refreshingChanged)
        Q_PROPERTY(QString passportSeries READ passportSeries NOTIFY userChanged)
        Q_PROPERTY(QString passportNumber READ passportNumber NOTIFY userChanged)
        Q_PROPERTY(QString dateOfBirth    READ dateOfBirth    NOTIFY userChanged)
        Q_PROPERTY(QString address        READ address        NOTIFY userChanged)
        Q_PROPERTY(int primaryAccountId   READ primaryAccountId NOTIFY primaryAccountChanged)


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
    QString shortName() const;
    bool isLoggedIn() const { return m_userId > 0; }
    double totalBalance() const { return m_totalBalance; }
    double dailyIncome() const { return m_dailyIncome; }
    double dailyExpense() const { return m_dailyExpense; }
    QVariantList cards() const { return m_cards; }
    bool hasCards() const { return !m_cards.isEmpty(); }
    bool isRefreshing() const { return m_isRefreshing; }
    QString passportSeries() const { return m_passportSeries; }
    QString passportNumber() const { return m_passportNumber; }
    QString dateOfBirth()    const { return m_dateOfBirth; }
    QString address()        const { return m_address; }
    int primaryAccountId()   const { return m_primaryAccountId; }

    // Setters
    void setUserData(int userId, const QString& firstName, const QString& lastName,
        const QString& middleName, const QString& email, const QString& phone);
    void setCards(const QVariantList& cards);
    void setTotalBalance(double balance);

    Q_INVOKABLE void loadUserData();      // Загрузить данные пользователя
    Q_INVOKABLE void loadCards();         // Загрузить карты
    Q_INVOKABLE void refreshBalance();    // Обновить баланс
    Q_INVOKABLE void logout();            // Выход
    Q_INVOKABLE void refreshAll();
    Q_INVOKABLE void setPrimaryAccount(int accountId);
    Q_INVOKABLE QVariantList getDebitCards();

signals:
    void userChanged();
    void balanceChanged();
    void cardsChanged();
    void loggedOut();
    void refreshingChanged();
    void primaryAccountChanged();

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
    double m_dailyIncome;
    double m_dailyExpense;
    QVariantList m_cards;
    bool    m_isRefreshing;
    QString m_passportSeries;
    QString m_passportNumber;
    QString m_dateOfBirth;
    QString m_address;
    int     m_primaryAccountId = -1;
};