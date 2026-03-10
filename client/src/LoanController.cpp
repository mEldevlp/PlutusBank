#include "LoanController.h"
#include "UserSession.h"
#include <QDate>
#include <QDebug>
#include <cmath>

LoanController::LoanController(QObject* parent)
    : QObject(parent)
    , m_net(NetworkClient::instance())
{}

// Каталог продуктов
void LoanController::loadProducts()
{
    m_products = m_net.loadLoanProducts();
    emit productsChanged();
}

// Калькулятор аннуитета
QVariantMap LoanController::calculatePayment(double amount, int months, double annualRate)
{
    QVariantMap result;

    if (amount <= 0 || months <= 0 || annualRate <= 0)
    {
        result["monthlyPayment"] = 0.0;
        result["totalAmount"] = 0.0;
        result["overpayment"] = 0.0;
        return result;
    }

    double r = annualRate / 12.0 / 100.0;
    double rn = std::pow(1.0 + r, months);

    // Ежемесячный платёж — целые рубли, округление ВВЕРХ
    double monthly = std::ceil(amount * (r * rn) / (rn - 1.0));

    // Симулируем график, чтобы получить точную итоговую сумму
    // (последний платёж будет меньше — добираем остаток тела + проценты)
    double remainPrincipal = amount;
    double actualTotal = 0.0;

    for (int i = 1; i <= months; ++i)
    {
        double interest = std::round(remainPrincipal * r * 100.0) / 100.0;

        if (i == months)
        {
            actualTotal += remainPrincipal + interest;
        }
        else
        {
            actualTotal += monthly;
            remainPrincipal -= (monthly - interest);
        }
    }

    result["monthlyPayment"] = monthly;
    result["totalAmount"] = std::round(actualTotal * 100.0) / 100.0;
    result["overpayment"] = std::round((actualTotal - amount) * 100.0) / 100.0;

    return result;
}

// Счета пользователя 
void LoanController::loadAccounts()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;

    m_accounts = m_net.getUserDebitAccounts(userId);
    emit accountsChanged();
}

// Оформление кредита

void LoanController::applyForLoan(int productId, double amount, int months, int targetAccountId)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit loanFailed("Пользователь не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();

    auto result = m_net.applyForLoan(userId, productId, amount, months, targetAccountId);

    m_isLoading = false; emit loadingChanged();

    if (result.ok)
    {
        emit loanApproved("Кредит одобрен!");
        UserSession::instance().refreshAll();
        loadUserLoans();
    }
    else
    {
        emit loanFailed(result.error);
    }
}

// Список кредитов пользователя
void LoanController::loadUserLoans()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;
    m_userLoans = m_net.loadUserLoans(userId);
    emit userLoansChanged();
}

// История закрытых кредитов
void LoanController::loadClosedLoans()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;
    auto result = m_net.loadClosedLoans(userId);
    m_closedLoans = result.loans;
    m_totalPaidAll = result.totalPaidAll;
    emit closedLoansChanged();
}

// График платежей 
void LoanController::loadSchedule(int loanId)
{
    m_schedule = m_net.loadLoanSchedule(loanId);
    emit scheduleChanged();
}

// Внести платёж
void LoanController::makePayment(int loanId)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit paymentFailed("Пользователь не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();

    auto result = m_net.makeLoanPayment(userId, loanId);

    m_isLoading = false; emit loadingChanged();

    if (!result.ok)
    {
        emit paymentFailed(result.error);
        return;
    }

    UserSession::instance().refreshAll();
    loadUserLoans();
    loadSchedule(loanId);

    if (result.closed)
    {
        emit paymentSuccess("Кредит полностью погашен!");
        emit loanClosed();
    }
    else
    {
        emit paymentSuccess(
            QString("Платёж внесён: %1 ₽").arg(result.paymentAmount, 0, 'f', 2));
    }
}