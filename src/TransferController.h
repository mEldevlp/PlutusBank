#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include "DatabaseManager.h"

class TransferController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList accounts READ accounts NOTIFY accountsChanged)

public:
    explicit TransferController(QObject* parent = nullptr);

    QVariantList accounts() const { return m_accounts; }

    Q_INVOKABLE void loadAccounts();

    // Перевод между своими счетами
    Q_INVOKABLE void transferInternal(int fromAccountId, int toAccountId, double amount);

    // Перевод другому человеку по номеру телефона
    Q_INVOKABLE void transferExternal(int fromAccountId, const QString& phone, double amount);

    // Поиск получателя для отображения имени
    Q_INVOKABLE QString findRecipientName(const QString& phone);

signals:
    void transferSuccess(const QString& message);
    void transferFailed(const QString& error);
    void accountsChanged();
    void recipientFound(const QString& name);
    void recipientNotFound();

private:
    DatabaseManager& m_db;
    QVariantList m_accounts;
};