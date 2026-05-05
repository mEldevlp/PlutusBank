#include "RequestHandler.h"
#include "DatabaseManager.h"
#include "Logger.h"
#include "../shared/NetworkProtocol.h"

#include <QJsonArray>
#include <QJsonValue>
#include <QDate>

#include <cmath>

RequestHandler::RequestHandler(QObject* parent)
    : QObject(parent)
    , m_db(DatabaseManager::instance())
{
    registerHandlers();
}

QJsonObject RequestHandler::handle(const QJsonObject& request, const QString& clientTag)
{
    QString method = request["method"].toString();
    qint64 id = request["id"].toInteger();
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

// касты
QJsonArray RequestHandler::variantListToJson(const QVariantList& list)
{
    return QJsonArray::fromVariantList(list);
}

QJsonObject RequestHandler::variantMapToJson(const QVariantMap& map)
{
    return QJsonObject::fromVariantMap(map);
}

// Регистрация всех обработчиков
void RequestHandler::registerHandlers()
{
    // Auth
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

            return { {"ok", ok} };
        };

    m_handlers["loginUser"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int userId = m_db.loginUser(p["phone"].toString(), p["password"].toString());
            if (userId > 0)
            {
                Logger::instance().userAction(tag, userId, "Вход в систему");
                QVariantMap userData = m_db.getUserData(userId);
                return {
                    {"userId", userId},
                    {"userData", variantMapToJson(userData)}
                };
            }
            return { {"userId", 0} };
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
            return { {"cards", variantListToJson(cards)} };
        };

    m_handlers["getTotalDebitBalance"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            double balance = m_db.getTotalDebitBalance(p["userId"].toInt());
            return { {"balance", balance} };
        };

    m_handlers["getUserAccountId"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            int accId = m_db.getUserAccountId(p["userId"].toInt());
            return { {"accountId", accId} };
        };

    m_handlers["getUserAccounts"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            QVariantList accounts = m_db.getUserAccounts(p["userId"].toInt());
            return { {"accounts", variantListToJson(accounts)} };
        };

    m_handlers["getAccountBalance"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            double balance = m_db.getAccountBalance(p["accountId"].toInt());
            return { {"balance", balance} };
        };

    m_handlers["getDailyIncome"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            double income = m_db.getDailyIncome(p["userId"].toInt());
            return { {"income", income} };
        };

    m_handlers["getDailyExpense"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            double expense = m_db.getDailyExpense(p["userId"].toInt());
            return { {"expense", expense} };
        };

    // ---- Transactions ----

    m_handlers["getTransactionHistory"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int userId = p["userId"].toInt();
            int limit = p.contains("limit") ? p["limit"].toInt() : 50;
            int offset = p.contains("offset") ? p["offset"].toInt() : 0;
            Logger::instance().userAction(tag, userId, "Просмотр истории транзакций");
            QVariantList history = m_db.getTransactionHistory(userId, limit, offset);
            return { {"history", variantListToJson(history)} };
        };

    // ---- Cards ----

    m_handlers["createAccount"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int userId = p["userId"].toInt();
            int accId = m_db.createAccount(userId, p["accountType"].toString());
            Logger::instance().userAction(tag, userId, "Создание счёта, тип: " + p["accountType"].toString());
            return { {"accountId", accId} };
        };

    m_handlers["generateCardNumber"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            QString num = m_db.generateCardNumber(p["brand"].toString());
            return { {"cardNumber", num} };
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
            return { {"ok", ok} };
        };

    m_handlers["blockCard"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int cardId = p["cardId"].toInt();
            bool ok = m_db.blockCard(cardId);
            if (ok)
                Logger::instance().userAction(tag, 0, "Блокировка карты ID " + QString::number(cardId));
            return { {"ok", ok} };
        };

    m_handlers["freezeCard"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int cardId = p["cardId"].toInt();
            bool ok = m_db.freezeCard(cardId);
            Logger::instance().userAction(tag, 0, "Заморозка/разморозка карты ID " + QString::number(cardId));
            return { {"ok", ok} };
        };

    m_handlers["unfreezeCard"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            return { {"ok", m_db.unfreezeCard(p["cardId"].toInt())} };
        };

    m_handlers["getCardFullDetails"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            QVariantMap details = m_db.getCardFullDetails(p["cardId"].toInt());
            return variantMapToJson(details);
        };

    m_handlers["getCardTransactions"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            int accId = p["accountId"].toInt();
            int limit = p.contains("limit") ? p["limit"].toInt() : 50;
            int offset = p.contains("offset") ? p["offset"].toInt() : 0;
            QVariantList list = m_db.getCardTransactions(accId, limit, offset);
            return { {"transactions", variantListToJson(list)} };
        };

    m_handlers["isAccountFrozenOrBlocked"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            bool frozen = m_db.isAccountFrozenOrBlocked(p["accountId"].toInt());
            return { {"frozen", frozen} };
        };

    // ---- Transfers ----

    m_handlers["transferBetweenAccounts"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int from = p["fromAccountId"].toInt();
            int to = p["toAccountId"].toInt();
            double amount = p["amount"].toDouble();
            bool ok = m_db.transferBetweenAccounts(from, to, amount);
            if (ok)
                Logger::instance().userAction(tag, 0,
                    QString("Перевод %1 ₽ со счёта %2 на счёт %3").arg(amount).arg(from).arg(to));
            return { {"ok", ok} };
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
            return { {"ok", ok} };
        };

    m_handlers["findAccountByPhone"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            int accId = m_db.findAccountByPhone(
                p["phone"].toString(),
                p.contains("accountType") ? p["accountType"].toString() : "debit"
            );
            return { {"accountId", accId} };
        };

    m_handlers["getAccountOwnerName"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            QString name = m_db.getAccountOwnerName(p["accountId"].toInt());
            return { {"name", name} };
        };

    m_handlers["getUserDebitAccounts"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            QVariantList list = m_db.getUserDebitAccounts(p["userId"].toInt());
            return { {"accounts", variantListToJson(list)} };
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
            return { {"ok", ok} };
        };

    // ---- Primary account ----

    m_handlers["setPrimaryAccount"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            bool ok = m_db.setPrimaryAccount(p["userId"].toInt(), p["accountId"].toInt());
            return { {"ok", ok} };
        };

    m_handlers["getPrimaryAccountId"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            int accId = m_db.getPrimaryAccountId(p["userId"].toInt());
            return { {"accountId", accId} };
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
                    p["id"] = q.value(0).toInt();
                    p["name"] = q.value(1).toString();
                    p["category"] = q.value(2).toString();
                    p["annual_rate"] = q.value(3).toDouble();
                    p["min_amount"] = q.value(4).toDouble();
                    p["max_amount"] = q.value(5).toDouble();
                    p["min_term_months"] = q.value(6).toInt();
                    p["max_term_months"] = q.value(7).toInt();
                    p["description"] = q.value(8).toString();
                    arr.append(p);
                }
            }
            return { {"products", arr} };
        };

    m_handlers["applyForLoan"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int userId = p["userId"].toInt();
            int productId = p["productId"].toInt();
            double amount = p["amount"].toDouble();
            int months = p["months"].toInt();
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
                return { {"ok", false}, {"error", "Кредитный продукт не найден"} };

            double rate = q.value(0).toDouble();
            double minAmt = q.value(1).toDouble();
            double maxAmt = q.value(2).toDouble();
            int    minTerm = q.value(3).toInt();
            int    maxTerm = q.value(4).toInt();

            if (amount < minAmt || amount > maxAmt)
                return { {"ok", false}, {"error", "Сумма вне допустимого диапазона"} };
            if (months < minTerm || months > maxTerm)
                return { {"ok", false}, {"error", "Срок вне допустимого диапазона"} };

            // Проверка карты
            q.prepare("SELECT c.is_blocked, c.is_active FROM cards c WHERE c.account_id = :accId LIMIT 1");
            q.bindValue(":accId", targetAccountId);
            if (q.exec() && q.next())
            {
                if (q.value(0).toBool())
                    return { {"ok", false}, {"error", "Невозможно зачислить на заблокированную карту"} };
                if (!q.value(1).toBool())
                    return { {"ok", false}, {"error", "Невозможно зачислить на замороженную карту"} };
            }

            // Банковский счёт
            q.prepare("SELECT a.id FROM accounts a "
                "INNER JOIN users u ON a.user_id = u.id "
                "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_loan_fund' LIMIT 1");
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Банковский счёт не настроен"} };
            int bankAccountId = q.value(0).toInt();

            // Аннуитет
            double r = rate / 12.0 / 100.0;
            double rn = std::pow(1.0 + r, months);
            double mp = amount * (r * rn) / (rn - 1.0);
            double tot = mp * months;
            mp = std::round(mp * 100.0) / 100.0;
            tot = std::round(tot * 100.0) / 100.0;

            db.transaction();

            // Списать с банка
            q.prepare("UPDATE accounts SET balance = balance - :amt WHERE id = :id AND balance >= :amt");
            q.bindValue(":amt", amount);
            q.bindValue(":id", bankAccountId);
            if (!q.exec() || q.numRowsAffected() == 0) { db.rollback(); return { {"ok", false}, {"error", "Банк не может выдать кредит"} }; }

            // Зачислить клиенту
            q.prepare("UPDATE accounts SET balance = balance + :amt WHERE id = :id");
            q.bindValue(":amt", amount);
            q.bindValue(":id", targetAccountId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка зачисления"} }; }

            // Транзакция выдачи
            q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                "transaction_type, description, status) "
                "VALUES (:from, :to, :amt, 'loan_disbursement', 'Выдача кредита', 'completed') RETURNING id");
            q.bindValue(":from", bankAccountId);
            q.bindValue(":to", targetAccountId);
            q.bindValue(":amt", amount);
            if (!q.exec() || !q.next()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка записи транзакции"} }; }

            QDate nextPayment = QDate::currentDate().addMonths(1);
            q.prepare("INSERT INTO loans (user_id, product_id, target_account_id, bank_account_id, "
                "principal, annual_rate, term_months, monthly_payment, remaining_balance, next_payment_date) "
                "VALUES (:uid, :pid, :target, :bank, :principal, :rate, :term, :mp, :remain, :npd) RETURNING id");
            q.bindValue(":uid", userId);
            q.bindValue(":pid", productId);
            q.bindValue(":target", targetAccountId);
            q.bindValue(":bank", bankAccountId);
            q.bindValue(":principal", amount);
            q.bindValue(":rate", rate);
            q.bindValue(":term", months);
            q.bindValue(":mp", mp);
            q.bindValue(":remain", tot);
            q.bindValue(":npd", nextPayment);
            if (!q.exec() || !q.next()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка создания кредита"} }; }

            int loanId = q.value(0).toInt();

            // График платежей
            double remainPrincipal = amount;
            for (int i = 1; i <= months; ++i)
            {
                double interestPart = std::round(remainPrincipal * r * 100.0) / 100.0;
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
                q.bindValue(":pp", principalPart);
                q.bindValue(":ip", interestPart);
                q.bindValue(":ta", totalPart);
                if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка создания графика"} }; }
                remainPrincipal -= principalPart;
            }

            if (!db.commit()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка подтверждения"} }; }

            Logger::instance().userAction(tag, userId, "Кредит одобрен, ID " + QString::number(loanId));
            return { {"ok", true}, {"loanId", loanId} };
        };

    m_handlers["loadUserLoans"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            int userId = p["userId"].toInt();
            QSqlQuery q(m_db.database());
            q.prepare(
                "SELECT l.id, lp.name, lp.category, l.principal, l.annual_rate, "
                "l.term_months, l.monthly_payment, l.remaining_balance, l.total_paid, "
                "l.next_payment_date, l.issued_at, l.status "
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
                    loan["id"] = q.value(0).toInt();
                    loan["product_name"] = q.value(1).toString();
                    loan["category"] = q.value(2).toString();
                    loan["principal"] = q.value(3).toDouble();
                    loan["annual_rate"] = q.value(4).toDouble();
                    loan["term_months"] = q.value(5).toInt();
                    loan["monthly_payment"] = q.value(6).toDouble();
                    loan["remaining_balance"] = q.value(7).toDouble();
                    loan["total_paid"] = q.value(8).toDouble();
                    loan["next_payment_date"] = q.value(9).toDate().toString("dd.MM.yyyy");
                    loan["issued_at"] = q.value(10).toDateTime().toString("dd.MM.yyyy");
                    loan["status"] = q.value(11).toString();
                    arr.append(loan);
                }
            }
            return { {"loans", arr} };
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
                    loan["id"] = q.value(0).toInt();
                    loan["product_name"] = q.value(1).toString();
                    loan["category"] = q.value(2).toString();
                    loan["principal"] = q.value(3).toDouble();
                    loan["annual_rate"] = q.value(4).toDouble();
                    loan["term_months"] = q.value(5).toInt();
                    loan["monthly_payment"] = q.value(6).toDouble();
                    loan["total_paid"] = q.value(7).toDouble();
                    loan["issued_at"] = q.value(8).toDateTime().toString("dd.MM.yyyy");
                    loan["closed_at"] = q.value(9).isNull() ? "" : q.value(9).toDateTime().toString("dd.MM.yyyy");
                    totalPaidAll += q.value(7).toDouble();
                    arr.append(loan);
                }
            }
            return { {"loans", arr}, {"totalPaidAll", totalPaidAll} };
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
                    item["id"] = q.value(0).toInt();
                    item["payment_number"] = q.value(1).toInt();
                    item["due_date"] = q.value(2).toDate().toString("dd.MM.yyyy");
                    item["principal_part"] = q.value(3).toDouble();
                    item["interest_part"] = q.value(4).toDouble();
                    item["total_amount"] = q.value(5).toDouble();
                    item["status"] = q.value(6).toString();
                    item["paid_at"] = q.value(7).isNull() ? "" : q.value(7).toDateTime().toString("dd.MM.yyyy HH:mm");
                    arr.append(item);
                }
            }
            return { {"schedule", arr} };
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
                return { {"ok", false}, {"error", "Кредит не найден"} };

            int clientAccountId = q.value(0).toInt();
            int bankAccountId = q.value(1).toInt();
            double remaining = q.value(3).toDouble();
            QString status = q.value(4).toString();

            if (status == "closed")
                return { {"ok", false}, {"error", "Кредит уже закрыт"} };

            q.prepare("SELECT id, total_amount FROM loan_schedule WHERE loan_id = :lid AND status = 'pending' ORDER BY payment_number LIMIT 1");
            q.bindValue(":lid", loanId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Нет ожидающих платежей"} };

            int scheduleId = q.value(0).toInt();
            double paymentAmount = q.value(1).toDouble();

            q.prepare("SELECT balance FROM accounts WHERE id = :id");
            q.bindValue(":id", clientAccountId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Счёт не найден"} };

            if (q.value(0).toDouble() < paymentAmount)
                return { {"ok", false}, {"error", QString("Недостаточно средств (нужно %1 ₽)").arg(paymentAmount, 0, 'f', 2)} };

            db.transaction();

            q.prepare("UPDATE accounts SET balance = balance - :amt WHERE id = :id");
            q.bindValue(":amt", paymentAmount); q.bindValue(":id", clientAccountId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка списания"} }; }

            q.prepare("UPDATE accounts SET balance = balance + :amt WHERE id = :id");
            q.bindValue(":amt", paymentAmount); q.bindValue(":id", bankAccountId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка зачисления"} }; }

            q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                "transaction_type, description, status) "
                "VALUES (:from, :to, :amt, 'loan_payment', 'Погашение кредита', 'completed') RETURNING id");
            q.bindValue(":from", clientAccountId);
            q.bindValue(":to", bankAccountId);
            q.bindValue(":amt", paymentAmount);
            if (!q.exec() || !q.next()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка транзакции"} }; }
            int txId = q.value(0).toInt();

            q.prepare("UPDATE loan_schedule SET status = 'paid', paid_at = CURRENT_TIMESTAMP, transaction_id = :txId WHERE id = :sid");
            q.bindValue(":txId", txId); q.bindValue(":sid", scheduleId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка обновления графика"} }; }

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
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка обновления кредита"} }; }

            if (!db.commit()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка подтверждения"} }; }

            return { {"ok", true}, {"closed", isFullyPaid}, {"paymentAmount", paymentAmount} };
        };

    // ---- Crypto ----

    m_handlers["getCryptocurrencies"] = [this](const QJsonObject&, const QString&) -> QJsonObject
        {
            QVariantList list = m_db.getCryptocurrencies();
            return { {"currencies", variantListToJson(list)} };
        };

    m_handlers["getUserWallets"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int userId = p["userId"].toInt();
            Logger::instance().userAction(tag, userId, "Загрузка крипто-кошельков");
            QVariantList list = m_db.getUserWallets(userId);
            return { {"wallets", variantListToJson(list)} };
        };

    m_handlers["buyCrypto"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int    userId = p["userId"].toInt();
            int    cryptoId = p["currencyId"].toInt();
            double rubAmount = p["rubAmount"].toDouble();
            int    cardId = p["cardId"].toInt();

            auto r = m_db.buyCrypto(userId, cryptoId, rubAmount, cardId);
            if (r.ok)
            {
                Logger::instance().userAction(tag, userId,
                    QString("Покупка крипты: %1 монет за %2 ₽")
                    .arg(r.coinAmount, 0, 'f', 8).arg(r.rubAmount, 0, 'f', 2));
            }
            return {
                {"ok",         r.ok},
                {"error",      r.error},
                {"coinAmount", r.coinAmount},
                {"rubAmount",  r.rubAmount},
                {"price",      r.price}
            };
        };

    m_handlers["sellCrypto"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int    userId = p["userId"].toInt();
            int    cryptoId = p["currencyId"].toInt();
            double coinAmount = p["coinAmount"].toDouble();
            int    cardId = p["cardId"].toInt();

            auto r = m_db.sellCrypto(userId, cryptoId, coinAmount, cardId);
            if (r.ok)
            {
                Logger::instance().userAction(tag, userId,
                    QString("Продажа крипты: %1 монет за %2 ₽")
                    .arg(r.coinAmount, 0, 'f', 8).arg(r.rubAmount, 0, 'f', 2));
            }
            return {
                {"ok",         r.ok},
                {"error",      r.error},
                {"coinAmount", r.coinAmount},
                {"rubAmount",  r.rubAmount},
                {"price",      r.price}
            };
        };

    m_handlers["transferCrypto"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int     userId = p["userId"].toInt();
            int     cryptoId = p["currencyId"].toInt();
            double  coinAmount = p["coinAmount"].toDouble();
            QString recipient = p["recipientAddress"].toString();

            auto r = m_db.transferCrypto(userId, cryptoId, coinAmount, recipient);
            if (r.ok)
            {
                Logger::instance().userAction(tag, userId,
                    QString("Крипто-перевод %1 → %2").arg(r.coinAmount, 0, 'f', 8).arg(recipient));
            }
            return {
                {"ok",            r.ok},
                {"error",         r.error},
                {"coinAmount",    r.coinAmount},
                {"recipientName", r.recipientName}
            };
        };

    m_handlers["getCryptoHistory"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            int userId = p["userId"].toInt();
            int limit = p.contains("limit") ? p["limit"].toInt() : 50;
            int offset = p.contains("offset") ? p["offset"].toInt() : 0;
            QVariantList list = m_db.getCryptoHistory(userId, limit, offset);
            return { {"history", variantListToJson(list)} };
        };

    m_handlers["getCoinDetail"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int userId = p["userId"].toInt();
            int currencyId = p["currencyId"].toInt();
            Logger::instance().userAction(tag, userId,
                QString("Загрузка деталей крипто-монеты %1").arg(currencyId));

            QVariantMap detail = m_db.getCoinDetail(userId, currencyId);
            return variantMapToJson(detail);
        };

    // ---- Deposits / Savings ----

    // ---------- helper: ленивое начисление процентов по нак. счёту ----------
    // Считаем, сколько прошло календарных дней с last_interest_date,
    // и доначисляем сложные проценты за каждый день.
    auto accrueSavingsInterest = [this](int savingsId, const QString& tag, int userId) -> void
        {
            QSqlQuery q(m_db.database());
            q.prepare("SELECT balance, annual_rate, last_interest_date "
                "FROM savings_accounts WHERE id = :id AND status = 'active'");
            q.bindValue(":id", savingsId);
            if (!q.exec() || !q.next()) return;

            double balance = q.value(0).toDouble();
            double rate = q.value(1).toDouble();
            QDate  lastDate = q.value(2).toDate();
            QDate  today = QDate::currentDate();

            int days = lastDate.daysTo(today);
            if (days <= 0 || balance <= 0) return;

            double daily = rate / 365.0 / 100.0;
            double newBalance = balance * std::pow(1.0 + daily, days);
            newBalance = std::round(newBalance * 100.0) / 100.0;
            double interest = newBalance - balance;
            if (interest <= 0.005) {
                // Обновим только дату, чтобы не дрожать на копейках
                q.prepare("UPDATE savings_accounts SET last_interest_date = :d WHERE id = :id");
                q.bindValue(":d", today);
                q.bindValue(":id", savingsId);
                q.exec();
                return;
            }

            QSqlDatabase db = m_db.database();
            db.transaction();

            q.prepare("UPDATE savings_accounts SET balance = :b, "
                "total_interest_paid = total_interest_paid + :i, "
                "last_interest_date = :d WHERE id = :id");
            q.bindValue(":b", newBalance);
            q.bindValue(":i", interest);
            q.bindValue(":d", today);
            q.bindValue(":id", savingsId);
            if (!q.exec()) { db.rollback(); return; }

            // Логируем как операцию (без банковской транзакции —
            // проценты внутри банка, не движение между счетами клиента)
            q.prepare("INSERT INTO deposit_operations "
                "(user_id, savings_id, operation_type, amount, balance_after, description) "
                "VALUES (:uid, :sid, 'savings_interest', :amt, :bal, "
                ":descr)");
            q.bindValue(":uid", userId);
            q.bindValue(":sid", savingsId);
            q.bindValue(":amt", interest);
            q.bindValue(":bal", newBalance);
            q.bindValue(":descr", QString("Начислено за %1 дн.").arg(days));
            q.exec();

            db.commit();
            Logger::instance().userAction(tag, userId,
                QString("Начислены проценты по нак. счёту: %1 ₽").arg(interest, 0, 'f', 2));
        };

    // ---------- helper: ленивое начисление процентов по срочному вкладу ----
    auto accrueDepositInterest = [this](int depositId, const QString& tag, int userId) -> void
        {
            QSqlQuery q(m_db.database());
            q.prepare("SELECT current_balance, annual_rate, last_interest_date, matures_at, status "
                "FROM deposits WHERE id = :id");
            q.bindValue(":id", depositId);
            if (!q.exec() || !q.next()) return;

            double balance = q.value(0).toDouble();
            double rate = q.value(1).toDouble();
            QDate  lastDate = q.value(2).toDate();
            QDate  matures = q.value(3).toDate();
            QString status = q.value(4).toString();

            if (status != "active") return;

            QDate today = QDate::currentDate();
            // Проценты начисляются только до даты погашения
            QDate effectiveTo = (today > matures) ? matures : today;
            int days = lastDate.daysTo(effectiveTo);
            if (days <= 0 || balance <= 0) return;

            double daily = rate / 365.0 / 100.0;
            double newBalance = balance * std::pow(1.0 + daily, days);
            newBalance = std::round(newBalance * 100.0) / 100.0;
            double interest = newBalance - balance;

            QSqlDatabase db = m_db.database();
            db.transaction();

            if (interest > 0.005)
            {
                q.prepare("UPDATE deposits SET current_balance = :b, "
                    "total_interest = total_interest + :i, "
                    "last_interest_date = :d WHERE id = :id");
                q.bindValue(":b", newBalance);
                q.bindValue(":i", interest);
                q.bindValue(":d", effectiveTo);
                q.bindValue(":id", depositId);
                if (!q.exec()) { db.rollback(); return; }

                q.prepare("INSERT INTO deposit_operations "
                    "(user_id, deposit_id, operation_type, amount, balance_after, description) "
                    "VALUES (:uid, :did, 'deposit_interest', :amt, :bal, :descr)");
                q.bindValue(":uid", userId);
                q.bindValue(":did", depositId);
                q.bindValue(":amt", interest);
                q.bindValue(":bal", newBalance);
                q.bindValue(":descr", QString("Начислено за %1 дн.").arg(days));
                q.exec();
            }
            else
            {
                // Ничего не начислили — обновим только дату
                q.prepare("UPDATE deposits SET last_interest_date = :d WHERE id = :id");
                q.bindValue(":d", effectiveTo);
                q.bindValue(":id", depositId);
                q.exec();
            }

            // Если срок вышел — переводим в статус matured (но деньги ещё не отдаём)
            if (today >= matures)
            {
                q.prepare("UPDATE deposits SET status = 'matured' WHERE id = :id AND status = 'active'");
                q.bindValue(":id", depositId);
                q.exec();
            }

            db.commit();

            if (interest > 0.005)
                Logger::instance().userAction(tag, userId,
                    QString("Начислены проценты по вкладу #%1: %2 ₽")
                    .arg(depositId).arg(interest, 0, 'f', 2));
        };

    // ---------- helper: получить ID банковского депозитного фонда ---------
    auto getBankDepositFundId = [this]() -> int
        {
            QSqlQuery q(m_db.database());
            q.prepare("SELECT a.id FROM accounts a "
                "INNER JOIN users u ON a.user_id = u.id "
                "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_deposit_fund' LIMIT 1");
            if (q.exec() && q.next()) return q.value(0).toInt();
            return -1;
        };

    // =====================================================================
    //                     SAVINGS  (накопительный счёт)
    // =====================================================================

    m_handlers["getSavingsAccount"] = [this, accrueSavingsInterest](
        const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int userId = p["userId"].toInt();

            QSqlQuery q(m_db.database());
            q.prepare("SELECT id FROM savings_accounts WHERE user_id = :uid AND status = 'active'");
            q.bindValue(":uid", userId);
            if (!q.exec() || !q.next())
                return { {"exists", false} };

            int sid = q.value(0).toInt();
            accrueSavingsInterest(sid, tag, userId);

            q.prepare("SELECT id, balance, annual_rate, last_interest_date, "
                "total_interest_paid, created_at "
                "FROM savings_accounts WHERE id = :id");
            q.bindValue(":id", sid);
            if (!q.exec() || !q.next())
                return { {"exists", false} };

            QJsonObject s;
            s["id"] = q.value(0).toInt();
            s["balance"] = q.value(1).toDouble();
            s["annual_rate"] = q.value(2).toDouble();
            s["last_interest_date"] = q.value(3).toDate().toString("dd.MM.yyyy");
            s["total_interest"] = q.value(4).toDouble();
            s["created_at"] = q.value(5).toDateTime().toString("dd.MM.yyyy");

            return { {"exists", true}, {"savings", s} };
        };

    m_handlers["openSavingsAccount"] = [this](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int    userId = p["userId"].toInt();
            int    fromAccountId = p["fromAccountId"].toInt();
            double amount = p["amount"].toDouble();

            Logger::instance().userAction(tag, userId,
                QString("Открытие накопительного счёта на %1 ₽").arg(amount));

            if (amount <= 0)
                return { {"ok", false}, {"error", "Сумма должна быть положительной"} };

            QSqlDatabase db = m_db.database();
            QSqlQuery q(db);

            // Проверка: уже есть активный?
            q.prepare("SELECT id FROM savings_accounts WHERE user_id = :uid AND status = 'active'");
            q.bindValue(":uid", userId);
            if (q.exec() && q.next())
                return { {"ok", false}, {"error", "У вас уже есть накопительный счёт"} };

            // Баланс счёта-источника
            q.prepare("SELECT balance, user_id FROM accounts WHERE id = :id");
            q.bindValue(":id", fromAccountId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Счёт списания не найден"} };
            if (q.value(1).toInt() != userId)
                return { {"ok", false}, {"error", "Счёт принадлежит другому пользователю"} };
            if (q.value(0).toDouble() < amount)
                return { {"ok", false}, {"error", "Недостаточно средств на счёте"} };

            db.transaction();

            // 1. Списать с дебетового счёта
            q.prepare("UPDATE accounts SET balance = balance - :a WHERE id = :id AND balance >= :a");
            q.bindValue(":a", amount);
            q.bindValue(":id", fromAccountId);
            if (!q.exec() || q.numRowsAffected() == 0)
            {
                db.rollback(); return { {"ok", false}, {"error", "Не удалось списать средства"} };
            }

            // 2. Найти банковский фонд вкладов
            q.prepare("SELECT a.id FROM accounts a INNER JOIN users u ON a.user_id = u.id "
                "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_deposit_fund' LIMIT 1");
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Банковский фонд не настроен"} };
            }
            int fundId = q.value(0).toInt();

            // 3. Зачислить в фонд
            q.prepare("UPDATE accounts SET balance = balance + :a WHERE id = :id");
            q.bindValue(":a", amount); q.bindValue(":id", fundId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка фонда"} }; }

            // 4. Записать банковскую транзакцию
            q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                "transaction_type, description, status) "
                "VALUES (:f, :t, :a, 'savings_topup', 'Открытие накоп. счёта', 'completed') RETURNING id");
            q.bindValue(":f", fromAccountId); q.bindValue(":t", fundId); q.bindValue(":a", amount);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка транзакции"} };
            }
            int txId = q.value(0).toInt();

            // 5. Создать накопительный счёт
            q.prepare("INSERT INTO savings_accounts (user_id, balance, annual_rate) "
                "VALUES (:uid, :b, 10.00) RETURNING id");
            q.bindValue(":uid", userId); q.bindValue(":b", amount);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка создания счёта"} };
            }
            int sid = q.value(0).toInt();

            // 6. Запись в журнал
            q.prepare("INSERT INTO deposit_operations "
                "(user_id, savings_id, operation_type, amount, balance_after, transaction_id, description) "
                "VALUES (:uid, :sid, 'savings_open', :a, :b, :tx, 'Открытие накопительного счёта')");
            q.bindValue(":uid", userId); q.bindValue(":sid", sid);
            q.bindValue(":a", amount);   q.bindValue(":b", amount); q.bindValue(":tx", txId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка журнала"} }; }

            if (!db.commit()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка подтверждения"} }; }
            return { {"ok", true} };
        };

    m_handlers["savingsTopUp"] = [this, accrueSavingsInterest](
        const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int    userId = p["userId"].toInt();
            int    fromAccountId = p["fromAccountId"].toInt();
            double amount = p["amount"].toDouble();

            Logger::instance().userAction(tag, userId,
                QString("Пополнение накоп. счёта на %1 ₽").arg(amount));

            if (amount <= 0)
                return { {"ok", false}, {"error", "Сумма должна быть положительной"} };

            QSqlDatabase db = m_db.database();
            QSqlQuery q(db);

            q.prepare("SELECT id FROM savings_accounts WHERE user_id = :uid AND status = 'active'");
            q.bindValue(":uid", userId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Накопительный счёт не найден"} };
            int sid = q.value(0).toInt();

            // Сначала доначислим проценты до сегодняшнего дня
            accrueSavingsInterest(sid, tag, userId);

            // Источник
            q.prepare("SELECT balance, user_id FROM accounts WHERE id = :id");
            q.bindValue(":id", fromAccountId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Счёт не найден"} };
            if (q.value(1).toInt() != userId)
                return { {"ok", false}, {"error", "Чужой счёт"} };
            if (q.value(0).toDouble() < amount)
                return { {"ok", false}, {"error", "Недостаточно средств"} };

            // Банковский фонд
            q.prepare("SELECT a.id FROM accounts a INNER JOIN users u ON a.user_id = u.id "
                "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_deposit_fund' LIMIT 1");
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Фонд не настроен"} };
            int fundId = q.value(0).toInt();

            db.transaction();

            q.prepare("UPDATE accounts SET balance = balance - :a WHERE id = :id AND balance >= :a");
            q.bindValue(":a", amount); q.bindValue(":id", fromAccountId);
            if (!q.exec() || q.numRowsAffected() == 0)
            {
                db.rollback(); return { {"ok", false}, {"error", "Не удалось списать"} };
            }

            q.prepare("UPDATE accounts SET balance = balance + :a WHERE id = :id");
            q.bindValue(":a", amount); q.bindValue(":id", fundId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка фонда"} }; }

            q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                "transaction_type, description, status) "
                "VALUES (:f, :t, :a, 'savings_topup', 'Пополнение накоп. счёта', 'completed') RETURNING id");
            q.bindValue(":f", fromAccountId); q.bindValue(":t", fundId); q.bindValue(":a", amount);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка транзакции"} };
            }
            int txId = q.value(0).toInt();

            q.prepare("UPDATE savings_accounts SET balance = balance + :a WHERE id = :id "
                "RETURNING balance");
            q.bindValue(":a", amount); q.bindValue(":id", sid);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка обновления"} };
            }
            double newBalance = q.value(0).toDouble();

            q.prepare("INSERT INTO deposit_operations "
                "(user_id, savings_id, operation_type, amount, balance_after, transaction_id, description) "
                "VALUES (:uid, :sid, 'savings_topup', :a, :b, :tx, 'Пополнение')");
            q.bindValue(":uid", userId); q.bindValue(":sid", sid);
            q.bindValue(":a", amount);   q.bindValue(":b", newBalance); q.bindValue(":tx", txId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка журнала"} }; }

            if (!db.commit()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка подтверждения"} }; }
            return { {"ok", true} };
        };

    m_handlers["savingsWithdraw"] = [this, accrueSavingsInterest](
        const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int    userId = p["userId"].toInt();
            int    toAccountId = p["toAccountId"].toInt();
            double amount = p["amount"].toDouble();

            Logger::instance().userAction(tag, userId,
                QString("Снятие с накоп. счёта %1 ₽").arg(amount));

            if (amount <= 0)
                return { {"ok", false}, {"error", "Сумма должна быть положительной"} };

            QSqlDatabase db = m_db.database();
            QSqlQuery q(db);

            q.prepare("SELECT id FROM savings_accounts WHERE user_id = :uid AND status = 'active'");
            q.bindValue(":uid", userId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Накопительный счёт не найден"} };
            int sid = q.value(0).toInt();

            // Доначислим проценты
            accrueSavingsInterest(sid, tag, userId);

            // Проверка
            q.prepare("SELECT balance FROM savings_accounts WHERE id = :id");
            q.bindValue(":id", sid);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Счёт не найден"} };
            double balance = q.value(0).toDouble();
            if (balance < amount)
                return { {"ok", false}, {"error", QString("На счёте только %1 ₽").arg(balance, 0, 'f', 2)} };

            // Получатель
            q.prepare("SELECT user_id FROM accounts WHERE id = :id");
            q.bindValue(":id", toAccountId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Счёт зачисления не найден"} };
            if (q.value(0).toInt() != userId)
                return { {"ok", false}, {"error", "Чужой счёт"} };

            // Фонд
            q.prepare("SELECT a.id FROM accounts a INNER JOIN users u ON a.user_id = u.id "
                "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_deposit_fund' LIMIT 1");
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Фонд не настроен"} };
            int fundId = q.value(0).toInt();

            db.transaction();

            q.prepare("UPDATE accounts SET balance = balance - :a WHERE id = :id AND balance >= :a");
            q.bindValue(":a", amount); q.bindValue(":id", fundId);
            if (!q.exec() || q.numRowsAffected() == 0)
            {
                db.rollback(); return { {"ok", false}, {"error", "Фонд не может выдать"} };
            }

            q.prepare("UPDATE accounts SET balance = balance + :a WHERE id = :id");
            q.bindValue(":a", amount); q.bindValue(":id", toAccountId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка зачисления"} }; }

            q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                "transaction_type, description, status) "
                "VALUES (:f, :t, :a, 'savings_withdraw', 'Снятие с накоп. счёта', 'completed') RETURNING id");
            q.bindValue(":f", fundId); q.bindValue(":t", toAccountId); q.bindValue(":a", amount);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка транзакции"} };
            }
            int txId = q.value(0).toInt();

            q.prepare("UPDATE savings_accounts SET balance = balance - :a WHERE id = :id "
                "RETURNING balance");
            q.bindValue(":a", amount); q.bindValue(":id", sid);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка обновления"} };
            }
            double newBalance = q.value(0).toDouble();

            q.prepare("INSERT INTO deposit_operations "
                "(user_id, savings_id, operation_type, amount, balance_after, transaction_id, description) "
                "VALUES (:uid, :sid, 'savings_withdraw', :a, :b, :tx, 'Снятие на карту')");
            q.bindValue(":uid", userId); q.bindValue(":sid", sid);
            q.bindValue(":a", amount);   q.bindValue(":b", newBalance); q.bindValue(":tx", txId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка журнала"} }; }

            if (!db.commit()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка подтверждения"} }; }
            return { {"ok", true} };
        };

    // =====================================================================
    //                       DEPOSITS  (срочные вклады)
    // =====================================================================

    // Серверный калькулятор ставки — единый источник истины
    auto rateForTerm = [](int months) -> double
        {
            if (months < 1)  return 0.0;
            if (months > 12) months = 12;
            double rate;
            if (months <= 3)
                rate = 7.0 + (months - 1) * 1.0;
            else if (months <= 6)
                rate = 9.0 + (months - 3) * (4.0 / 3.0);
            else
                rate = 13.0 + (months - 6) * (2.0 / 6.0);
            return std::round(rate * 100.0) / 100.0;
        };

    m_handlers["getUserDeposits"] = [this, accrueDepositInterest](
        const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int userId = p["userId"].toInt();

            // Сначала доначислим проценты по всем активным
            QSqlQuery q(m_db.database());
            q.prepare("SELECT id FROM deposits WHERE user_id = :uid AND status = 'active'");
            q.bindValue(":uid", userId);
            if (q.exec())
            {
                QList<int> ids;
                while (q.next()) ids << q.value(0).toInt();
                for (int id : ids) accrueDepositInterest(id, tag, userId);
            }

            // Загрузка списка (включая matured)
            q.prepare("SELECT id, principal, current_balance, annual_rate, term_months, "
                "is_replenishable, opened_at, matures_at, total_interest, total_topups, "
                "status, last_interest_date, "
                "(matures_at <= CURRENT_DATE) AS can_claim, "
                "(matures_at - CURRENT_DATE)  AS days_remaining "
                "FROM deposits WHERE user_id = :uid AND status IN ('active','matured') "
                "ORDER BY opened_at DESC");
            q.bindValue(":uid", userId);

            QJsonArray arr;
            if (q.exec())
            {
                while (q.next())
                {
                    QJsonObject d;
                    d["id"] = q.value(0).toInt();
                    d["principal"] = q.value(1).toDouble();
                    d["current_balance"] = q.value(2).toDouble();
                    d["annual_rate"] = q.value(3).toDouble();
                    d["term_months"] = q.value(4).toInt();
                    d["is_replenishable"] = q.value(5).toBool();
                    d["opened_at"] = q.value(6).toDateTime().toString("dd.MM.yyyy");
                    d["matures_at"] = q.value(7).toDate().toString("dd.MM.yyyy");
                    d["total_interest"] = q.value(8).toDouble();
                    d["total_topups"] = q.value(9).toDouble();
                    d["status"] = q.value(10).toString();
                    d["last_interest_date"] = q.value(11).toDate().toString("dd.MM.yyyy");
                    d["can_claim"] = q.value(12).toBool();
                    d["days_remaining"] = q.value(13).toInt();
                    arr.append(d);
                }
            }
            return { {"deposits", arr} };
        };

    m_handlers["getClosedDeposits"] = [this](const QJsonObject& p, const QString&) -> QJsonObject
        {
            int userId = p["userId"].toInt();
            QSqlQuery q(m_db.database());
            q.prepare("SELECT id, principal, current_balance, annual_rate, term_months, "
                "opened_at, matures_at, total_interest, total_topups, closed_at "
                "FROM deposits WHERE user_id = :uid AND status = 'closed' "
                "ORDER BY closed_at DESC");
            q.bindValue(":uid", userId);

            QJsonArray arr;
            if (q.exec())
            {
                while (q.next())
                {
                    QJsonObject d;
                    d["id"] = q.value(0).toInt();
                    d["principal"] = q.value(1).toDouble();
                    d["final_balance"] = q.value(2).toDouble();
                    d["annual_rate"] = q.value(3).toDouble();
                    d["term_months"] = q.value(4).toInt();
                    d["opened_at"] = q.value(5).toDateTime().toString("dd.MM.yyyy");
                    d["matures_at"] = q.value(6).toDate().toString("dd.MM.yyyy");
                    d["total_interest"] = q.value(7).toDouble();
                    d["total_topups"] = q.value(8).toDouble();
                    d["closed_at"] = q.value(9).isNull() ? "" : q.value(9).toDateTime().toString("dd.MM.yyyy");
                    arr.append(d);
                }
            }
            return { {"deposits", arr} };
        };

    m_handlers["openDeposit"] = [this, rateForTerm](const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int    userId = p["userId"].toInt();
            int    fromAccountId = p["fromAccountId"].toInt();
            double amount = p["amount"].toDouble();
            int    months = p["months"].toInt();
            bool   replenishable = p["replenishable"].toBool();

            Logger::instance().userAction(tag, userId,
                QString("Открытие вклада: %1 ₽ на %2 мес., пополняемый=%3")
                .arg(amount).arg(months).arg(replenishable));

            if (amount <= 0)
                return { {"ok", false}, {"error", "Сумма должна быть положительной"} };
            if (months < 1 || months > 12)
                return { {"ok", false}, {"error", "Срок должен быть от 1 до 12 месяцев"} };
            if (amount < 1000)
                return { {"ok", false}, {"error", "Минимальная сумма вклада — 1 000 ₽"} };

            double rate = rateForTerm(months);

            QSqlDatabase db = m_db.database();
            QSqlQuery q(db);

            // Проверка источника
            q.prepare("SELECT balance, user_id FROM accounts WHERE id = :id");
            q.bindValue(":id", fromAccountId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Счёт списания не найден"} };
            if (q.value(1).toInt() != userId)
                return { {"ok", false}, {"error", "Чужой счёт"} };
            if (q.value(0).toDouble() < amount)
                return { {"ok", false}, {"error", "Недостаточно средств"} };

            // Фонд
            q.prepare("SELECT a.id FROM accounts a INNER JOIN users u ON a.user_id = u.id "
                "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_deposit_fund' LIMIT 1");
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Фонд не настроен"} };
            int fundId = q.value(0).toInt();

            QDate today = QDate::currentDate();
            QDate matures = today.addMonths(months);

            db.transaction();

            // Списание
            q.prepare("UPDATE accounts SET balance = balance - :a WHERE id = :id AND balance >= :a");
            q.bindValue(":a", amount); q.bindValue(":id", fromAccountId);
            if (!q.exec() || q.numRowsAffected() == 0)
            {
                db.rollback(); return { {"ok", false}, {"error", "Не удалось списать"} };
            }

            q.prepare("UPDATE accounts SET balance = balance + :a WHERE id = :id");
            q.bindValue(":a", amount); q.bindValue(":id", fundId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка фонда"} }; }

            // Транзакция
            q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                "transaction_type, description, status) "
                "VALUES (:f, :t, :a, 'deposit_open', 'Открытие вклада', 'completed') RETURNING id");
            q.bindValue(":f", fromAccountId); q.bindValue(":t", fundId); q.bindValue(":a", amount);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка транзакции"} };
            }
            int txId = q.value(0).toInt();

            // Запись вклада
            q.prepare("INSERT INTO deposits (user_id, principal, current_balance, annual_rate, "
                "term_months, is_replenishable, matures_at) "
                "VALUES (:uid, :p, :p, :r, :t, :rep, :m) RETURNING id");
            q.bindValue(":uid", userId); q.bindValue(":p", amount); q.bindValue(":r", rate);
            q.bindValue(":t", months);   q.bindValue(":rep", replenishable); q.bindValue(":m", matures);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка создания вклада"} };
            }
            int did = q.value(0).toInt();

            // Журнал
            q.prepare("INSERT INTO deposit_operations "
                "(user_id, deposit_id, operation_type, amount, balance_after, transaction_id, description) "
                "VALUES (:uid, :did, 'deposit_open', :a, :b, :tx, 'Открытие вклада')");
            q.bindValue(":uid", userId); q.bindValue(":did", did);
            q.bindValue(":a", amount);   q.bindValue(":b", amount); q.bindValue(":tx", txId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка журнала"} }; }

            if (!db.commit()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка подтверждения"} }; }
            return { {"ok", true} };
        };

    m_handlers["depositTopUp"] = [this, accrueDepositInterest](
        const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int    userId = p["userId"].toInt();
            int    depositId = p["depositId"].toInt();
            int    fromAccountId = p["fromAccountId"].toInt();
            double amount = p["amount"].toDouble();

            Logger::instance().userAction(tag, userId,
                QString("Пополнение вклада #%1 на %2 ₽").arg(depositId).arg(amount));

            if (amount <= 0)
                return { {"ok", false}, {"error", "Сумма должна быть положительной"} };

            QSqlDatabase db = m_db.database();
            QSqlQuery q(db);

            q.prepare("SELECT user_id, is_replenishable, status FROM deposits WHERE id = :id");
            q.bindValue(":id", depositId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Вклад не найден"} };
            if (q.value(0).toInt() != userId)
                return { {"ok", false}, {"error", "Чужой вклад"} };
            if (!q.value(1).toBool())
                return { {"ok", false}, {"error", "Этот вклад не пополняемый"} };
            if (q.value(2).toString() != "active")
                return { {"ok", false}, {"error", "Вклад не активен"} };

            // Доначислим проценты до сегодня
            accrueDepositInterest(depositId, tag, userId);

            // Источник
            q.prepare("SELECT balance, user_id FROM accounts WHERE id = :id");
            q.bindValue(":id", fromAccountId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Счёт не найден"} };
            if (q.value(1).toInt() != userId)
                return { {"ok", false}, {"error", "Чужой счёт"} };
            if (q.value(0).toDouble() < amount)
                return { {"ok", false}, {"error", "Недостаточно средств"} };

            q.prepare("SELECT a.id FROM accounts a INNER JOIN users u ON a.user_id = u.id "
                "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_deposit_fund' LIMIT 1");
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Фонд не настроен"} };
            int fundId = q.value(0).toInt();

            db.transaction();

            q.prepare("UPDATE accounts SET balance = balance - :a WHERE id = :id AND balance >= :a");
            q.bindValue(":a", amount); q.bindValue(":id", fromAccountId);
            if (!q.exec() || q.numRowsAffected() == 0)
            {
                db.rollback(); return { {"ok", false}, {"error", "Не удалось списать"} };
            }

            q.prepare("UPDATE accounts SET balance = balance + :a WHERE id = :id");
            q.bindValue(":a", amount); q.bindValue(":id", fundId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка фонда"} }; }

            q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                "transaction_type, description, status) "
                "VALUES (:f, :t, :a, 'deposit_topup', 'Пополнение вклада', 'completed') RETURNING id");
            q.bindValue(":f", fromAccountId); q.bindValue(":t", fundId); q.bindValue(":a", amount);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка транзакции"} };
            }
            int txId = q.value(0).toInt();

            q.prepare("UPDATE deposits SET current_balance = current_balance + :a, "
                "total_topups = total_topups + :a WHERE id = :id RETURNING current_balance");
            q.bindValue(":a", amount); q.bindValue(":id", depositId);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка обновления вклада"} };
            }
            double newBalance = q.value(0).toDouble();

            q.prepare("INSERT INTO deposit_operations "
                "(user_id, deposit_id, operation_type, amount, balance_after, transaction_id, description) "
                "VALUES (:uid, :did, 'deposit_topup', :a, :b, :tx, 'Пополнение')");
            q.bindValue(":uid", userId); q.bindValue(":did", depositId);
            q.bindValue(":a", amount);   q.bindValue(":b", newBalance); q.bindValue(":tx", txId);
            if (!q.exec()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка журнала"} }; }

            if (!db.commit()) { db.rollback(); return { {"ok", false}, {"error", "Ошибка подтверждения"} }; }
            return { {"ok", true} };
        };

    m_handlers["claimDeposit"] = [this, accrueDepositInterest](
        const QJsonObject& p, const QString& tag) -> QJsonObject
        {
            int userId = p["userId"].toInt();
            int depositId = p["depositId"].toInt();
            int toAccountId = p["toAccountId"].toInt();

            Logger::instance().userAction(tag, userId,
                QString("Получение вклада #%1").arg(depositId));

            // Доначислим до сегодня (на случай если matured ещё не зафиксирован)
            accrueDepositInterest(depositId, tag, userId);

            QSqlDatabase db = m_db.database();
            QSqlQuery q(db);

            q.prepare("SELECT user_id, current_balance, matures_at, status "
                "FROM deposits WHERE id = :id");
            q.bindValue(":id", depositId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Вклад не найден"}, {"payoutAmount", 0} };

            if (q.value(0).toInt() != userId)
                return { {"ok", false}, {"error", "Чужой вклад"}, {"payoutAmount", 0} };
            double payout = q.value(1).toDouble();
            QDate  matures = q.value(2).toDate();
            QString status = q.value(3).toString();

            if (status == "closed")
                return { {"ok", false}, {"error", "Вклад уже закрыт"}, {"payoutAmount", 0} };
            if (QDate::currentDate() < matures)
                return { {"ok", false}, {"error", "Срок вклада ещё не истёк"}, {"payoutAmount", 0} };

            // Получатель
            q.prepare("SELECT user_id FROM accounts WHERE id = :id");
            q.bindValue(":id", toAccountId);
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Счёт зачисления не найден"}, {"payoutAmount", 0} };
            if (q.value(0).toInt() != userId)
                return { {"ok", false}, {"error", "Чужой счёт"}, {"payoutAmount", 0} };

            q.prepare("SELECT a.id FROM accounts a INNER JOIN users u ON a.user_id = u.id "
                "WHERE u.is_system_user = TRUE AND a.account_type = 'bank_deposit_fund' LIMIT 1");
            if (!q.exec() || !q.next())
                return { {"ok", false}, {"error", "Фонд не настроен"}, {"payoutAmount", 0} };
            int fundId = q.value(0).toInt();

            db.transaction();

            q.prepare("UPDATE accounts SET balance = balance - :a WHERE id = :id AND balance >= :a");
            q.bindValue(":a", payout); q.bindValue(":id", fundId);
            if (!q.exec() || q.numRowsAffected() == 0)
            {
                db.rollback(); return { {"ok", false}, {"error", "Фонд не может выдать"}, {"payoutAmount", 0} };
            }

            q.prepare("UPDATE accounts SET balance = balance + :a WHERE id = :id");
            q.bindValue(":a", payout); q.bindValue(":id", toAccountId);
            if (!q.exec())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка зачисления"}, {"payoutAmount", 0} };
            }

            q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
                "transaction_type, description, status) "
                "VALUES (:f, :t, :a, 'deposit_payout', 'Выплата по вкладу', 'completed') RETURNING id");
            q.bindValue(":f", fundId); q.bindValue(":t", toAccountId); q.bindValue(":a", payout);
            if (!q.exec() || !q.next())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка транзакции"}, {"payoutAmount", 0} };
            }
            int txId = q.value(0).toInt();

            // Не обнуляем current_balance — оно остаётся как финальная сумма выплаты
            // (используется в истории закрытых вкладов)
            q.prepare("UPDATE deposits SET status = 'closed', "
                "closed_at = CURRENT_TIMESTAMP WHERE id = :id");
            q.bindValue(":id", depositId);
            if (!q.exec())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка закрытия"}, {"payoutAmount", 0} };
            }

            q.prepare("INSERT INTO deposit_operations "
                "(user_id, deposit_id, operation_type, amount, balance_after, transaction_id, description) "
                "VALUES (:uid, :did, 'deposit_payout', :a, :a, :tx, 'Выплата по окончании срока')");
            q.bindValue(":uid", userId); q.bindValue(":did", depositId);
            q.bindValue(":a", payout);   q.bindValue(":tx", txId);
            if (!q.exec())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка журнала"}, {"payoutAmount", 0} };
            }

            if (!db.commit())
            {
                db.rollback(); return { {"ok", false}, {"error", "Ошибка подтверждения"}, {"payoutAmount", 0} };
            }

            return { {"ok", true}, {"error", ""}, {"payoutAmount", payout} };
        };


}