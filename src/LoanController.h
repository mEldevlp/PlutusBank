#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include "DatabaseManager.h"

class LoanController : public QObject
{
    Q_OBJECT

        Q_PROPERTY(QVariantList products     READ products     NOTIFY productsChanged)
        Q_PROPERTY(QVariantList userLoans    READ userLoans    NOTIFY userLoansChanged)
        Q_PROPERTY(QVariantList closedLoans  READ closedLoans  NOTIFY closedLoansChanged)
        Q_PROPERTY(double totalPaidAll       READ totalPaidAll NOTIFY closedLoansChanged)
        Q_PROPERTY(QVariantList schedule     READ schedule     NOTIFY scheduleChanged)
        Q_PROPERTY(QVariantList accounts     READ accounts     NOTIFY accountsChanged)
        Q_PROPERTY(bool isLoading            READ isLoading    NOTIFY loadingChanged)

public:
    explicit LoanController(QObject* parent = nullptr);

    QVariantList products()   const { return m_products; }
    QVariantList userLoans()  const { return m_userLoans; }
    QVariantList closedLoans() const { return m_closedLoans; }
    double totalPaidAll()     const { return m_totalPaidAll; }
    QVariantList schedule()   const { return m_schedule; }
    QVariantList accounts()   const { return m_accounts; }
    bool isLoading()          const { return m_isLoading; }

    // Каталог
    Q_INVOKABLE void loadProducts();

    // Калькулятор аннуитета — возвращает { monthlyPayment, totalAmount, overpayment }
    Q_INVOKABLE QVariantMap calculatePayment(double amount, int months, double annualRate);

    // Счета пользователя для зачисления
    Q_INVOKABLE void loadAccounts();

    // Оформить кредит
    Q_INVOKABLE void applyForLoan(int productId, double amount, int months, int targetAccountId);

    // Мои кредиты
    Q_INVOKABLE void loadUserLoans();

    // История закрытых кредитов
    Q_INVOKABLE void loadClosedLoans();

    // График конкретного кредита
    Q_INVOKABLE void loadSchedule(int loanId);

    // Внести очередной платёж
    Q_INVOKABLE void makePayment(int loanId);

signals:
    void productsChanged();
    void userLoansChanged();
    void closedLoansChanged();
    void scheduleChanged();
    void accountsChanged();
    void loadingChanged();

    void loanApproved(const QString& message);
    void loanFailed(const QString& error);
    void paymentSuccess(const QString& message);
    void paymentFailed(const QString& error);
    void loanClosed();

private:
    DatabaseManager& m_db;
    QVariantList m_products;
    QVariantList m_userLoans;
    QVariantList m_closedLoans;
    double m_totalPaidAll = 0.0;
    QVariantList m_schedule;
    QVariantList m_accounts;
    bool m_isLoading = false;
};