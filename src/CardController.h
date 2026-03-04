#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include "DatabaseManager.h"

class CardController : public QObject
{
    Q_OBJECT

        Q_PROPERTY(QVariantList cardTransactions READ cardTransactions NOTIFY cardTransactionsChanged)
        Q_PROPERTY(bool isLoading READ isLoading NOTIFY loadingChanged)

public:
    explicit CardController(QObject* parent = nullptr);

    QVariantList cardTransactions() const { return m_cardTransactions; }
    bool isLoading() const { return m_isLoading; }

    // Создание карты
    Q_INVOKABLE void createCard(const QString& cardType, const QString& cardBrand);
    Q_INVOKABLE QString generateCVC();
    Q_INVOKABLE QString generatePIN();

    // Управление картой
    Q_INVOKABLE void blockCard(int cardId);
    Q_INVOKABLE void freezeCard(int cardId);
    Q_INVOKABLE QVariantMap getCardDetails(int cardId);
    Q_INVOKABLE void loadCardTransactions(int accountId);
    Q_INVOKABLE void copyToClipboard(const QString& text);

    // Пополнение
    Q_INVOKABLE bool topUpAccounts(const QVariantList& accountIds, double amount);

signals:
    void cardCreated(const QVariantMap& cardData);
    void cardCreationFailed(const QString& error);
    void creationProgress(const QString& message);

    void cardBlocked();
    void cardBlockFailed(const QString& error);
    void cardFrozen(bool isFrozen);
    void cardFreezeFailed(const QString& error);

    void cardTransactionsChanged();
    void loadingChanged();

    void topUpSuccess(double totalAmount, int cardCount);
    void topUpFailed(const QString& error);

private:
    DatabaseManager& m_db;
    QVariantList m_cardTransactions;
    bool m_isLoading = false;

    QString hashData(const QString& data);
};