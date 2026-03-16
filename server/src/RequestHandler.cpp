#include "RequestHandler.h"
#include "DatabaseManager.h"
#include "Logger.h"
#include "../shared/NetworkProtocol.h"

#include <QJsonArray>
#include <QJsonValue>
#include <QDate>

RequestHandler::RequestHandler(QObject* parent)
    : QObject(parent)
    , m_db(DatabaseManager::instance())
{
    registerHandlers();
}

QJsonObject RequestHandler::handle(const QJsonObject& request, const QString& clientTag)
{
    QString method = request["method"].toString();
    qint64 id      = request["id"].toInteger();
    QJsonObject params = request["params"].toObject();

    auto it = m_handlers.find(method);
    if (it == m_handlers.end())
    {
        Logger::instance().warning("Неизвестный метод: " + method, clientTag);
        return Protocol::makeError(id, "Неизвестный метод: " + method);
    }

    try
    {
        QJsonObject result = it.value()(params, clientTag);
        return Protocol::makeSuccess(id, result);
    }
    catch (const std::exception& e)
    {
        Logger::instance().error(QString("Исключение в %1: %2").arg(method, e.what()), clientTag);
        return Protocol::makeError(id, QString("Внутренняя ошибка сервера"));
    }
}

// ---------- Конвертеры ----------

QJsonArray RequestHandler::variantListToJson(const QVariantList& list)
{
    return QJsonArray::fromVariantList(list);
}

QJsonObject RequestHandler::variantMapToJson(const QVariantMap& map)
{
    return QJsonObject::fromVariantMap(map);
}

// ---------- Регистрация всех обработчиков ----------

void RequestHandler::registerHandlers()
{
    // ---- Auth ----

    m_handlers["registerUser"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        bool ok = m_db.registerUser(
            p["firstName"].toString(),
            p["lastName"].toString(),
            p["middleName"].toString(),
            p["dateOfBirth"].toString(),
            p["passportSeries"].toString(),
            p["passportNumber"].toString(),
            p["email"].toString(),
            p["phone"].toString(),
            p["password"].toString()
        );

        if (ok)
            Logger::instance().userAction(tag, 0, "Регистрация: " + p["phone"].toString());

        return {{"ok", ok}};
    };

    m_handlers["loginUser"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int userId = m_db.loginUser(p["phone"].toString(), p["password"].toString());
        if (userId > 0)
        {
            Logger::instance().userAction(tag, userId, "Вход в систему");
            QVariantMap data = m_db.getUserData(userId);
            return {
                {"userId", userId},
                {"userData", variantMapToJson(data)}
            };
        }
        return {{"userId", 0}};
    };

    // ---- User data ----

    m_handlers["getUserData"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        QVariantMap data = m_db.getUserData(p["userId"].toInt());
        return variantMapToJson(data);
    };

    m_handlers["getUserCards"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int userId = p["userId"].toInt();
        Logger::instance().userAction(tag, userId, "Загрузка списка карт");
        QVariantList cards = m_db.getUserCards(userId);
        return {{"cards", variantListToJson(cards)}};
    };

    m_handlers["getTotalDebitBalance"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        double balance = m_db.getTotalDebitBalance(p["userId"].toInt());
        return {{"balance", balance}};
    };

    m_handlers["getUserAccountId"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        int accId = m_db.getUserAccountId(p["userId"].toInt());
        return {{"accountId", accId}};
    };

    m_handlers["getUserAccounts"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        QVariantList accounts = m_db.getUserAccounts(p["userId"].toInt());
        return {{"accounts", variantListToJson(accounts)}};
    };

    m_handlers["getAccountBalance"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        double balance = m_db.getAccountBalance(p["accountId"].toInt());
        return {{"balance", balance}};
    };

    m_handlers["getDailyIncome"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        double income = m_db.getDailyIncome(p["userId"].toInt());
        return {{"income", income}};
    };

    m_handlers["getDailyExpense"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        double expense = m_db.getDailyExpense(p["userId"].toInt());
        return {{"expense", expense}};
    };

    // ---- Transactions ----

    m_handlers["getTransactionHistory"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int userId = p["userId"].toInt();
        int limit  = p.contains("limit")  ? p["limit"].toInt()  : 50;
        int offset = p.contains("offset") ? p["offset"].toInt() : 0;
        Logger::instance().userAction(tag, userId, "Просмотр истории транзакций");
        QVariantList history = m_db.getTransactionHistory(userId, limit, offset);
        return {{"history", variantListToJson(history)}};
    };

    // ---- Cards ----

    m_handlers["createAccount"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int userId = p["userId"].toInt();
        int accId  = m_db.createAccount(userId, p["accountType"].toString());
        Logger::instance().userAction(tag, userId, "Создание счёта, тип: " + p["accountType"].toString());
        return {{"accountId", accId}};
    };

    m_handlers["generateCardNumber"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        QString num = m_db.generateCardNumber(p["brand"].toString());
        return {{"cardNumber", num}};
    };

    m_handlers["createCard"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        bool ok = m_db.createCard(
            p["accountId"].toInt(),
            p["cardNumber"].toString(),
            p["cardHolderName"].toString(),
            QDate::fromString(p["expiryDate"].toString(), "yyyy-MM-dd"),
            p["cvcHash"].toString(),
            p["pinHash"].toString(),
            p["cardType"].toString(),
            p["cardBrand"].toString()
        );
        if (ok)
            Logger::instance().userAction(tag, 0, "Создание карты: ****" + p["cardNumber"].toString().right(4));
        return {{"ok", ok}};
    };

    m_handlers["blockCard"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int cardId = p["cardId"].toInt();
        bool ok = m_db.blockCard(cardId);
        if (ok)
            Logger::instance().userAction(tag, 0, "Блокировка карты ID " + QString::number(cardId));
        return {{"ok", ok}};
    };

    m_handlers["freezeCard"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int cardId = p["cardId"].toInt();
        bool ok = m_db.freezeCard(cardId);
        Logger::instance().userAction(tag, 0, "Заморозка/разморозка карты ID " + QString::number(cardId));
        return {{"ok", ok}};
    };

    m_handlers["unfreezeCard"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        return {{"ok", m_db.unfreezeCard(p["cardId"].toInt())}};
    };

    m_handlers["getCardFullDetails"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        QVariantMap details = m_db.getCardFullDetails(p["cardId"].toInt());
        return variantMapToJson(details);
    };

    m_handlers["getCardTransactions"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        int accId  = p["accountId"].toInt();
        int limit  = p.contains("limit")  ? p["limit"].toInt()  : 50;
        int offset = p.contains("offset") ? p["offset"].toInt() : 0;
        QVariantList list = m_db.getCardTransactions(accId, limit, offset);
        return {{"transactions", variantListToJson(list)}};
    };

    m_handlers["isAccountFrozenOrBlocked"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        bool frozen = m_db.isAccountFrozenOrBlocked(p["accountId"].toInt());
        return {{"frozen", frozen}};
    };

    // ---- Transfers ----

    m_handlers["transferBetweenAccounts"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int from = p["fromAccountId"].toInt();
        int to   = p["toAccountId"].toInt();
        double amount = p["amount"].toDouble();
        bool ok = m_db.transferBetweenAccounts(from, to, amount);
        if (ok)
            Logger::instance().userAction(tag, 0,
                QString("Перевод %1 ₽ со счёта %2 на счёт %3").arg(amount).arg(from).arg(to));
        return {{"ok", ok}};
    };

    m_handlers["transferToUser"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int from = p["fromAccountId"].toInt();
        QString phone = p["recipientPhone"].toString();
        double amount = p["amount"].toDouble();
        bool ok = m_db.transferToUser(from, phone, amount);
        if (ok)
            Logger::instance().userAction(tag, 0,
                QString("Перевод %1 ₽ на тел. %2").arg(amount).arg(phone));
        return {{"ok", ok}};
    };

    m_handlers["findAccountByPhone"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        int accId = m_db.findAccountByPhone(
            p["phone"].toString(),
            p.contains("accountType") ? p["accountType"].toString() : "debit"
        );
        return {{"accountId", accId}};
    };

    m_handlers["getAccountOwnerName"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        QString name = m_db.getAccountOwnerName(p["accountId"].toInt());
        return {{"name", name}};
    };

    m_handlers["getUserDebitAccounts"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        QVariantList list = m_db.getUserDebitAccounts(p["userId"].toInt());
        return {{"accounts", variantListToJson(list)}};
    };

    // ---- Top-up ----

    m_handlers["topUpAccount"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int accId = p["accountId"].toInt();
        double amount = p["amount"].toDouble();
        bool ok = m_db.topUpAccount(accId, amount);
        if (ok)
            Logger::instance().userAction(tag, 0,
                QString("Пополнение счёта %1 на %2 ₽").arg(accId).arg(amount));
        return {{"ok", ok}};
    };

    // ---- Primary account ----

    m_handlers["setPrimaryAccount"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        bool ok = m_db.setPrimaryAccount(p["userId"].toInt(), p["accountId"].toInt());
        return {{"ok", ok}};
    };

    m_handlers["getPrimaryAccountId"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        int accId = m_db.getPrimaryAccountId(p["userId"].toInt());
        return {{"accountId", accId}};
    };

    // ---- Loans ----

    m_handlers["loadLoanProducts"] = [this](const QJsonObject&, const QString&) -> QJsonObject
    {
        QSqlQuery q(m_db.database());
        q.prepare(
            "SELECT id, name, category, annual_rate, "
            "min_amount, max_amount, min_term_months, max_term_months, description "
            "FROM loan_products WHERE is_active = TRUE ORDER BY id"
        );
        QJsonArray arr;
        if (q.exec())
        {
            while (q.next())
            {
                QJsonObject p;
                p["id"]              = q.value(0).toInt();
                p["name"]            = q.value(1).toString();
                p["category"]        = q.value(2).toString();
                p["annual_rate"]     = q.value(3).toDouble();
                p["min_amount"]      = q.value(4).toDouble();
                p["max_amount"]      = q.value(5).toDouble();
                p["min_term_months"] = q.value(6).toInt();
                p["max_term_months"] = q.value(7).toInt();
                p["description"]     = q.value(8).toString();
                arr.append(p);
            }
        }
        return {{"products", arr}};
    };

    m_handlers["applyForLoan"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int userId          = p["userId"].toInt();
        int productId       = p["productId"].toInt();
        double amount       = p["amount"].toDouble();
        int months          = p["months"].toInt();
        int targetAccountId = p["targetAccountId"].toInt();

        Logger::instance().userAction(tag, userId,
            QString("Оформление кредита: сумма %1, срок %2 мес.").arg(amount).arg(months));

        // Полная логика оформления кредита (транзакционная)
        QSqlDatabase db = m_db.database();
        QSqlQuery q(db);

        // 1. Загружаем продукт
        q.prepare("SELECT annual_rate, min_amount, max_amount, min_term_months, max_term_months "
                  "FROM loan_products WHERE id = :id AND is_active = TRUE");
        q.bindValue(":id", productId);
        if (!q.exec() || !q.next())
            return {{"ok", false}, {"error", "Кредитный продукт не найден"}};

        double rate    = q.value(0).toDouble();
        double minAmt  = q.value(1).toDouble();
        double maxAmt  = q.value(2).toDouble();
        int    minTerm = q.value(3).toInt();
        int    maxTerm = q.value(4).toInt();

        if (amount < minAmt || amount > maxAmt)
            return {{"ok", false}, {"error", "Сумма вне допустимого диапазона"}};
        if (months < minTerm || months > maxTerm)
            return {{"ok", false}, {"error", "Срок вне допустимого диапазона"}};

        // Проверка карты
        q.prepare("SELECT c.is_blocked, c.is_active FROM cards c WHERE c.account_id = :accId LIMIT 1");
        q.bindValue(":accId", targetAccountId);
        if (q.exec() && q.next())
        {
            if (q.value(0).toBool())
                return {{"ok", false}, {"error", "Невозможно зачислить на заблокированную карту"}};
            if (!q.value(1).toBool())
                return {{"ok", false}, {"error", "Невозможно зачислить на замороженную карту"}};
        }

        // Банковский счёт
        q.prepare("SELECT a.id FROM accounts a "
                  "INNER JOIN users u ON a.user_id = u.id "
                  "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_loan_fund' LIMIT 1");
        if (!q.exec() || !q.next())
            return {{"ok", false}, {"error", "Банковский счёт не настроен"}};
        int bankAccountId = q.value(0).toInt();

        // Аннуитет
        double r   = rate / 12.0 / 100.0;
        double rn  = std::pow(1.0 + r, months);
        double mp  = amount * (r * rn) / (rn - 1.0);
        double tot = mp * months;
        mp  = std::round(mp  * 100.0) / 100.0;
        tot = std::round(tot * 100.0) / 100.0;

        db.transaction();

        // Списать с банка
        q.prepare("UPDATE accounts SET balance = balance - :amt WHERE id = :id AND balance >= :amt");
        q.bindValue(":amt", amount);
        q.bindValue(":id", bankAccountId);
        if (!q.exec() || q.numRowsAffected() == 0) { db.rollback(); return {{"ok", false}, {"error", "Банк не может выдать кредит"}}; }

        // Зачислить клиенту
        q.prepare("UPDATE accounts SET balance = balance + :amt WHERE id = :id");
        q.bindValue(":amt", amount);
        q.bindValue(":id", targetAccountId);
        if (!q.exec()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка зачисления"}}; }

        // Транзакция выдачи
        q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                  "transaction_type, description, status) "
                  "VALUES (:from, :to, :amt, 'loan_disbursement', 'Выдача кредита', 'completed') RETURNING id");
        q.bindValue(":from", bankAccountId);
        q.bindValue(":to",   targetAccountId);
        q.bindValue(":amt",  amount);
        if (!q.exec() || !q.next()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка записи транзакции"}}; }

        QDate nextPayment = QDate::currentDate().addMonths(1);
        q.prepare("INSERT INTO loans (user_id, product_id, target_account_id, bank_account_id, "
                  "principal, annual_rate, term_months, monthly_payment, remaining_balance, next_payment_date) "
                  "VALUES (:uid, :pid, :target, :bank, :principal, :rate, :term, :mp, :remain, :npd) RETURNING id");
        q.bindValue(":uid",       userId);
        q.bindValue(":pid",       productId);
        q.bindValue(":target",    targetAccountId);
        q.bindValue(":bank",      bankAccountId);
        q.bindValue(":principal", amount);
        q.bindValue(":rate",      rate);
        q.bindValue(":term",      months);
        q.bindValue(":mp",        mp);
        q.bindValue(":remain",    tot);
        q.bindValue(":npd",       nextPayment);
        if (!q.exec() || !q.next()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка создания кредита"}}; }

        int loanId = q.value(0).toInt();

        // График платежей
        double remainPrincipal = amount;
        for (int i = 1; i <= months; ++i)
        {
            double interestPart  = std::round(remainPrincipal * r * 100.0) / 100.0;
            double principalPart = std::round((mp - interestPart) * 100.0) / 100.0;
            if (i == months) { principalPart = std::round(remainPrincipal * 100.0) / 100.0; }
            double totalPart = principalPart + interestPart;
            QDate dueDate = QDate::currentDate().addMonths(i);

            q.prepare("INSERT INTO loan_schedule (loan_id, payment_number, due_date, "
                      "principal_part, interest_part, total_amount) "
                      "VALUES (:lid, :num, :due, :pp, :ip, :ta)");
            q.bindValue(":lid", loanId);
            q.bindValue(":num", i);
            q.bindValue(":due", dueDate);
            q.bindValue(":pp",  principalPart);
            q.bindValue(":ip",  interestPart);
            q.bindValue(":ta",  totalPart);
            if (!q.exec()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка создания графика"}}; }
            remainPrincipal -= principalPart;
        }

        if (!db.commit()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка подтверждения"}}; }

        Logger::instance().userAction(tag, userId, "Кредит одобрен, ID " + QString::number(loanId));
        return {{"ok", true}, {"loanId", loanId}};
    };

    m_handlers["loadUserLoans"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        int userId = p["userId"].toInt();
        QSqlQuery q(m_db.database());
        q.prepare(
            "SELECT l.id, lp.name, lp.category, l.principal, l.annual_rate, "
            "l.term_months, l.monthly_payment, l.remaining_balance, l.total_paid, "
            "l.next_payment_date, l.issued_at "
            "FROM loans l INNER JOIN loan_products lp ON l.product_id = lp.id "
            "WHERE l.user_id = :uid AND l.status = 'active' ORDER BY l.issued_at DESC"
        );
        q.bindValue(":uid", userId);

        QJsonArray arr;
        if (q.exec())
        {
            while (q.next())
            {
                QJsonObject loan;
                loan["id"]                = q.value(0).toInt();
                loan["product_name"]      = q.value(1).toString();
                loan["category"]          = q.value(2).toString();
                loan["principal"]         = q.value(3).toDouble();
                loan["annual_rate"]       = q.value(4).toDouble();
                loan["term_months"]       = q.value(5).toInt();
                loan["monthly_payment"]   = q.value(6).toDouble();
                loan["remaining_balance"] = q.value(7).toDouble();
                loan["total_paid"]        = q.value(8).toDouble();
                loan["next_payment_date"] = q.value(9).toDate().toString("dd.MM.yyyy");
                loan["issued_at"]         = q.value(10).toDateTime().toString("dd.MM.yyyy");
                arr.append(loan);
            }
        }
        return {{"loans", arr}};
    };

    m_handlers["loadClosedLoans"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        int userId = p["userId"].toInt();
        QSqlQuery q(m_db.database());
        q.prepare(
            "SELECT l.id, lp.name, lp.category, l.principal, l.annual_rate, "
            "l.term_months, l.monthly_payment, l.total_paid, l.issued_at, l.closed_at "
            "FROM loans l INNER JOIN loan_products lp ON l.product_id = lp.id "
            "WHERE l.user_id = :uid AND l.status = 'closed' ORDER BY l.closed_at DESC"
        );
        q.bindValue(":uid", userId);

        QJsonArray arr;
        double totalPaidAll = 0;
        if (q.exec())
        {
            while (q.next())
            {
                QJsonObject loan;
                loan["id"]              = q.value(0).toInt();
                loan["product_name"]    = q.value(1).toString();
                loan["category"]        = q.value(2).toString();
                loan["principal"]       = q.value(3).toDouble();
                loan["annual_rate"]     = q.value(4).toDouble();
                loan["term_months"]     = q.value(5).toInt();
                loan["monthly_payment"] = q.value(6).toDouble();
                loan["total_paid"]      = q.value(7).toDouble();
                loan["issued_at"]       = q.value(8).toDateTime().toString("dd.MM.yyyy");
                loan["closed_at"]       = q.value(9).isNull() ? "" : q.value(9).toDateTime().toString("dd.MM.yyyy");
                totalPaidAll += q.value(7).toDouble();
                arr.append(loan);
            }
        }
        return {{"loans", arr}, {"totalPaidAll", totalPaidAll}};
    };

    m_handlers["loadLoanSchedule"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
    {
        int loanId = p["loanId"].toInt();
        QSqlQuery q(m_db.database());
        q.prepare(
            "SELECT id, payment_number, due_date, principal_part, interest_part, "
            "total_amount, status, paid_at FROM loan_schedule WHERE loan_id = :lid ORDER BY payment_number"
        );
        q.bindValue(":lid", loanId);

        QJsonArray arr;
        if (q.exec())
        {
            while (q.next())
            {
                QJsonObject item;
                item["id"]             = q.value(0).toInt();
                item["payment_number"] = q.value(1).toInt();
                item["due_date"]       = q.value(2).toDate().toString("dd.MM.yyyy");
                item["principal_part"] = q.value(3).toDouble();
                item["interest_part"]  = q.value(4).toDouble();
                item["total_amount"]   = q.value(5).toDouble();
                item["status"]         = q.value(6).toString();
                item["paid_at"]        = q.value(7).isNull() ? "" : q.value(7).toDateTime().toString("dd.MM.yyyy HH:mm");
                arr.append(item);
            }
        }
        return {{"schedule", arr}};
    };

    m_handlers["makeLoanPayment"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
    {
        int userId = p["userId"].toInt();
        int loanId = p["loanId"].toInt();

        Logger::instance().userAction(tag, userId, "Платёж по кредиту ID " + QString::number(loanId));

        QSqlDatabase db = m_db.database();
        QSqlQuery q(db);

        q.prepare("SELECT target_account_id, bank_account_id, monthly_payment, remaining_balance, status "
                  "FROM loans WHERE id = :lid AND user_id = :uid");
        q.bindValue(":lid", loanId);
        q.bindValue(":uid", userId);
        if (!q.exec() || !q.next())
            return {{"ok", false}, {"error", "Кредит не найден"}};

        int clientAccountId  = q.value(0).toInt();
        int bankAccountId    = q.value(1).toInt();
        double remaining     = q.value(3).toDouble();
        QString status       = q.value(4).toString();

        if (status == "closed")
            return {{"ok", false}, {"error", "Кредит уже закрыт"}};

        q.prepare("SELECT id, total_amount FROM loan_schedule WHERE loan_id = :lid AND status = 'pending' ORDER BY payment_number LIMIT 1");
        q.bindValue(":lid", loanId);
        if (!q.exec() || !q.next())
            return {{"ok", false}, {"error", "Нет ожидающих платежей"}};

        int scheduleId       = q.value(0).toInt();
        double paymentAmount = q.value(1).toDouble();

        q.prepare("SELECT balance FROM accounts WHERE id = :id");
        q.bindValue(":id", clientAccountId);
        if (!q.exec() || !q.next())
            return {{"ok", false}, {"error", "Счёт не найден"}};

        if (q.value(0).toDouble() < paymentAmount)
            return {{"ok", false}, {"error", QString("Недостаточно средств (нужно %1 ₽)").arg(paymentAmount, 0, 'f', 2)}};

        db.transaction();

        q.prepare("UPDATE accounts SET balance = balance - :amt WHERE id = :id");
        q.bindValue(":amt", paymentAmount); q.bindValue(":id", clientAccountId);
        if (!q.exec()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка списания"}}; }

        q.prepare("UPDATE accounts SET balance = balance + :amt WHERE id = :id");
        q.bindValue(":amt", paymentAmount); q.bindValue(":id", bankAccountId);
        if (!q.exec()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка зачисления"}}; }

        q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                  "transaction_type, description, status) "
                  "VALUES (:from, :to, :amt, 'loan_payment', 'Погашение кредита', 'completed') RETURNING id");
        q.bindValue(":from", clientAccountId);
        q.bindValue(":to",   bankAccountId);
        q.bindValue(":amt",  paymentAmount);
        if (!q.exec() || !q.next()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка транзакции"}}; }
        int txId = q.value(0).toInt();

        q.prepare("UPDATE loan_schedule SET status = 'paid', paid_at = CURRENT_TIMESTAMP, transaction_id = :txId WHERE id = :sid");
        q.bindValue(":txId", txId); q.bindValue(":sid", scheduleId);
        if (!q.exec()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка обновления графика"}}; }

        double newRemaining = remaining - paymentAmount;
        bool isFullyPaid = (newRemaining < 0.01);

        if (isFullyPaid)
        {
            q.prepare("UPDATE loans SET total_paid = total_paid + :amt, remaining_balance = 0, "
                      "status = 'closed', closed_at = CURRENT_TIMESTAMP WHERE id = :lid");
        }
        else
        {
            q.prepare("UPDATE loans SET total_paid = total_paid + :amt, "
                      "remaining_balance = remaining_balance - :amt2, "
                      "next_payment_date = next_payment_date + INTERVAL '1 month' WHERE id = :lid");
            q.bindValue(":amt2", paymentAmount);
        }
        q.bindValue(":amt", paymentAmount);
        q.bindValue(":lid", loanId);
        if (!q.exec()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка обновления кредита"}}; }

        if (!db.commit()) { db.rollback(); return {{"ok", false}, {"error", "Ошибка подтверждения"}}; }

        return {{"ok", true}, {"closed", isFullyPaid}, {"paymentAmount", paymentAmount}};
    };
}
