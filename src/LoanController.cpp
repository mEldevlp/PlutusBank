#include "LoanController.h"
#include "UserSession.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDate>
#include <QDebug>
#include <cmath>

LoanController::LoanController(QObject* parent)
    : QObject(parent)
    , m_db(DatabaseManager::instance())
{
}

// Каталог продуктов

void LoanController::loadProducts()
{
    m_products.clear();
    QSqlQuery q(DatabaseManager::instance().database());

    q.prepare(
        "SELECT id, name, category, annual_rate, "
        "min_amount, max_amount, min_term_months, max_term_months, description "
        "FROM loan_products WHERE is_active = TRUE ORDER BY id"
    );

    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap p;
            p["id"] = q.value(0).toInt();
            p["name"] = q.value(1).toString();
            p["category"] = q.value(2).toString();
            p["annual_rate"] = q.value(3).toDouble();
            p["min_amount"] = q.value(4).toDouble();
            p["max_amount"] = q.value(5).toDouble();
            p["min_term_months"] = q.value(6).toInt();
            p["max_term_months"] = q.value(7).toInt();
            p["description"] = q.value(8).toString();
            m_products.append(p);
        }
    }
    else
    {
        qWarning() << u"Ошибка загрузки продуктов:" << q.lastError().text();
    }

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
    double monthly = amount * (r * rn) / (rn - 1.0);
    double total = monthly * months;

    result["monthlyPayment"] = std::round(monthly * 100.0) / 100.0;
    result["totalAmount"] = std::round(total * 100.0) / 100.0;
    result["overpayment"] = std::round((total - amount) * 100.0) / 100.0;

    return result;
}

// Счета пользователя 

void LoanController::loadAccounts()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;

    m_accounts = m_db.getUserDebitAccounts(userId);
    emit accountsChanged();
}

// Оформление кредита

void LoanController::applyForLoan(int productId, double amount, int months, int targetAccountId)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0)
    {
        emit loanFailed(u"Пользователь не авторизован"_qs);
        return;
    }

    m_isLoading = true;
    emit loadingChanged();

    QSqlDatabase db = DatabaseManager::instance().database();
    QSqlQuery q(db);

    // 1. Загружаем продукт
    q.prepare("SELECT annual_rate, min_amount, max_amount, min_term_months, max_term_months "
        "FROM loan_products WHERE id = :id AND is_active = TRUE");
    q.bindValue(":id", productId);

    if (!q.exec() || !q.next())
    {
        m_isLoading = false; emit loadingChanged();
        emit loanFailed(u"Кредитный продукт не найден"_qs);
        return;
    }

    double rate = q.value(0).toDouble();
    double minAmt = q.value(1).toDouble();
    double maxAmt = q.value(2).toDouble();
    int    minTerm = q.value(3).toInt();
    int    maxTerm = q.value(4).toInt();

    if (amount < minAmt || amount > maxAmt)
    {
        m_isLoading = false; emit loadingChanged();
        emit loanFailed(u"Сумма вне допустимого диапазона"_qs);
        return;
    }
    if (months < minTerm || months > maxTerm)
    {
        m_isLoading = false; emit loadingChanged();
        emit loanFailed(u"Срок вне допустимого диапазона"_qs);
        return;
    }

    // 2a. Проверяем, что карта привязанного счёта не заблокирована / заморожена
    q.prepare(
        "SELECT c.is_blocked, c.is_active FROM cards c "
        "WHERE c.account_id = :accId LIMIT 1"
    );
    q.bindValue(":accId", targetAccountId);

    if (q.exec() && q.next())
    {
        bool blocked = q.value(0).toBool();
        bool active = q.value(1).toBool();

        if (blocked)
        {
            m_isLoading = false; emit loadingChanged();
            emit loanFailed(u"Невозможно зачислить на заблокированную карту"_qs);
            return;
        }
        if (!active)
        {
            m_isLoading = false; emit loadingChanged();
            emit loanFailed(u"Невозможно зачислить на замороженную карту"_qs);
            return;
        }
    }

    // 2. Находим банковский счёт
    q.prepare("SELECT a.id FROM accounts a "
        "INNER JOIN users u ON a.user_id = u.id "
        "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_loan_fund' "
        "LIMIT 1");

    if (!q.exec() || !q.next())
    {
        m_isLoading = false; emit loadingChanged();
        emit loanFailed(u"Банковский счёт не настроен"_qs);
        return;
    }

    int bankAccountId = q.value(0).toInt();

    // 3. Рассчитываем аннуитет
    QVariantMap calc = calculatePayment(amount, months, rate);
    double monthlyPayment = calc["monthlyPayment"].toDouble();
    double totalAmount = calc["totalAmount"].toDouble();

    // 4. Транзакция
    db.transaction();

    // 4a. Списать с банковского счёта
    q.prepare("UPDATE accounts SET balance = balance - :amt WHERE id = :id AND balance >= :amt");
    q.bindValue(":amt", amount);
    q.bindValue(":id", bankAccountId);

    if (!q.exec() || q.numRowsAffected() == 0)
    {
        db.rollback();
        m_isLoading = false; emit loadingChanged();
        emit loanFailed(u"Банк не может выдать кредит (недостаточно средств)"_qs);
        return;
    }

    // 4b. Зачислить на счёт клиента
    q.prepare("UPDATE accounts SET balance = balance + :amt WHERE id = :id");
    q.bindValue(":amt", amount);
    q.bindValue(":id", targetAccountId);

    if (!q.exec())
    {
        db.rollback();
        m_isLoading = false; emit loadingChanged();
        emit loanFailed(u"Ошибка зачисления на счёт"_qs);
        return;
    }

    // 4c. Транзакция выдачи
    q.prepare(
        "INSERT INTO transactions (from_account_id, to_account_id, amount, "
        "transaction_type, description, status) "
        "VALUES (:from, :to, :amt, 'loan_disbursement', :desc, 'completed') "
        "RETURNING id"
    );
    q.bindValue(":from", bankAccountId);
    q.bindValue(":to", targetAccountId);
    q.bindValue(":amt", amount);
    q.bindValue(":desc", u"Выдача кредита"_qs);

    if (!q.exec() || !q.next())
    {
        db.rollback();
        m_isLoading = false; emit loadingChanged();
        emit loanFailed(u"Ошибка записи транзакции"_qs);
        return;
    }

    // 4d. Создаём запись кредита
    QDate nextPayment = QDate::currentDate().addMonths(1);

    q.prepare(
        "INSERT INTO loans (user_id, product_id, target_account_id, bank_account_id, "
        "principal, annual_rate, term_months, monthly_payment, "
        "remaining_balance, next_payment_date) "
        "VALUES (:uid, :pid, :target, :bank, :principal, :rate, :term, :mp, :remain, :npd) "
        "RETURNING id"
    );
    q.bindValue(":uid", userId);
    q.bindValue(":pid", productId);
    q.bindValue(":target", targetAccountId);
    q.bindValue(":bank", bankAccountId);
    q.bindValue(":principal", amount);
    q.bindValue(":rate", rate);
    q.bindValue(":term", months);
    q.bindValue(":mp", monthlyPayment);
    q.bindValue(":remain", totalAmount);
    q.bindValue(":npd", nextPayment);

    if (!q.exec() || !q.next())
    {
        db.rollback();
        m_isLoading = false; emit loadingChanged();
        emit loanFailed(u"Ошибка создания кредита: "_qs + q.lastError().text());
        return;
    }

    int loanId = q.value(0).toInt();

    // 4e. Генерируем график платежей (аннуитет)
    double r = rate / 12.0 / 100.0;
    double remainPrincipal = amount;

    for (int i = 1; i <= months; ++i)
    {
        double interestPart = std::round(remainPrincipal * r * 100.0) / 100.0;
        double principalPart = monthlyPayment - interestPart;

        // Последний платёж корректируем
        if (i == months)
        {
            principalPart = remainPrincipal;
            double totalPay = principalPart + interestPart;
            // monthlyPayment для последнего платежа может отличаться
            q.prepare(
                "INSERT INTO loan_schedule (loan_id, payment_number, due_date, "
                "principal_part, interest_part, total_amount) "
                "VALUES (:lid, :num, :due, :pp, :ip, :total)"
            );
            q.bindValue(":total", std::round(totalPay * 100.0) / 100.0);
        }
        else
        {
            q.prepare(
                "INSERT INTO loan_schedule (loan_id, payment_number, due_date, "
                "principal_part, interest_part, total_amount) "
                "VALUES (:lid, :num, :due, :pp, :ip, :total)"
            );
            q.bindValue(":total", monthlyPayment);
        }

        QDate dueDate = QDate::currentDate().addMonths(i);

        q.bindValue(":lid", loanId);
        q.bindValue(":num", i);
        q.bindValue(":due", dueDate);
        q.bindValue(":pp", std::round(principalPart * 100.0) / 100.0);
        q.bindValue(":ip", interestPart);

        if (!q.exec())
        {
            db.rollback();
            m_isLoading = false; emit loadingChanged();
            emit loanFailed(u"Ошибка генерации графика: "_qs + q.lastError().text());
            return;
        }

        remainPrincipal -= principalPart;
        if (remainPrincipal < 0) remainPrincipal = 0;
    }

    // 5. Коммит
    if (!db.commit())
    {
        db.rollback();
        m_isLoading = false; emit loadingChanged();
        emit loanFailed(u"Ошибка подтверждения транзакции"_qs);
        return;
    }

    m_isLoading = false;
    emit loadingChanged();

    UserSession::instance().refreshAll();
    emit loanApproved(u"Кредит одобрен! Средства зачислены на счёт."_qs);
}

// Список кредитов пользователя
void LoanController::loadUserLoans()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;

    m_userLoans.clear();
    QSqlQuery q(DatabaseManager::instance().database());

    q.prepare(
        "SELECT l.id, lp.name, lp.category, l.principal, l.annual_rate, "
        "l.term_months, l.monthly_payment, l.total_paid, l.remaining_balance, "
        "l.status, l.issued_at, l.next_payment_date "
        "FROM loans l "
        "INNER JOIN loan_products lp ON l.product_id = lp.id "
        "WHERE l.user_id = :uid "
        "ORDER BY l.issued_at DESC"
    );
    q.bindValue(":uid", userId);

    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap loan;
            loan["id"] = q.value(0).toInt();
            loan["product_name"] = q.value(1).toString();
            loan["category"] = q.value(2).toString();
            loan["principal"] = q.value(3).toDouble();
            loan["annual_rate"] = q.value(4).toDouble();
            loan["term_months"] = q.value(5).toInt();
            loan["monthly_payment"] = q.value(6).toDouble();
            loan["total_paid"] = q.value(7).toDouble();
            loan["remaining_balance"] = q.value(8).toDouble();
            loan["status"] = q.value(9).toString();
            loan["issued_at"] = q.value(10).toDateTime().toString("dd.MM.yyyy");
            loan["next_payment_date"] = q.value(11).toDate().toString("dd.MM.yyyy");
            m_userLoans.append(loan);
        }
    }
    else
    {
        qWarning() << u"Ошибка загрузки кредитов:" << q.lastError().text();
    }

    emit userLoansChanged();
}

// История закрытых кредитов
void LoanController::loadClosedLoans()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;

    m_closedLoans.clear();
    m_totalPaidAll = 0.0;

    QSqlQuery q(DatabaseManager::instance().database());

    q.prepare(
        "SELECT l.id, lp.name, lp.category, l.principal, l.annual_rate, "
        "l.term_months, l.monthly_payment, l.total_paid, "
        "l.issued_at, l.closed_at "
        "FROM loans l "
        "INNER JOIN loan_products lp ON l.product_id = lp.id "
        "WHERE l.user_id = :uid AND l.status = 'closed' "
        "ORDER BY l.closed_at DESC"
    );
    q.bindValue(":uid", userId);

    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap loan;
            loan["id"] = q.value(0).toInt();
            loan["product_name"] = q.value(1).toString();
            loan["category"] = q.value(2).toString();
            loan["principal"] = q.value(3).toDouble();
            loan["annual_rate"] = q.value(4).toDouble();
            loan["term_months"] = q.value(5).toInt();
            loan["monthly_payment"] = q.value(6).toDouble();
            loan["total_paid"] = q.value(7).toDouble();
            loan["issued_at"] = q.value(8).toDateTime().toString("dd.MM.yyyy");
            loan["closed_at"] = q.value(9).isNull()
                ? "" : q.value(9).toDateTime().toString("dd.MM.yyyy");

            m_totalPaidAll += q.value(7).toDouble();
            m_closedLoans.append(loan);
        }
    }
    else
    {
        qWarning() << u"Ошибка загрузки истории кредитов:" << q.lastError().text();
    }

    emit closedLoansChanged();
}

// График платежей 
void LoanController::loadSchedule(int loanId)
{
    m_schedule.clear();
    QSqlQuery q(DatabaseManager::instance().database());

    q.prepare(
        "SELECT id, payment_number, due_date, principal_part, interest_part, "
        "total_amount, status, paid_at "
        "FROM loan_schedule WHERE loan_id = :lid ORDER BY payment_number"
    );
    q.bindValue(":lid", loanId);

    if (q.exec())
    {
        while (q.next())
        {
            QVariantMap item;
            item["id"] = q.value(0).toInt();
            item["payment_number"] = q.value(1).toInt();
            item["due_date"] = q.value(2).toDate().toString("dd.MM.yyyy");
            item["principal_part"] = q.value(3).toDouble();
            item["interest_part"] = q.value(4).toDouble();
            item["total_amount"] = q.value(5).toDouble();
            item["status"] = q.value(6).toString();
            item["paid_at"] = q.value(7).isNull()
                ? "" : q.value(7).toDateTime().toString("dd.MM.yyyy HH:mm");
            m_schedule.append(item);
        }
    }
    else
    {
        qWarning() << u"Ошибка загрузки графика:" << q.lastError().text();
    }

    emit scheduleChanged();
}

// Внести платёж
void LoanController::makePayment(int loanId)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0)
    {
        emit paymentFailed(u"Пользователь не авторизован"_qs);
        return;
    }

    m_isLoading = true;
    emit loadingChanged();

    QSqlDatabase db = DatabaseManager::instance().database();
    QSqlQuery q(db);

    // 1. Загружаем данные кредита
    q.prepare(
        "SELECT target_account_id, bank_account_id, monthly_payment, "
        "remaining_balance, status "
        "FROM loans WHERE id = :lid AND user_id = :uid"
    );
    q.bindValue(":lid", loanId);
    q.bindValue(":uid", userId);

    if (!q.exec() || !q.next())
    {
        m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Кредит не найден"_qs);
        return;
    }

    int    clientAccountId = q.value(0).toInt();
    int    bankAccountId = q.value(1).toInt();
    double monthlyPayment = q.value(2).toDouble();
    double remaining = q.value(3).toDouble();
    QString status = q.value(4).toString();

    if (status == "closed")
    {
        m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Кредит уже закрыт"_qs);
        return;
    }

    // 2. Находим следующий неоплаченный платёж в графике
    q.prepare(
        "SELECT id, total_amount FROM loan_schedule "
        "WHERE loan_id = :lid AND status = 'pending' "
        "ORDER BY payment_number LIMIT 1"
    );
    q.bindValue(":lid", loanId);

    if (!q.exec() || !q.next())
    {
        m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Нет ожидающих платежей"_qs);
        return;
    }

    int    scheduleId = q.value(0).toInt();
    double paymentAmount = q.value(1).toDouble();

    // 3. Проверяем баланс клиента
    q.prepare("SELECT balance FROM accounts WHERE id = :id");
    q.bindValue(":id", clientAccountId);

    if (!q.exec() || !q.next())
    {
        m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Счёт не найден"_qs);
        return;
    }

    double clientBalance = q.value(0).toDouble();
    if (clientBalance < paymentAmount)
    {
        m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Недостаточно средств на счёте (нужно "_qs +
            QString::number(paymentAmount, 'f', 2) + u" ₽)"_qs);
        return;
    }

    // 4. Транзакция
    db.transaction();

    // 4a. Списать со счёта клиента
    q.prepare("UPDATE accounts SET balance = balance - :amt WHERE id = :id");
    q.bindValue(":amt", paymentAmount);
    q.bindValue(":id", clientAccountId);
    if (!q.exec()) {
        db.rollback(); m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Ошибка списания"_qs); return;
    }

    // 4b. Зачислить на банковский счёт
    q.prepare("UPDATE accounts SET balance = balance + :amt WHERE id = :id");
    q.bindValue(":amt", paymentAmount);
    q.bindValue(":id", bankAccountId);
    if (!q.exec()) {
        db.rollback(); m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Ошибка зачисления на банковский счёт"_qs); return;
    }

    // 4c. Транзакция платежа
    q.prepare(
        "INSERT INTO transactions (from_account_id, to_account_id, amount, "
        "transaction_type, description, status) "
        "VALUES (:from, :to, :amt, 'loan_payment', :desc, 'completed') "
        "RETURNING id"
    );
    q.bindValue(":from", clientAccountId);
    q.bindValue(":to", bankAccountId);
    q.bindValue(":amt", paymentAmount);
    q.bindValue(":desc", u"Погашение кредита"_qs);

    if (!q.exec() || !q.next())
    {
        db.rollback(); m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Ошибка записи транзакции"_qs);
        return;
    }

    int txId = q.value(0).toInt();

    // 4d. Обновляем строку графика
    q.prepare(
        "UPDATE loan_schedule SET status = 'paid', paid_at = CURRENT_TIMESTAMP, "
        "transaction_id = :txId WHERE id = :sid"
    );
    q.bindValue(":txId", txId);
    q.bindValue(":sid", scheduleId);
    if (!q.exec()) {
        db.rollback(); m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Ошибка обновления графика"_qs); return;
    }

    // 4e. Обновляем кредит
    double newRemaining = remaining - paymentAmount;
    if (newRemaining < 0.01) newRemaining = 0;

    bool isFullyPaid = (newRemaining < 0.01);

    if (isFullyPaid)
    {
        q.prepare(
            "UPDATE loans SET total_paid = total_paid + :amt, remaining_balance = 0, "
            "status = 'closed', closed_at = CURRENT_TIMESTAMP WHERE id = :lid"
        );
    }
    else
    {
        q.prepare(
            "UPDATE loans SET total_paid = total_paid + :amt, "
            "remaining_balance = remaining_balance - :amt2, "
            "next_payment_date = next_payment_date + INTERVAL '1 month' "
            "WHERE id = :lid"
        );
        q.bindValue(":amt2", paymentAmount);
    }
    q.bindValue(":amt", paymentAmount);
    q.bindValue(":lid", loanId);

    if (!q.exec()) {
        db.rollback(); m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Ошибка обновления кредита"_qs); return;
    }

    // 5. Коммит
    if (!db.commit())
    {
        db.rollback(); m_isLoading = false; emit loadingChanged();
        emit paymentFailed(u"Ошибка подтверждения"_qs);
        return;
    }

    m_isLoading = false;
    emit loadingChanged();

    UserSession::instance().refreshAll();
    loadUserLoans();
    loadSchedule(loanId);

    if (isFullyPaid)
    {
        emit paymentSuccess(u"Кредит полностью погашен!"_qs);
        emit loanClosed();
    }
    else
    {
        emit paymentSuccess(u"Платёж внесён: "_qs + QString::number(paymentAmount, 'f', 2) + u" ₽"_qs);
    }
}