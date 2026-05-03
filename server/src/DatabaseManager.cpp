#include "DatabaseManager.h"


DatabaseManager& DatabaseManager::instance()
{
    static DatabaseManager instance;
    return instance;
}

DatabaseManager::DatabaseManager()
    : m_connected(false)
{}

DatabaseManager::~DatabaseManager()
{
    disconnect();
}

void DatabaseManager::setConnectionParams(const QString& driver, const QString& host, int port,
    const QString& dbName, const QString& user, const QString& password)
{
    m_driver = driver;
    m_host = host;
    m_port = port;
    m_dbName = dbName;
    m_user = user;
    m_password = password;
}

bool DatabaseManager::connect()
{
    m_db = QSqlDatabase::addDatabase(m_driver);
    m_db.setHostName(m_host);
    m_db.setPort(m_port);
    m_db.setDatabaseName(m_dbName);
    m_db.setUserName(m_user);
    m_db.setPassword(m_password);

    Logger::instance().info(QString("Подключение к %1 : %2 / %3").arg(m_host).arg(m_port).arg(m_dbName));

    if (!m_db.open())
    {
        qWarning() << "" << m_db.lastError().text();
        Logger::instance().warning("Ошибка подключения к БД: ");
        return false;
    }

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
        Logger::instance().info("Отключено от PostgreSQL");
        emit disconnected();
    }
}

bool DatabaseManager::isConnected() const
{
    return m_connected && m_db.isOpen();
}

QString DatabaseManager::hashPassword(const QString& password)
{
    QByteArray salt(16, Qt::Uninitialized);
    for (int i = 0; i < salt.size(); ++i)
        salt[i] = static_cast<char>(QRandomGenerator::global()->bounded(256));

    QByteArray salted = salt + password.toUtf8();
    QByteArray hash = QCryptographicHash::hash(salted, QCryptographicHash::Sha256);

    return salt.toHex() + ':' + hash.toHex();
}

bool DatabaseManager::verifyPassword(const QString& password, const QString& stored)
{
    auto parts = stored.split(':');

    if (parts.size() == 2) {
        QByteArray salt = QByteArray::fromHex(parts[0].toUtf8());
        QByteArray expectedHash = QByteArray::fromHex(parts[1].toUtf8());
        QByteArray actual = QCryptographicHash::hash(salt + password.toUtf8(), QCryptographicHash::Sha256);
        return actual == expectedHash;
    }

    // голый SHA-256 без соли
    QByteArray oldHash = QCryptographicHash::hash(password.toUtf8(), QCryptographicHash::Sha256).toHex();
    return stored == QString::fromLatin1(oldHash);
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
    query.bindValue(":middleName", middleName.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : middleName);
    query.bindValue(":dateOfBirth", dateOfBirth);
    query.bindValue(":passportSeries", passportSeries);
    query.bindValue(":passportNumber", passportNumber);
    query.bindValue(":email", email);
    query.bindValue(":phone", phone);
    query.bindValue(":password", hashPassword(password));

    if (!query.exec())
    {
        Logger::instance().warning(QString("Ошибка регистрации:").arg(query.lastError().text()));
        emit error("Ошибка регистрации пользователя");
        return false;
    }

    Logger::instance().info(
        QString("Пользователь зарегистрирован: %1 %2 %3").arg(firstName).arg(lastName).arg(email));

    return true;
}

int DatabaseManager::loginUser(const QString& phone, const QString& password)
{
    // Принудительно сбрасываем все подготовленные операции
    m_db.exec("DEALLOCATE ALL");

    int userId = -1;
    QString storedHash;

    {
        QSqlQuery query(m_db);
        query.setForwardOnly(true);
        query.prepare("SELECT id, password_hash FROM users WHERE phone = :phone");
        query.bindValue(":phone", phone);

        if (!query.exec() || !query.next())
        {
            emit error("Неверный номер телефона или пароль");
            return -1;
        }

        userId = query.value(0).toInt();
        storedHash = query.value(1).toString();
        query.clear();
    }

    qDebug() << "LOGIN DEBUG: userId=" << userId << "storedHash=" << storedHash.left(20) << "...";

    if (!verifyPassword(password, storedHash))
    {
        qDebug() << "LOGIN DEBUG: verifyPassword FAILED";
        emit error("Неверный номер телефона или пароль");
        return -1;
    }

    // миграция старого хэша
    if (!storedHash.contains(':'))
    {
        m_db.exec("DEALLOCATE ALL");
        QSqlQuery update(m_db);
        update.setForwardOnly(true);
        update.prepare("UPDATE users SET password_hash = :newHash WHERE id = :id");
        update.bindValue(":newHash", hashPassword(password));
        update.bindValue(":id", userId);
        update.exec();
        update.clear();
    }

    //qDebug() << u"Успешный вход. User ID:" << userId;
    return userId;
}

QVariantMap DatabaseManager::getUserData(int userId)
{
    QVariantMap userData;

    m_db.exec("DEALLOCATE ALL");

    QSqlQuery query(m_db);
    query.setForwardOnly(true);

    query.prepare(
        "SELECT first_name, last_name, middle_name, email, phone, "
        "passport_series, passport_number, date_of_birth, "
        "address, primary_account_id "
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
        //qWarning() << u"Ошибка загрузки данных пользователя:" << query.lastError().text();
    }

    query.clear();

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
        
        Logger::instance().info(
            QString("Загружено карт: %1").arg(cards.size()));
    }
    else
    {
        Logger::instance().warning("Ошибка загрузки карт: %1", query.lastError().text());
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
        Logger::instance().info(QString("Общий баланс дебетовых счетов: %1").arg(totalBalance));
        return totalBalance;
    }

    Logger::instance().warning(
        QString("Ошибка получения баланса: %1").arg(query.lastError().text()));

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

    if (query.exec() && query.next())
    {
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

    Logger::instance().warning(
        QString("Ошибка получения дохода за сутки: %1").arg(query.lastError().text()));

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

    Logger::instance().info(QString("Ошибка получения расхода за сутки:").arg(query.lastError().text()));

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
                item["direction"] = "self";   // между своими счетами
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

        Logger::instance().info(QString("Загружено транзакций: %1").arg(history.size()));
    }
    else
    {
        Logger::instance().warning(
            QString("Ошибка загрузки истории:").arg(query.lastError().text()));
    }

    return history;
}

int DatabaseManager::createAccount(int userId, const QString& accountType)
{
    QSqlQuery query(m_db);

    // Генерируем номер счёта (20 цифр)
    QString accountNumber = "40817810";  // Префикс для РФ
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
    
        Logger::instance().warning(
            QString("Ошибка создания счёта: %1").arg(query.lastError().text()));
        return -1;
    }

    int accountId = query.value(0).toInt();

    Logger::instance().info(
        QString("Счёт создан: %1 ID: %2").arg(accountNumber).arg(accountId));

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
        Logger::instance().warning(
            QString("Ошибка генерации номера карты: %1").arg(query.lastError().text()));

        return QString();
    }

    QString cardNumber = query.value(0).toString();
    Logger::instance().info(QString("Сгенерирован номер карты: %1").arg(cardNumber));
    
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
        Logger::instance().warning(
            QString("Ошибка создания карты: %1").arg(query.lastError().text()));
        return false;
    }

    Logger::instance().info("Карта создана в БД");
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

        Logger::instance().warning(
            QString("Ошибка списания: %1").arg(query.lastError().text()));

        return false;
    }

    // Зачисление
    query.prepare("UPDATE accounts SET balance = balance + :amount WHERE id = :id");
    query.bindValue(":amount", amount);
    query.bindValue(":id", toAccountId);

    if (!query.exec())
    {
        m_db.rollback();

        Logger::instance().warning(
            QString("Ошибка зачисления: %1").arg(query.lastError().text()));

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
        Logger::instance().warning(
            QString("Ошибка записи транзакции: %1").arg(query.lastError().text()));

        return false;
    }

    if (!m_db.commit())
    {
        m_db.rollback();
        //qWarning() << u"Ошибка коммита:" << m_db.lastError().text();
        return false;
    }
    
    Logger::instance().info(
        QString("Перевод выполнен: %1 со счёта %2 на счёт %3").arg(amount).arg(fromAccountId).arg(toAccountId));
    
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
        Logger::instance().warning(
            QString("Ошибка блокировки карты: %1").arg(query.lastError().text()));
        return false;
    }

    Logger::instance().info(QString("Карта заблокирована. ID: %1").arg(cardId));
    return true;
}

bool DatabaseManager::freezeCard(int cardId)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE cards SET is_active = NOT is_active WHERE id = :id RETURNING is_active");
    query.bindValue(":id", cardId);

    if (!query.exec() || !query.next())
    {
        Logger::instance().warning(
            QString("Ошибка заморозки карты: %1").arg(query.lastError().text()));

        return false;
    }

    bool newState = query.value(0).toBool();
    
    Logger::instance().info(
        QString("Карта %1 ID: %2").arg(newState ? "разморожена" : "заморожена").arg(cardId));

    return true;
}

bool DatabaseManager::unfreezeCard(int cardId)
{
    QSqlQuery query(m_db);
    query.prepare("UPDATE cards SET is_active = true WHERE id = :id");
    query.bindValue(":id", cardId);

    if (!query.exec())
    {
        Logger::instance().warning(
            QString("Ошибка разморозки карты: %1").arg(query.lastError().text()));
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
        Logger::instance().warning(
            QString("Ошибка зачисления:").arg(query.lastError().text()));
        return false;
    }

    // Запись транзакции (деньги из воздуха)
    query.prepare(
        "INSERT INTO transactions (from_account_id, to_account_id, amount, transaction_type, description, status) "
        "VALUES (NULL, :to, :amount, 'external', :desc, 'completed')"
    );
    query.bindValue(":to", accountId);
    query.bindValue(":amount", amount);
    query.bindValue(":desc", QStringLiteral("Пополнение счёта"));

    if (!query.exec())
    {
        m_db.rollback();
        Logger::instance().warning(
            QString("Ошибка записи транзакции:").arg(query.lastError().text()));

        return false;
    }

    if (!m_db.commit())
    {
        m_db.rollback();
        return false;
    }

    Logger::instance().info(
        QString("Пополнение: %1 на счёт %2").arg(amount).arg(accountId));

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
        Logger::instance().warning(
            QString("Ошибка установки основного счёта: %1").arg(query.lastError().text()));
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

// ---- Каталог монет ----
QVariantList DatabaseManager::getCryptocurrencies()
{
    QVariantList list;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT id, symbol, name, description, icon_color, icon_letter, "
        "       base_price, current_price, last_updated "
        "FROM cryptocurrencies WHERE is_active = TRUE ORDER BY id"
    );
    if (!q.exec())
    {
        Logger::instance().warning("getCryptocurrencies: " + q.lastError().text());
        return list;
    }
    while (q.next())
    {
        QVariantMap m;
        m["id"] = q.value(0).toInt();
        m["symbol"] = q.value(1).toString();
        m["name"] = q.value(2).toString();
        m["description"] = q.value(3).toString();
        m["icon_color"] = q.value(4).toString();
        m["icon_letter"] = q.value(5).toString();
        m["base_price"] = q.value(6).toDouble();
        m["current_price"] = q.value(7).toDouble();
        m["last_updated"] = q.value(8).toDateTime().toString("HH:mm:ss");
        list.append(m);
    }
    return list;
}

// ---- Кошелёк "по требованию": если нет — создаём ----
QVariantMap DatabaseManager::ensureWallet(int userId, int currencyId)
{
    QVariantMap result;
    QSqlQuery q(m_db);
    q.prepare("SELECT id, balance, address FROM crypto_wallets "
        "WHERE user_id = :uid AND currency_id = :cid");
    q.bindValue(":uid", userId);
    q.bindValue(":cid", currencyId);

    if (q.exec() && q.next())
    {
        result["id"] = q.value(0).toInt();
        result["balance"] = q.value(1).toDouble();
        result["address"] = q.value(2).toString();
        return result;
    }

    QSqlQuery ins(m_db);
    ins.prepare(
        "INSERT INTO crypto_wallets (user_id, currency_id, balance, address) "
        "VALUES (:uid, :cid, 0, generate_crypto_address()) "
        "RETURNING id, balance, address"
    );
    ins.bindValue(":uid", userId);
    ins.bindValue(":cid", currencyId);
    if (ins.exec() && ins.next())
    {
        result["id"] = ins.value(0).toInt();
        result["balance"] = ins.value(1).toDouble();
        result["address"] = ins.value(2).toString();
    }
    else
    {
        Logger::instance().warning("ensureWallet INSERT: " + ins.lastError().text());
    }
    return result;
}

// ---- Список кошельков пользователя (создаём пустые для всех монет) ----
QVariantList DatabaseManager::getUserWallets(int userId)
{
    // 1. Гарантируем по 1 кошельку для каждой активной монеты
    QSqlQuery cur(m_db);
    cur.exec("SELECT id FROM cryptocurrencies WHERE is_active = TRUE");
    while (cur.next())
        ensureWallet(userId, cur.value(0).toInt());

    // 2. Возвращаем сводный view — там и баланс монет, и рублёвый эквивалент
    QVariantList list;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT wallet_id, currency_id, symbol, name, icon_color, icon_letter, "
        "       current_price, balance, rub_value, address "
        "FROM user_wallets_view WHERE user_id = :uid "
        "ORDER BY currency_id"
    );
    q.bindValue(":uid", userId);
    if (!q.exec())
    {
        Logger::instance().warning("getUserWallets: " + q.lastError().text());
        return list;
    }
    while (q.next())
    {
        QVariantMap m;
        m["wallet_id"] = q.value(0).toInt();
        m["currency_id"] = q.value(1).toInt();
        m["symbol"] = q.value(2).toString();
        m["name"] = q.value(3).toString();
        m["icon_color"] = q.value(4).toString();
        m["icon_letter"] = q.value(5).toString();
        m["current_price"] = q.value(6).toDouble();
        m["balance"] = q.value(7).toDouble();
        m["rub_value"] = q.value(8).toDouble();
        m["address"] = q.value(9).toString();
        list.append(m);
    }
    return list;
}

// ---- Покупка крипты на рубли с конкретной банковской карты ----
DatabaseManager::BuyResult DatabaseManager::buyCrypto(int userId, int currencyId, double rubAmount, int cardId)
{
    BuyResult res{ false, "", 0.0, 0.0, 0.0 };

    if (rubAmount <= 0.0)
    {
        res.error = "Сумма должна быть положительной";
        return res;
    }

    QSqlQuery q(m_db);

    // 1. Проверяем валюту и зафиксируем цену в момент сделки
    q.prepare("SELECT current_price, symbol FROM cryptocurrencies WHERE id = :id AND is_active = TRUE");
    q.bindValue(":id", currencyId);
    if (!q.exec() || !q.next())
    {
        res.error = "Криптовалюта не найдена";
        return res;
    }
    double price = q.value(0).toDouble();
    QString sym = q.value(1).toString();
    if (price <= 0)
    {
        res.error = "Некорректная цена";
        return res;
    }

    // 2. Проверяем карту: принадлежит ли пользователю, активна ли, не заблокирована
    q.prepare(
        "SELECT c.account_id, c.is_blocked, c.is_active "
        "FROM cards c INNER JOIN accounts a ON c.account_id = a.id "
        "WHERE c.id = :cid AND a.user_id = :uid"
    );
    q.bindValue(":cid", cardId);
    q.bindValue(":uid", userId);
    if (!q.exec() || !q.next())
    {
        res.error = "Карта не найдена";
        return res;
    }
    int  accountId = q.value(0).toInt();
    bool blocked = q.value(1).toBool();
    bool active = q.value(2).toBool();
    if (blocked) { res.error = "Карта заблокирована"; return res; }
    if (!active) { res.error = "Карта заморожена";    return res; }

    // 3. Гарантируем наличие кошелька
    QVariantMap wallet = ensureWallet(userId, currencyId);
    if (wallet.isEmpty())
    {
        res.error = "Не удалось создать кошелёк";
        return res;
    }

    // 4. Считаем количество монет (8 знаков после запятой)
    double coins = std::round((rubAmount / price) * 1e8) / 1e8;
    if (coins <= 0)
    {
        res.error = "Слишком маленькая сумма";
        return res;
    }

    // 5. Транзакционно: списать рубли, увеличить баланс кошелька, записи в обе истории
    m_db.transaction();

    q.prepare("UPDATE accounts SET balance = balance - :amt WHERE id = :id AND balance >= :amt");
    q.bindValue(":amt", rubAmount);
    q.bindValue(":id", accountId);
    if (!q.exec() || q.numRowsAffected() == 0)
    {
        m_db.rollback();
        res.error = "Недостаточно средств на карте";
        return res;
    }

    QString descRub = QString("Покупка %1 %2 по курсу %3 ₽")
        .arg(coins, 0, 'f', 8).arg(sym).arg(price, 0, 'f', 2);

    q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
        "transaction_type, description, status) "
        "VALUES (:from, NULL, :amt, 'external', :desc, 'completed') RETURNING id");
    q.bindValue(":from", accountId);
    q.bindValue(":amt", rubAmount);
    q.bindValue(":desc", descRub);
    if (!q.exec() || !q.next())
    {
        m_db.rollback();
        res.error = "Ошибка банковской транзакции";
        return res;
    }
    int bankTxId = q.value(0).toInt();

    q.prepare("UPDATE crypto_wallets SET balance = balance + :amt "
        "WHERE user_id = :uid AND currency_id = :cid");
    q.bindValue(":amt", coins);
    q.bindValue(":uid", userId);
    q.bindValue(":cid", currencyId);
    if (!q.exec() || q.numRowsAffected() == 0)
    {
        m_db.rollback();
        res.error = "Ошибка зачисления монет";
        return res;
    }

    q.prepare("INSERT INTO crypto_transactions "
        "(operation_type, user_id, currency_id, coin_amount, rub_amount, "
        " price_per_coin, card_id, related_account_id, bank_transaction_id, description) "
        "VALUES ('buy', :uid, :cid, :coins, :rub, :price, :card, :acc, :btx, :desc)");
    q.bindValue(":uid", userId);
    q.bindValue(":cid", currencyId);
    q.bindValue(":coins", coins);
    q.bindValue(":rub", rubAmount);
    q.bindValue(":price", price);
    q.bindValue(":card", cardId);
    q.bindValue(":acc", accountId);
    q.bindValue(":btx", bankTxId);
    q.bindValue(":desc", descRub);
    if (!q.exec())
    {
        m_db.rollback();
        res.error = "Ошибка истории крипто-операций";
        return res;
    }

    if (!m_db.commit())
    {
        m_db.rollback();
        res.error = "Не удалось зафиксировать транзакцию";
        return res;
    }

    res.ok = true;
    res.coinAmount = coins;
    res.rubAmount = rubAmount;
    res.price = price;
    return res;
}

// ---- Продажа криптовалюты с зачислением рублей на карту ----
DatabaseManager::SellResult DatabaseManager::sellCrypto(int userId, int currencyId, double coinAmount, int cardId)
{
    SellResult res{ false, "", 0.0, 0.0, 0.0 };

    if (coinAmount <= 0.0)
    {
        res.error = "Количество должно быть положительным";
        return res;
    }

    QSqlQuery q(m_db);

    q.prepare("SELECT current_price, symbol FROM cryptocurrencies WHERE id = :id AND is_active = TRUE");
    q.bindValue(":id", currencyId);
    if (!q.exec() || !q.next()) { res.error = "Криптовалюта не найдена"; return res; }
    double price = q.value(0).toDouble();
    QString sym = q.value(1).toString();

    q.prepare("SELECT balance FROM crypto_wallets WHERE user_id = :uid AND currency_id = :cid");
    q.bindValue(":uid", userId);
    q.bindValue(":cid", currencyId);
    if (!q.exec() || !q.next()) { res.error = "Кошелёк не найден"; return res; }
    double balance = q.value(0).toDouble();
    if (balance + 1e-9 < coinAmount)
    {
        res.error = QString("Недостаточно монет (есть %1)").arg(balance, 0, 'f', 8);
        return res;
    }

    q.prepare(
        "SELECT c.account_id, c.is_blocked, c.is_active "
        "FROM cards c INNER JOIN accounts a ON c.account_id = a.id "
        "WHERE c.id = :cid AND a.user_id = :uid"
    );
    q.bindValue(":cid", cardId);
    q.bindValue(":uid", userId);
    if (!q.exec() || !q.next()) { res.error = "Карта не найдена"; return res; }
    int  accountId = q.value(0).toInt();
    if (q.value(1).toBool()) { res.error = "Карта заблокирована"; return res; }
    if (!q.value(2).toBool()) { res.error = "Карта заморожена"; return res; }

    double rubAmount = std::round((coinAmount * price) * 100.0) / 100.0;
    if (rubAmount <= 0) { res.error = "Слишком маленькая сумма"; return res; }

    m_db.transaction();

    q.prepare("UPDATE crypto_wallets SET balance = balance - :amt "
        "WHERE user_id = :uid AND currency_id = :cid AND balance >= :amt");
    q.bindValue(":amt", coinAmount);
    q.bindValue(":uid", userId);
    q.bindValue(":cid", currencyId);
    if (!q.exec() || q.numRowsAffected() == 0)
    {
        m_db.rollback();
        res.error = "Не удалось списать монеты";
        return res;
    }

    QString descRub = QString("Продажа %1 %2 по курсу %3 ₽")
        .arg(coinAmount, 0, 'f', 8).arg(sym).arg(price, 0, 'f', 2);

    q.prepare("UPDATE accounts SET balance = balance + :amt WHERE id = :id");
    q.bindValue(":amt", rubAmount);
    q.bindValue(":id", accountId);
    if (!q.exec()) { m_db.rollback(); res.error = "Ошибка зачисления рублей"; return res; }

    q.prepare("INSERT INTO transactions (from_account_id, to_account_id, amount, "
        "transaction_type, description, status) "
        "VALUES (NULL, :to, :amt, 'external', :desc, 'completed') RETURNING id");
    q.bindValue(":to", accountId);
    q.bindValue(":amt", rubAmount);
    q.bindValue(":desc", descRub);
    if (!q.exec() || !q.next()) { m_db.rollback(); res.error = "Ошибка банковской транзакции"; return res; }
    int bankTxId = q.value(0).toInt();

    q.prepare("INSERT INTO crypto_transactions "
        "(operation_type, user_id, currency_id, coin_amount, rub_amount, "
        " price_per_coin, card_id, related_account_id, bank_transaction_id, description) "
        "VALUES ('sell', :uid, :cid, :coins, :rub, :price, :card, :acc, :btx, :desc)");
    q.bindValue(":uid", userId);
    q.bindValue(":cid", currencyId);
    q.bindValue(":coins", coinAmount);
    q.bindValue(":rub", rubAmount);
    q.bindValue(":price", price);
    q.bindValue(":card", cardId);
    q.bindValue(":acc", accountId);
    q.bindValue(":btx", bankTxId);
    q.bindValue(":desc", descRub);
    if (!q.exec()) { m_db.rollback(); res.error = "Ошибка истории"; return res; }

    if (!m_db.commit()) { m_db.rollback(); res.error = "Не удалось зафиксировать"; return res; }

    res.ok = true;
    res.coinAmount = coinAmount;
    res.rubAmount = rubAmount;
    res.price = price;
    return res;
}

// ---- Перевод монет другому пользователю по адресу кошелька ----
DatabaseManager::CryptoTransferResult DatabaseManager::transferCrypto(
    int userId, int currencyId, double coinAmount, const QString& recipientAddress)
{
    CryptoTransferResult res{ false, "", 0.0, "" };

    if (coinAmount <= 0)
    {
        res.error = "Количество должно быть положительным";
        return res;
    }

    QSqlQuery q(m_db);

    // Найти получателя по адресу
    q.prepare("SELECT w.id, w.user_id, u.first_name, u.last_name "
        "FROM crypto_wallets w INNER JOIN users u ON u.id = w.user_id "
        "WHERE w.address = :addr AND w.currency_id = :cid");
    q.bindValue(":addr", recipientAddress);
    q.bindValue(":cid", currencyId);
    if (!q.exec() || !q.next())
    {
        res.error = "Кошелёк получателя не найден";
        return res;
    }
    int recipientUserId = q.value(1).toInt();
    QString recipName = q.value(3).toString() + " " + q.value(2).toString().left(1) + ".";

    if (recipientUserId == userId)
    {
        res.error = "Нельзя переводить самому себе";
        return res;
    }

    // Гарантируем, что у отправителя есть кошелёк
    QVariantMap myWallet = ensureWallet(userId, currencyId);
    if (myWallet.isEmpty()) { res.error = "Кошелёк отправителя не найден"; return res; }

    if (myWallet["balance"].toDouble() + 1e-9 < coinAmount)
    {
        res.error = QString("Недостаточно монет (есть %1)").arg(myWallet["balance"].toDouble(), 0, 'f', 8);
        return res;
    }

    QString sym;
    q.prepare("SELECT symbol FROM cryptocurrencies WHERE id = :id");
    q.bindValue(":id", currencyId);
    if (q.exec() && q.next()) sym = q.value(0).toString();

    m_db.transaction();

    q.prepare("UPDATE crypto_wallets SET balance = balance - :amt "
        "WHERE user_id = :uid AND currency_id = :cid AND balance >= :amt");
    q.bindValue(":amt", coinAmount);
    q.bindValue(":uid", userId);
    q.bindValue(":cid", currencyId);
    if (!q.exec() || q.numRowsAffected() == 0)
    {
        m_db.rollback();
        res.error = "Не удалось списать монеты";
        return res;
    }

    q.prepare("UPDATE crypto_wallets SET balance = balance + :amt "
        "WHERE user_id = :uid AND currency_id = :cid");
    q.bindValue(":amt", coinAmount);
    q.bindValue(":uid", recipientUserId);
    q.bindValue(":cid", currencyId);
    if (!q.exec() || q.numRowsAffected() == 0)
    {
        m_db.rollback();
        res.error = "Не удалось зачислить монеты получателю";
        return res;
    }

    QString descOut = QString("Перевод %1 %2 → %3").arg(coinAmount, 0, 'f', 8).arg(sym).arg(recipientAddress);
    QString descIn = QString("Получено %1 %2 от пользователя").arg(coinAmount, 0, 'f', 8).arg(sym);

    q.prepare("INSERT INTO crypto_transactions "
        "(operation_type, user_id, counterparty_user_id, currency_id, coin_amount, description) "
        "VALUES ('transfer_out', :uid, :ctp, :cid, :coins, :desc)");
    q.bindValue(":uid", userId); q.bindValue(":ctp", recipientUserId);
    q.bindValue(":cid", currencyId); q.bindValue(":coins", coinAmount);
    q.bindValue(":desc", descOut);
    if (!q.exec()) { m_db.rollback(); res.error = "Ошибка истории"; return res; }

    q.prepare("INSERT INTO crypto_transactions "
        "(operation_type, user_id, counterparty_user_id, currency_id, coin_amount, description) "
        "VALUES ('transfer_in', :uid, :ctp, :cid, :coins, :desc)");
    q.bindValue(":uid", recipientUserId); q.bindValue(":ctp", userId);
    q.bindValue(":cid", currencyId); q.bindValue(":coins", coinAmount);
    q.bindValue(":desc", descIn);
    if (!q.exec()) { m_db.rollback(); res.error = "Ошибка истории получателя"; return res; }

    if (!m_db.commit()) { m_db.rollback(); res.error = "Не удалось зафиксировать"; return res; }

    res.ok = true;
    res.coinAmount = coinAmount;
    res.recipientName = recipName;
    return res;
}

// ---- История крипто-операций пользователя ----
QVariantList DatabaseManager::getCryptoHistory(int userId, int limit, int offset)
{
    QVariantList list;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT t.id, t.operation_type, t.coin_amount, t.rub_amount, t.price_per_coin, "
        "       t.description, t.created_at, c.symbol, c.icon_color, c.icon_letter "
        "FROM crypto_transactions t "
        "INNER JOIN cryptocurrencies c ON c.id = t.currency_id "
        "WHERE t.user_id = :uid "
        "ORDER BY t.created_at DESC LIMIT :lim OFFSET :off"
    );
    q.bindValue(":uid", userId);
    q.bindValue(":lim", limit);
    q.bindValue(":off", offset);
    if (!q.exec()) return list;

    while (q.next())
    {
        QVariantMap m;
        m["id"] = q.value(0).toInt();
        m["operation_type"] = q.value(1).toString();
        m["coin_amount"] = q.value(2).toDouble();
        m["rub_amount"] = q.value(3).toDouble();
        m["price_per_coin"] = q.value(4).toDouble();
        m["description"] = q.value(5).toString();
        m["created_at"] = q.value(6).toDateTime().toString("dd.MM.yyyy HH:mm");
        m["symbol"] = q.value(7).toString();
        m["icon_color"] = q.value(8).toString();
        m["icon_letter"] = q.value(9).toString();
        list.append(m);
    }
    return list;
}