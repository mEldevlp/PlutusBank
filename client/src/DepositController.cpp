#include "DepositController.h"
#include "UserSession.h"
#include <QDebug>
#include <cmath>

DepositController::DepositController(QObject* parent)
    : QObject(parent)
    , m_net(NetworkClient::instance())
{}

// ---------------------------------------------------------------------
// Загрузка данных
// ---------------------------------------------------------------------
void DepositController::loadAccounts()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;
    m_accounts = m_net.getUserDebitAccounts(userId);
    emit accountsChanged();
}

void DepositController::loadSavings()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;
    m_savings = m_net.getSavingsAccount(userId);
    emit savingsChanged();
}

void DepositController::loadDeposits()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;
    m_deposits = m_net.getUserDeposits(userId);
    emit depositsChanged();
}

void DepositController::loadClosedDeposits()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;
    m_closedDeposits = m_net.getClosedDeposits(userId);
    emit closedDepositsChanged();
}

void DepositController::refreshAll()
{
    loadAccounts();
    loadSavings();
    loadDeposits();
}

// ---------------------------------------------------------------------
// Калькулятор
// ---------------------------------------------------------------------
double DepositController::rateForTerm(int months) const
{
    if (months < 1)  return 0.0;
    if (months > 12) months = 12;

    // Кусочно-линейная кривая по опорным точкам:
    //   1 мес → 7 %, 3 мес → 9 %, 6 мес → 13 %, 12 мес → 15 %
    double rate;
    if (months <= 3)
        rate = 7.0 + (months - 1) * 1.0;                       // 1→7, 2→8, 3→9
    else if (months <= 6)
        rate = 9.0 + (months - 3) * (4.0 / 3.0);               // 3→9, 6→13
    else
        rate = 13.0 + (months - 6) * (2.0 / 6.0);              // 6→13, 12→15

    return std::round(rate * 100.0) / 100.0;
}

QVariantMap DepositController::calculateDeposit(double amount, int months) const
{
    QVariantMap out;
    if (amount <= 0 || months < 1)
    {
        out["rate"]            = 0.0;
        out["finalAmount"]     = 0.0;
        out["income"]          = 0.0;
        out["effectiveYield"]  = 0.0;
        return out;
    }

    double rate     = rateForTerm(months);
    int    days     = months * 30;                              // упрощение: 30 дней / месяц
    double daily    = rate / 365.0 / 100.0;

    // Капитализация ежедневная
    double finalAmount = amount * std::pow(1.0 + daily, days);
    finalAmount = std::round(finalAmount * 100.0) / 100.0;

    double income = finalAmount - amount;

    // Эффективная доходность (% годовых, считаем как доход × 365 / срокДней / тело × 100)
    double effective = (income / amount) * (365.0 / days) * 100.0;
    effective = std::round(effective * 100.0) / 100.0;

    out["rate"]            = rate;
    out["finalAmount"]     = finalAmount;
    out["income"]          = std::round(income * 100.0) / 100.0;
    out["effectiveYield"]  = effective;
    return out;
}

// ---------------------------------------------------------------------
// Накопительный счёт
// ---------------------------------------------------------------------
void DepositController::openSavings(int fromAccountId, double amount)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit operationFailed("Не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();
    auto r = m_net.openSavingsAccount(userId, fromAccountId, amount);
    m_isLoading = false; emit loadingChanged();

    if (!r.ok) { emit operationFailed(r.error); return; }

    emit operationSuccess("Накопительный счёт открыт!");
    emit savingsOpened();
    UserSession::instance().refreshAll();
    loadSavings();
    loadAccounts();
}

void DepositController::topUpSavings(int fromAccountId, double amount)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit operationFailed("Не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();
    auto r = m_net.savingsTopUp(userId, fromAccountId, amount);
    m_isLoading = false; emit loadingChanged();

    if (!r.ok) { emit operationFailed(r.error); return; }

    emit operationSuccess(QString("Пополнено на %1 ₽").arg(amount, 0, 'f', 2));
    UserSession::instance().refreshAll();
    loadSavings();
    loadAccounts();
}

void DepositController::withdrawSavings(int toAccountId, double amount)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit operationFailed("Не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();
    auto r = m_net.savingsWithdraw(userId, toAccountId, amount);
    m_isLoading = false; emit loadingChanged();

    if (!r.ok) { emit operationFailed(r.error); return; }

    emit operationSuccess(QString("Снято %1 ₽").arg(amount, 0, 'f', 2));
    UserSession::instance().refreshAll();
    loadSavings();
    loadAccounts();
}

// ---------------------------------------------------------------------
// Срочные вклады
// ---------------------------------------------------------------------
void DepositController::openDeposit(int fromAccountId, double amount, int months, bool replenishable)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit operationFailed("Не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();
    auto r = m_net.openDeposit(userId, fromAccountId, amount, months, replenishable);
    m_isLoading = false; emit loadingChanged();

    if (!r.ok) { emit operationFailed(r.error); return; }

    emit operationSuccess("Вклад открыт!");
    emit depositOpened();
    UserSession::instance().refreshAll();
    loadDeposits();
    loadAccounts();
}

void DepositController::topUpDeposit(int depositId, int fromAccountId, double amount)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit operationFailed("Не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();
    auto r = m_net.depositTopUp(userId, depositId, fromAccountId, amount);
    m_isLoading = false; emit loadingChanged();

    if (!r.ok) { emit operationFailed(r.error); return; }

    emit operationSuccess(QString("Вклад пополнен на %1 ₽").arg(amount, 0, 'f', 2));
    UserSession::instance().refreshAll();
    loadDeposits();
    loadAccounts();
}

void DepositController::claimDeposit(int depositId, int toAccountId)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit operationFailed("Не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();
    auto r = m_net.claimDeposit(userId, depositId, toAccountId);
    m_isLoading = false; emit loadingChanged();

    if (!r.ok) { emit operationFailed(r.error); return; }

    emit operationSuccess(QString("Вклад закрыт. Получено %1 ₽").arg(r.payoutAmount, 0, 'f', 2));
    emit depositClaimed();
    UserSession::instance().refreshAll();
    loadDeposits();
    loadClosedDeposits();
    loadAccounts();
}
