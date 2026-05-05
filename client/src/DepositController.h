#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include "NetworkClient.h"

/*
    DepositController — раздел «Вклады».

    Ведёт два типа продуктов:
      • Накопительный счёт (savings) — один на пользователя, 10 % годовых,
        пополнение/снятие на карту без ограничений, начисление ежедневное.
      • Срочный вклад     (deposit) — много на пользователя, ставка зависит
        от срока (1–12 мес), на карту вернуть нельзя; можно пополнять (если
        пометили как пополняемый) и видеть накопленные проценты. По истечении
        срока разблокируется кнопка «Забрать».

    Все операции синхронные (через NetworkClient).
*/
class DepositController : public QObject
{
    Q_OBJECT

    // Накопительный счёт
    Q_PROPERTY(QVariantMap savings        READ savings        NOTIFY savingsChanged)
    Q_PROPERTY(bool        hasSavings     READ hasSavings     NOTIFY savingsChanged)

    // Срочные вклады
    Q_PROPERTY(QVariantList deposits      READ deposits       NOTIFY depositsChanged)
    Q_PROPERTY(QVariantList closedDeposits READ closedDeposits NOTIFY closedDepositsChanged)

    // Доступные счета пользователя для списания / зачисления
    Q_PROPERTY(QVariantList accounts      READ accounts       NOTIFY accountsChanged)

    Q_PROPERTY(bool        isLoading      READ isLoading      NOTIFY loadingChanged)

public:
    explicit DepositController(QObject* parent = nullptr);

    QVariantMap   savings()        const { return m_savings; }
    bool          hasSavings()     const { return !m_savings.isEmpty(); }
    QVariantList  deposits()       const { return m_deposits; }
    QVariantList  closedDeposits() const { return m_closedDeposits; }
    QVariantList  accounts()       const { return m_accounts; }
    bool          isLoading()      const { return m_isLoading; }

    // ---- Загрузка данных ----
    Q_INVOKABLE void loadAccounts();
    Q_INVOKABLE void loadSavings();
    Q_INVOKABLE void loadDeposits();
    Q_INVOKABLE void loadClosedDeposits();
    Q_INVOKABLE void refreshAll();

    // ---- Калькулятор ----
    // Возвращает рекомендуемую годовую ставку для срочного вклада (1..12 мес.)
    Q_INVOKABLE double rateForTerm(int months) const;

    // Расчёт итогов: { rate, finalAmount, income, effectiveYield }
    // effectiveYield — эффективная доходность годовых (с учётом ежедневной капитализации)
    Q_INVOKABLE QVariantMap calculateDeposit(double amount, int months) const;

    // ---- Накопительный счёт ----
    Q_INVOKABLE void openSavings(int fromAccountId, double amount);
    Q_INVOKABLE void topUpSavings(int fromAccountId, double amount);
    Q_INVOKABLE void withdrawSavings(int toAccountId, double amount);

    // ---- Срочные вклады ----
    Q_INVOKABLE void openDeposit(int fromAccountId, double amount, int months, bool replenishable);
    Q_INVOKABLE void topUpDeposit(int depositId, int fromAccountId, double amount);
    Q_INVOKABLE void claimDeposit(int depositId, int toAccountId);

signals:
    void savingsChanged();
    void depositsChanged();
    void closedDepositsChanged();
    void accountsChanged();
    void loadingChanged();

    // Уведомления для UI
    void operationSuccess(const QString& message);
    void operationFailed(const QString& error);
    void depositOpened();
    void depositClaimed();
    void savingsOpened();

private:
    NetworkClient& m_net;

    QVariantMap   m_savings;
    QVariantList  m_deposits;
    QVariantList  m_closedDeposits;
    QVariantList  m_accounts;
    bool          m_isLoading = false;
};
