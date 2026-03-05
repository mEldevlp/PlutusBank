#include "DatabaseManager.h"
#include <QCryptographicHash>
#include <QDate>
#include <QDebug>

DatabaseManager& DatabaseManager::instance()
{
    static DatabaseManager instance;
    return instance;
}

DatabaseManager::DatabaseManager()
    : m_connected(false)
{
}

DatabaseManager::~DatabaseManager()
{
    disconnect();
}

bool DatabaseManager::connect()
{
    m_db = QSqlDatabase::addDatabase("QPSQL");
    m_db.setHostName("127.0.0.1");
    m_db.setPort(5433);
    m_db.setDatabaseName("plutusbank");
    m_db.setUserName("postgres");
    m_db.setPassword("root");

    qDebug() << u"Попытка подключения к PostgreSQL...";

    if (!m_db.open()) 
    {
        qWarning() << u"Ошибка подключения к БД:" << m_db.lastError().text();
        emit error("Не удалось подключиться к базе данных");
        return false;
    }

    qDebug() << u"Успешное подключение к PostgreSQL";
    m_connected = true;
    emit connected();
    return true;
}

void DatabaseManager::disconnect()
{
    if (m_connected) 
    {
        m_db.close();
        m_connected = false;
        qDebug() << u"Отключено от PostgreSQL";
        emit disconnected();
    }
}

bool DatabaseManager::isConnected() const
{
    return m_connected && m_db.isOpen();
}

QString DatabaseManager::hashPassword(const QString& password)
{
    return QString(QCryptographicHash::hash(password.toUtf8(), QCryptographicHash::Sha256).toHex());
}

bool DatabaseManager::verifyPassword(const QString& password, const QString& hash)
{
    return hashPassword(password) == hash;
}

bool DatabaseManager::registerUser(
    const QString& firstName,
    const QString& lastName,
    const QString& middleName,
    const QString& dateOfBirth,
    const QString& passportSeries,
    const QString& passportNumber,
    const QString& email,
    const QString& phone,
    const QString& password)
{
    QSqlQuery query(m_db);

    query.prepare(
        "INSERT INTO users ("
        "first_name, last_name, middle_name, "
        "date_of_birth, passport_series, passport_number, "
        "email, phone, password_hash"
        ") VALUES ("
        ":firstName, :lastName, :middleName, "
        ":dateOfBirth, :passportSeries, :passportNumber, "
        ":email, :phone, :password"
        ")"
    );

    query.bindValue(":firstName", firstName);
    query.bindValue(":lastName", lastName);
    query.bindValue(":middleName", middleName.isEmpty() ? QVariant(QVariant::String) : middleName);
    query.bindValue(":dateOfBirth", dateOfBirth);
    query.bindValue(":passportSeries", passportSeries);
    query.bindValue(":passportNumber", passportNumber);
    query.bindValue(":email", email);
    query.bindValue(":phone", phone);
    query.bindValue(":password", hashPassword(password));

    if (!query.exec()) 
    {
        qWarning() << u"Ошибка регистрации:" << query.lastError().text();
        emit error("Ошибка регистрации пользователя");
        return false;
    }

    qDebug() << u"Пользователь зарегистрирован:" << firstName << lastName << email;
    return true;
}

int DatabaseManager::loginUser(const QString& phone, const QString& password)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT id, password_hash FROM users WHERE phone = :phone");
    query.bindValue(":phone", phone);

    if (!query.exec() || !query.next()) 
    {
        emit error("Неверный номер телефона или пароль");
        return -1;  // -1 означает ошибку
    }

    int userId = query.value(0).toInt();
    QString storedHash = query.value(1).toString();

    if (!verifyPassword(password, storedHash)) 
    {
        emit error("Неверный номер телефона или пароль");
        return -1;
    }

    qDebug() << u"Успешный вход. User ID:" << userId;
    return userId;
}

QVariantMap DatabaseManager::getUserData(int userId)
{
    QVariantMap userData;
    QSqlQuery query(m_db);

    query.prepare(
        "SELECT first_name, last_name, middle_name, email, phone, "
        "passport_series, passport_number, date_of_birth, "
        "COALESCE(address, ''), COALESCE(primary_account_id, -1) "
        "FROM users WHERE id = :userId"
    );
    query.bindValue(":userId", userId);

    if (query.exec() && query.next()) 
    {
        userData["first_name"] = query.value(0).toString();
        userData["last_name"] = query.value(1).toString();
        userData["middle_name"] = query.value(2).toString();
        userData["email"] = query.value(3).toString();
        userData["phone"] = query.value(4).toString();
        userData["passport_series"] = query.value(5).toString();
        userData["passport_number"] = query.value(6).toString();
        userData["date_of_birth"] = query.value(7).toDate().toString("dd.MM.yyyy");
        userData["address"] = query.value(8).toString();
        userData["primary_account_id"] = query.value(9).toInt();
    }
    else 
    {
        qWarning() << u"Ошибка загрузки данных пользователя:" << query.lastError().text();
    }

    return userData;
}

int DatabaseManager::getUserAccountId(int userId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT id FROM accounts WHERE user_id = :userId LIMIT 1");
    query.bindValue(":userId", userId);

    if (query.exec() && query.next())
    {
        return query.value(0).toInt();
    }

    return -1;
}

QVariantList DatabaseManager::getUserCards(int userId)
{
    QVariantList cards;

    QSqlQuery query;
    query.prepare(
        "SELECT c.id, c.card_number, c.card_holder_name, c.card_type, "
        "c.card_brand, c.is_active, c.is_blocked, c.expiry_date, "
        "c.daily_limit, c.monthly_limit, a.balance, "
        "a.id AS account_id, a.account_number "
        "FROM cards c "
        "INNER JOIN accounts a ON c.account_id = a.id "
        "WHERE a.user_id = :userId "
        "ORDER BY c.created_at DESC"
    );

    query.bindValue(":userId", userId);

    if (query.exec()) 
    {
        while (query.next()) 
        {
            QVariantMap card;
            card["id"] = query.value(0).toInt();
            card["card_number"] = query.value(1).toString();
            card["card_holder_name"] = query.value(2).toString();
            card["card_type"] = query.value(3).toString();
            card["card_brand"] = query.value(4).toString();
            card["is_active"] = query.value(5).toBool();
            card["is_blocked"] = query.value(6).toBool();
            card["expiry_date"] = query.value(7).toDate().toString("MM/yy");
            card["daily_limit"] = query.value(8).toDouble();
            card["monthly_limit"] = query.value(9).toDouble();
            card["balance"] = query.value(10).toDouble();
            card["account_id"] = query.value(11).toInt();
            card["account_number"] = query.value(12).toString();

            cards.append(card);
        }
        qDebug() << "Загружено карт:" << cards.size();
    }
    else 
    {
        qWarning() << "Ошибка загрузки карт:" << query.lastError().text();
    }

    return cards;
}

double DatabaseManager::getTotalDebitBalance(int userId)
{
    QSqlQuery query(m_db);

    query.prepare(
        "SELECT COALESCE(SUM(balance), 0) "
        "FROM accounts "
        "WHERE user_id = :userId AND account_type = 'debit'"
    );
    query.bindValue(":userId", userId);

    if (query.exec() && query.next())
    {
        double totalBalance = query.value(0).toDouble();
        qDebug() << u"Общий баланс дебетовых счетов:" << totalBalance;
        return totalBalance;
    }

    qWarning() << u"Ошибка получения баланса:" << query.lastError().text();
    return 0.0;
}

QVariantList DatabaseManager::getUserAccounts(int userId)
{
    QVariantList accounts;
    QSqlQuery query(m_db);
    query.prepare("SELECT id, account_number, balance, account_type FROM accounts WHERE user_id = :userId");
    query.bindValue(":userId", userId);

    if (query.exec()) {
        while (query.next()) {
            QVariantMap account;
            account["id"] = query.value(0).toInt();
            account["number"] = query.value(1).toString();
            account["balance"] = query.value(2).toDouble();
            account["type"] = query.value(3).toString();
            accounts.append(account);
        }
    }

    return accounts;
}

double DatabaseManager::getAccountBalance(int accountId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT balance FROM accounts WHERE id = :accountId");
    query.bindValue(":accountId", accountId);

    if (query.exec() && query.next()) {
        return query.value(0).toDouble();
    }

    return 0.0;
}

double DatabaseManager::getDailyIncome(int userId)
{
    QSqlQuery query(m_db);
    query.prepare(
        "SELECT COALESCE(SUM(t.amount), 0) "
        "FROM transactions t "
        "INNER JOIN accounts a ON t.to_account_id = a.id "
        "WHERE a.user_id = :userId "
        "  AND t.status = 'completed' "
        "  AND t.created_at >= CURRENT_DATE "
        "  AND (t.from_account_id IS NULL "
        "       OR t.from_account_id NOT IN (SELECT id FROM accounts WHERE user_id = :userId2))"
    );
    query.bindValue(":userId", userId);
    query.bindValue(":userId2", userId);

    if (query.exec() && query.next()) 
    {
        return query.value(0).toDouble();
    }

    qWarning() << u"Ошибка получения дохода за сутки:" << query.lastError().text();
    return 0.0;
}

double DatabaseManager::getDailyExpense(int userId)
{
    QSqlQuery query(m_db);
    query.prepare(
        "SELECT COALESCE(SUM(t.amount), 0) "
        "FROM transactions t "
        "INNER JOIN accounts a ON t.from_account_id = a.id "
        "WHERE a.user_id = :userId "
        "  AND t.status = 'completed' "
        "  AND t.created_at >= CURRENT_DATE "
        "  AND (t.to_account_id IS NULL "
        "       OR t.to_account_id NOT IN (SELECT id FROM accounts WHERE user_id = :userId2))"
    );
    query.bindValue(":userId", userId);
    query.bindValue(":userId2", userId);

    if (query.exec() && query.next()) 
    {
        return query.value(0).toDouble();
    }

    qWarning() << u"Ошибка получения расхода за сутки:" << query.lastError().text();
    return 0.0;
}

QVariantList DatabaseManager::getTransactionHistory(int userId, int limit, int offset)
{
    QVariantList history;
    QSqlQuery query(m_db);

    // Получаем все транзакции, где пользователь отправитель или получатель
    query.prepare(
        "SELECT t.id, t.amount, t.transaction_type, t.description, t.status, t.created_at, "
        "       t.from_account_id, t.to_account_id, "
        "       fa.account_number AS from_account, "
        "       ta.account_number AS to_account, "
        "       fu.last_name || ' ' || LEFT(fu.first_name, 1) || '.' AS from_name, "
        "       tu.last_name || ' ' || LEFT(tu.first_name, 1) || '.' AS to_name, "
        "       fc.card_number AS from_card, "
        "       tc.card_number AS to_card "
        "FROM transactions t "
        "LEFT JOIN accounts fa ON t.from_account_id = fa.id "
        "LEFT JOIN accounts ta ON t.to_account_id = ta.id "
        "LEFT JOIN users fu ON fa.user_id = fu.id "
        "LEFT JOIN users tu ON ta.user_id = tu.id "
        "LEFT JOIN cards fc ON fc.account_id = fa.id "
        "LEFT JOIN cards tc ON tc.account_id = ta.id "
        "WHERE fa.user_id = :userId1 OR ta.user_id = :userId2 "
        "ORDER BY t.created_at DESC "
        "LIMIT :limit OFFSET :offset"
    );

    query.bindValue(":userId1", userId);
    query.bindValue(":userId2", userId);
    query.bindValue(":limit", limit);
    query.bindValue(":offset", offset);

    if (query.exec()) 
    {
        while (query.next()) 
        {
            QVariantMap item;
            item["id"] = query.value(0).toInt();
            item["amount"] = query.value(1).toDouble();
            item["transaction_type"] = query.value(2).toString();
            item["description"] = query.value(3).toString();
            item["status"] = query.value(4).toString();
            item["created_at"] = query.value(5).toDateTime().toString("dd.MM.yyyy HH:mm");
            item["date_group"] = query.value(5).toDateTime().toString("dd.MM.yyyy");

            int fromAccountId = query.value(6).toInt();
            int toAccountId = query.value(7).toInt();

            // Определяем направление относительно текущего пользователя
            // Проверяем, является ли from_account нашим
            QSqlQuery checkFrom(m_db);
            checkFrom.prepare("SELECT user_id FROM accounts WHERE id = :id");
            checkFrom.bindValue(":id", fromAccountId);
            bool isOutgoing = false;

            if (checkFrom.exec() && checkFrom.next()) 
            {
                isOutgoing = (checkFrom.value(0).toInt() == userId);
            }

            // Проверяем, является ли to_account тоже нашим (внутренний перевод)
            QSqlQuery checkTo(m_db);
            checkTo.prepare("SELECT user_id FROM accounts WHERE id = :id");
            checkTo.bindValue(":id", toAccountId);
            bool isIncoming = false;

            if (checkTo.exec() && checkTo.next()) 
            {
                isIncoming = (checkTo.value(0).toInt() == userId);
            }

            if (isOutgoing && isIncoming) 
            {
                item["direction"] = "self";   // перевод между своими счетами
            }
            else if (isOutgoing) 
            {
                item["direction"] = "out";
            }
            else 
            {
                item["direction"] = "in";
            }

            item["from_name"] = query.value(10).toString();
            item["to_name"] = query.value(11).toString();

            // Последние 4 цифры карт
            QString fromCard = query.value(12).toString();
            QString toCard = query.value(13).toString();
            item["from_card_last4"] = fromCard.isEmpty() ? "" : fromCard.right(4);
            item["to_card_last4"] = toCard.isEmpty() ? "" : toCard.right(4);

            history.append(item);
        }
        qDebug() << u"Загружено транзакций:" << history.size();
    }
    else 
    {
        qWarning() << u"Ошибка загрузки истории:" << query.lastError().text();
    }

    return history;
}

int DatabaseManager::createAccount(int userId, const QString& accountType)
{
    QSqlQuery query(m_db);

    // Генерируем номер счёта (20 цифр)
    QString accountNumber = "40817810";  // Префикс для физлиц РФ
    for (int i = 0; i < 12; i++) 
    {
        accountNumber += QString::number(QRandomGenerator::global()->bounded(10));
    }

    // Определяем начальный баланс
    double initialBalance = 0.0;
    if (accountType == "credit") 
    {
        initialBalance = 50000.0;  // Кредитный лимит (потом уберу хардкод)
    }

    query.prepare(
        "INSERT INTO accounts (user_id, account_number, balance, account_type) "
        "VALUES (:userId, :accountNumber, :balance, :accountType) "
        "RETURNING id"
    );

    query.bindValue(":userId", userId);
    query.bindValue(":accountNumber", accountNumber);
    query.bindValue(":balance", initialBalance);
    query.bindValue(":accountType", accountType);

    if (!query.exec() || !query.next()) 
    {
        qWarning() << u"Ошибка создания счёта:" << query.lastError().text();
        return -1;
    }

    int accountId = query.value(0).toInt();
    qDebug() << u"Счёт создан:" << accountNumber << "ID:" << accountId;

    return accountId;
}

QString DatabaseManager::generateCardNumber(const QString& brand)
{
    QSqlQuery query(m_db);

    // Вызываем PostgreSQL функцию generate_valid_card_number
    query.prepare("SELECT generate_valid_card_number(:brand)");
    query.bindValue(":brand", brand);

    if (!query.exec() || !query.next()) 
    {
        qWarning() << u"Ошибка генерации номера карты:" << query.lastError().text();
        return QString();
    }

    QString cardNumber = query.value(0).toString();
    qDebug() << u"Сгенерирован номер карты:" << cardNumber;

    return cardNumber;
}

bool DatabaseManager::createCard(
    int accountId,
    const QString& cardNumber,
    const QString& cardHolderName,
    const QDate& expiryDate,
    const QString& cvcHash,
    const QString& pinHash,
    const QString& cardType,
    const QString& cardBrand)
{
    QSqlQuery query(m_db);

    query.prepare(
        "INSERT INTO cards ("
        "account_id, card_number, card_holder_name, expiry_date, "
        "cvv_hash, pin_hash, card_type, card_brand, "
        "is_active, is_blocked, daily_limit, monthly_limit"
        ") VALUES ("
        ":accountId, :cardNumber, :cardHolderName, :expiryDate, "
        ":cvcHash, :pinHash, :cardType, :cardBrand, "
        "true, false, 100000.00, 500000.00"
        ")"
    );

    query.bindValue(":accountId", accountId);
    query.bindValue(":cardNumber", cardNumber);
    query.bindValue(":cardHolderName", cardHolderName);
    query.bindValue(":expiryDate", expiryDate);
    query.bindValue(":cvcHash", cvcHash);
    query.bindValue(":pinHash", pinHash);
    query.bindValue(":cardType", cardType);
    query.bindValue(":cardBrand", cardBrand);

    if (!query.exec()) 
    {
        qWarning() << u"Ошибка создания карты:" << query.lastError().text();
        return false;
    }

    qDebug() << u"Карта создана в БД";
    return true;
}

bool DatabaseManager::transferBetweenAccounts(int fromAccountId, int toAccountId, double amount)
{
    if (fromAccountId == toAccountId)
    {
        emit error("Нельзя переводить на тот же счёт");
        return false;
    }

    QSqlQuery query(m_db);

    // Начинаем транзакцию
    m_db.transaction();

    // Проверяем баланс отправителя
    query.prepare("SELECT balance FROM accounts WHERE id = :id FOR UPDATE");
    query.bindValue(":id", fromAccountId);

    if (!query.exec() || !query.next()) 
    {
        m_db.rollback();
        emit error("Счёт отправителя не найден");
        return false;
    }

    double balance = query.value(0).toDouble();
    if (balance < amount)
    {
        m_db.rollback();
        emit error("Недостаточно средств");
        return false;
    }

    // Проверяем существование счёта получателя
    query.prepare("SELECT id FROM accounts WHERE id = :id FOR UPDATE");
    query.bindValue(":id", toAccountId);

    if (!query.exec() || !query.next())
    {
        m_db.rollback();
        emit error("Счёт получателя не найден");
        return false;
    }

    // Списание
    query.prepare("UPDATE accounts SET balance = balance - :amount WHERE id = :id");
    query.bindValue(":amount", amount);
    query.bindValue(":id", fromAccountId);

    if (!query.exec())
    {
        m_db.rollback();
        qWarning() << u"Ошибка списания:" << query.lastError().text();
        return false;
    }

    // Зачисление
    query.prepare("UPDATE accounts SET balance = balance + :amount WHERE id = :id");
    query.bindValue(":amount", amount);
    query.bindValue(":id", toAccountId);

    if (!query.exec())
    {
        m_db.rollback();
        qWarning() << u"Ошибка зачисления:" << query.lastError().text();
        return false;
    }

    // Определяем тип перевода
    QSqlQuery typeQuery(m_db);
    typeQuery.prepare(
        "SELECT (SELECT user_id FROM accounts WHERE id = :from) = "
        "(SELECT user_id FROM accounts WHERE id = :to)"
    );
    typeQuery.bindValue(":from", fromAccountId);
    typeQuery.bindValue(":to", toAccountId);
    typeQuery.exec();
    typeQuery.next();
    bool isInternal = typeQuery.value(0).toBool();

    // Запись транзакции
    query.prepare(
        "INSERT INTO transactions (from_account_id, to_account_id, amount, transaction_type, status) "
        "VALUES (:from, :to, :amount, :type, 'completed')"
    );
    query.bindValue(":from", fromAccountId);
    query.bindValue(":to", toAccountId);
    query.bindValue(":amount", amount);
    query.bindValue(":type", isInternal ? "internal" : "external");

    if (!query.exec())
    {
        m_db.rollback();
        qWarning() << u"Ошибка записи транзакции:" << query.lastError().text();
        return false;
    }

    if (!m_db.commit())
    {
        m_db.rollback();
        qWarning() << u"Ошибка коммита:" << m_db.lastError().text();
        return false;
    }

    qDebug() << u"Перевод выполнен:" << amount << u"со счёта" << fromAccountId << u"на счёт" << toAccountId;
    return true;
}

int DatabaseManager::findAccountByPhone(const QString& phone, const QString& accountType)
{
    QSqlQuery query(m_db);

    // Сначала пробуем primary_account_id
    query.prepare(
        "SELECT u.primary_account_id FROM users u "
        "WHERE u.phone = :phone AND u.primary_account_id IS NOT NULL"
    );
    query.bindValue(":phone", phone);

    if (query.exec() && query.next()) 
    {
        int primaryId = query.value(0).toInt();
        if (primaryId > 0)
            return primaryId;
    }

    // Фолбэк: первый дебетовый счёт
    query.prepare(
        "SELECT a.id FROM accounts a "
        "INNER JOIN users u ON a.user_id = u.id "
        "WHERE u.phone = :phone AND a.account_type = :type "
        "ORDER BY a.created_at ASC LIMIT 1"
    );
    query.bindValue(":phone", phone);
    query.bindValue(":type", accountType);

    if (query.exec() && query.next())
        return query.value(0).toInt();

    return -1;
}

bool DatabaseManager::transferToUser(int fromAccountId, const QString& recipientPhone, double amount)
{
    int toAccountId = findAccountByPhone(recipientPhone, "debit");
    if (toAccountId <= 0)
    {
        emit error("Получатель с таким номером не найден или у него нет дебетового счёта");
        return false;
    }

    // Проверяем, что не переводим самому себе на тот же счёт
    return transferBetweenAccounts(fromAccountId, toAccountId, amount);
}

QString DatabaseManager::getAccountOwnerName(int accountId)
{
    QSqlQuery query(m_db);
    query.prepare(
        "SELECT u.last_name || ' ' || u.first_name "
        "FROM users u INNER JOIN accounts a ON a.user_id = u.id "
        "WHERE a.id = :id"
    );
    query.bindValue(":id", accountId);

    if (query.exec() && query.next())
    {
        return query.value(0).toString();
    }

    return "";
}

QVariantList DatabaseManager::getUserDebitAccounts(int userId)
{
    QVariantList accounts;
    QSqlQuery query(m_db);
    query.prepare(
        "SELECT a.id, a.account_number, a.balance, a.account_type, "
        "c.card_number, c.card_brand, c.is_active, c.is_blocked "
        "FROM accounts a "
        "LEFT JOIN cards c ON c.account_id = a.id "
        "WHERE a.user_id = :userId AND a.account_type = 'debit' "
        "ORDER BY a.account_type, a.created_at"
    );
    query.bindValue(":userId", userId);

    if (query.exec())
    {
        while (query.next())
        {
            QVariantMap acc;
            acc["id"] = query.value(0).toInt();
            acc["account_number"] = query.value(1).toString();
            acc["balance"] = query.value(2).toDouble();
            acc["account_type"] = query.value(3).toString();
            acc["card_number"] = query.value(4).toString();
            acc["card_brand"] = query.value(5).toString();
            acc["is_active"] = query.value(6).toBool();
            acc["is_blocked"] = query.value(7).toBool();
            accounts.append(acc);
        }
    }

    return accounts;
}

bool DatabaseManager::blockCard(int cardId)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE cards SET is_blocked = true, is_active = false WHERE id = :id");
    query.bindValue(":id", cardId);

    if (!query.exec()) 
    {
        qWarning() << u"Ошибка блокировки карты:" << query.lastError().text();
        return false;
    }

    qDebug() << u"Карта заблокирована. ID:" << cardId;
    return true;
}

bool DatabaseManager::freezeCard(int cardId)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE cards SET is_active = NOT is_active WHERE id = :id RETURNING is_active");
    query.bindValue(":id", cardId);

    if (!query.exec() || !query.next()) 
    {
        qWarning() << u"Ошибка заморозки карты:" << query.lastError().text();
        return false;
    }

    bool newState = query.value(0).toBool();
    qDebug() << u"Карта" << (newState ? "разморожена" : "заморожена") << "ID:" << cardId;
    return true;
}

bool DatabaseManager::unfreezeCard(int cardId)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE cards SET is_active = true WHERE id = :id");
    query.bindValue(":id", cardId);

    if (!query.exec()) 
    {
        qWarning() << u"Ошибка разморозки карты:" << query.lastError().text();
        return false;
    }

    return true;
}

QVariantMap DatabaseManager::getCardFullDetails(int cardId)
{
    QVariantMap details;
    QSqlQuery query(m_db);
    query.prepare(
        "SELECT c.id, c.card_number, c.card_holder_name, c.card_type, "
        "c.card_brand, c.is_active, c.is_blocked, c.expiry_date, "
        "c.daily_limit, c.monthly_limit, a.balance, a.id AS account_id, "
        "a.account_number "
        "FROM cards c "
        "INNER JOIN accounts a ON c.account_id = a.id "
        "WHERE c.id = :cardId"
    );
    query.bindValue(":cardId", cardId);

    if (query.exec() && query.next()) {
        details["id"] = query.value(0).toInt();
        details["card_number"] = query.value(1).toString();
        details["card_holder_name"] = query.value(2).toString();
        details["card_type"] = query.value(3).toString();
        details["card_brand"] = query.value(4).toString();
        details["is_active"] = query.value(5).toBool();
        details["is_blocked"] = query.value(6).toBool();
        details["expiry_date"] = query.value(7).toDate().toString("MM/yy");
        details["daily_limit"] = query.value(8).toDouble();
        details["monthly_limit"] = query.value(9).toDouble();
        details["balance"] = query.value(10).toDouble();
        details["account_id"] = query.value(11).toInt();
        details["account_number"] = query.value(12).toString();
    }
    return details;
}

QVariantList DatabaseManager::getCardTransactions(int accountId, int limit, int offset)
{
    QVariantList history;
    QSqlQuery query(m_db);

    query.prepare(
        "SELECT t.id, t.amount, t.transaction_type, t.description, t.status, t.created_at, "
        "       t.from_account_id, t.to_account_id, "
        "       fu.last_name || ' ' || LEFT(fu.first_name, 1) || '.' AS from_name, "
        "       tu.last_name || ' ' || LEFT(tu.first_name, 1) || '.' AS to_name, "
        "       fc.card_number AS from_card, "
        "       tc.card_number AS to_card "
        "FROM transactions t "
        "LEFT JOIN accounts fa ON t.from_account_id = fa.id "
        "LEFT JOIN accounts ta ON t.to_account_id = ta.id "
        "LEFT JOIN users fu ON fa.user_id = fu.id "
        "LEFT JOIN users tu ON ta.user_id = tu.id "
        "LEFT JOIN cards fc ON fc.account_id = fa.id "
        "LEFT JOIN cards tc ON tc.account_id = ta.id "
        "WHERE t.from_account_id = :accId1 OR t.to_account_id = :accId2 "
        "ORDER BY t.created_at DESC "
        "LIMIT :limit OFFSET :offset"
    );

    query.bindValue(":accId1", accountId);
    query.bindValue(":accId2", accountId);
    query.bindValue(":limit", limit);
    query.bindValue(":offset", offset);

    if (query.exec()) 
    {
        while (query.next()) 
        {
            QVariantMap item;
            item["id"] = query.value(0).toInt();
            item["amount"] = query.value(1).toDouble();
            item["transaction_type"] = query.value(2).toString();
            item["description"] = query.value(3).toString();
            item["status"] = query.value(4).toString();
            item["created_at"] = query.value(5).toDateTime().toString("dd.MM.yyyy HH:mm");
            item["date_group"] = query.value(5).toDateTime().toString("dd.MM.yyyy");

            int fromAccId = query.value(6).toInt();
            bool isOutgoing = (fromAccId == accountId);

            item["direction"] = isOutgoing ? "out" : "in";
            item["from_name"] = query.value(8).toString();
            item["to_name"] = query.value(9).toString();

            QString fromCard = query.value(10).toString();
            QString toCard = query.value(11).toString();
            item["from_card_last4"] = fromCard.isEmpty() ? "" : fromCard.right(4);
            item["to_card_last4"] = toCard.isEmpty() ? "" : toCard.right(4);

            history.append(item);
        }
    }
    return history;
}

bool DatabaseManager::isAccountFrozenOrBlocked(int accountId)
{
    QSqlQuery query(m_db);
    query.prepare(
        "SELECT c.is_active, c.is_blocked FROM cards c "
        "WHERE c.account_id = :accountId LIMIT 1"
    );
    query.bindValue(":accountId", accountId);

    if (query.exec() && query.next()) 
    {
        bool isActive = query.value(0).toBool();
        bool isBlocked = query.value(1).toBool();
        return isBlocked || !isActive;
    }
    return false;
}

bool DatabaseManager::topUpAccount(int accountId, double amount)
{
    if (amount <= 0) 
    {
        emit error("Сумма должна быть больше нуля");
        return false;
    }

    QSqlQuery query(m_db);
    m_db.transaction();

    // Проверяем существование счёта
    query.prepare("SELECT id FROM accounts WHERE id = :id FOR UPDATE");
    query.bindValue(":id", accountId);

    if (!query.exec() || !query.next()) 
    {
        m_db.rollback();
        emit error("Счёт не найден");
        return false;
    }

    // Зачисление
    query.prepare("UPDATE accounts SET balance = balance + :amount WHERE id = :id");
    query.bindValue(":amount", amount);
    query.bindValue(":id", accountId);

    if (!query.exec()) 
    {
        m_db.rollback();
        qWarning() << u"Ошибка зачисления:" << query.lastError().text();
        return false;
    }

    // Запись транзакции (деньги из воздуха)
    query.prepare(
        "INSERT INTO transactions (from_account_id, to_account_id, amount, transaction_type, description, status) "
        "VALUES (NULL, :to, :amount, 'external', :desc, 'completed')"
    );
    query.bindValue(":to", accountId);
    query.bindValue(":amount", amount);
    query.bindValue(":desc", QString(u"Пополнение счёта"));

    if (!query.exec())
    {
        m_db.rollback();
        qWarning() << u"Ошибка записи транзакции:" << query.lastError().text();
        return false;
    }

    if (!m_db.commit())
    {
        m_db.rollback();
        return false;
    }

    qDebug() << u"Пополнение:" << amount << u"на счёт" << accountId;
    return true;
}

// установить основной счёт
bool DatabaseManager::setPrimaryAccount(int userId, int accountId)
{
    QSqlQuery query(m_db);
    query.prepare(
        "UPDATE users SET primary_account_id = :accountId WHERE id = :userId"
    );
    query.bindValue(":accountId", accountId);
    query.bindValue(":userId", userId);

    if (!query.exec()) 
    {
        qWarning() << u"Ошибка установки основного счёта:" << query.lastError().text();
        emit error("Не удалось назначить основной счёт");
        return false;
    }
    return true;
}

// получить id основного счёта
int DatabaseManager::getPrimaryAccountId(int userId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT primary_account_id FROM users WHERE id = :userId");
    query.bindValue(":userId", userId);

    if (query.exec() && query.next() && !query.value(0).isNull())
        return query.value(0).toInt();

    return -1;
}