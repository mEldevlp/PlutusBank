#include "DatabaseManager.h"
#include <QDateTime>
#include <QRegularExpression>
#include <cmath>

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

// --- Гарантирует наличие кошелька (user, currency); возвращает его карточку.
//     Адрес генерируется PL/pgSQL-функцией public.generate_crypto_address().
//     Конкурентно безопасно за счёт UNIQUE(user_id, currency_id) + ON CONFLICT.
QVariantMap DatabaseManager::ensureWallet(int userId, int currencyId)
{
    QVariantMap out;

    // 1) Пробуем достать существующий кошелёк
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT id, user_id, currency_id, balance, address "
            "  FROM crypto_wallets "
            " WHERE user_id = :uid AND currency_id = :cid"
        );
        q.bindValue(":uid", userId);
        q.bindValue(":cid", currencyId);
        if (q.exec() && q.next())
        {
            out["id"] = q.value(0).toInt();
            out["user_id"] = q.value(1).toInt();
            out["currency_id"] = q.value(2).toInt();
            out["balance"] = q.value(3).toDouble();
            out["address"] = q.value(4).toString();
            return out;
        }
    }

    // 2) Нет — создаём (idempotent через ON CONFLICT)
    {
        QSqlQuery q(m_db);
        q.prepare(
            "INSERT INTO crypto_wallets (user_id, currency_id, balance, address) "
            "VALUES (:uid, :cid, 0, public.generate_crypto_address()) "
            "ON CONFLICT (user_id, currency_id) DO NOTHING"
        );
        q.bindValue(":uid", userId);
        q.bindValue(":cid", currencyId);
        if (!q.exec())
        {
            qWarning() << u"ensureWallet: INSERT failed:" << q.lastError().text();
            return {};
        }
    }

    // 3) Перечитываем (в т.ч. на случай, когда ON CONFLICT просто пропустил вставку)
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT id, user_id, currency_id, balance, address "
            "  FROM crypto_wallets "
            " WHERE user_id = :uid AND currency_id = :cid"
        );
        q.bindValue(":uid", userId);
        q.bindValue(":cid", currencyId);
        if (q.exec() && q.next())
        {
            out["id"] = q.value(0).toInt();
            out["user_id"] = q.value(1).toInt();
            out["currency_id"] = q.value(2).toInt();
            out["balance"] = q.value(3).toDouble();
            out["address"] = q.value(4).toString();
        }
    }
    return out;
}

// --- Каталог криптовалют (только активные) ---
QVariantList DatabaseManager::getCryptocurrencies()
{
    QVariantList out;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT id, symbol, name, description, icon_color, icon_letter, "
        "       base_price, current_price, volatility, jump_intensity, jump_sigma, "
        "       drift, mean_reversion, last_updated, is_active "
        "  FROM cryptocurrencies WHERE is_active = TRUE "
        " ORDER BY id"
    );
    if (!q.exec())
    {
        Logger::instance().warning("getCryptocurrencies: " + q.lastError().text());
        return out;
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
        m["volatility"] = q.value(8).toDouble();
        m["jump_intensity"] = q.value(9).toDouble();
        m["jump_sigma"] = q.value(10).toDouble();
        m["drift"] = q.value(11).toDouble();
        m["mean_reversion"] = q.value(12).toDouble();
        m["last_updated"] = q.value(13).toDateTime().toString("dd.MM.yyyy HH:mm:ss");
        m["is_active"] = q.value(14).toBool();
        out.append(m);
    }
    return out;
}

// --- Кошельки пользователя (через user_wallets_view) ---
//     Перед выдачей убеждаемся, что у пользователя есть кошелёк по каждой
//     активной валюте — чтобы в каталоге у него всегда был адрес.
QVariantList DatabaseManager::getUserWallets(int userId)
{
    // Догенерируем недостающие
    {
        QSqlQuery cur(m_db);
        cur.prepare("SELECT id FROM cryptocurrencies WHERE is_active = TRUE");
        if (cur.exec())
        {
            while (cur.next())
                ensureWallet(userId, cur.value(0).toInt());
        }
    }

    QVariantList out;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT wallet_id, currency_id, balance, address, "
        "       symbol, name, icon_color, icon_letter, current_price, rub_value "
        "  FROM user_wallets_view "
        " WHERE user_id = :uid "
        " ORDER BY rub_value DESC, currency_id"
    );
    q.bindValue(":uid", userId);
    if (!q.exec())
    {
        Logger::instance().warning("getUserWallets: " + q.lastError().text());
        return out;
    }
    while (q.next())
    {
        QVariantMap m;
        m["id"] = q.value(0).toInt();
        m["currency_id"] = q.value(1).toInt();
        m["balance"] = q.value(2).toDouble();
        m["address"] = q.value(3).toString();
        m["symbol"] = q.value(4).toString();
        m["name"] = q.value(5).toString();
        m["icon_color"] = q.value(6).toString();
        m["icon_letter"] = q.value(7).toString();
        m["current_price"] = q.value(8).toDouble();
        m["rub_value"] = q.value(9).toDouble();
        out.append(m);
    }
    return out;
}

// --- Общая история крипто-операций (без фильтра по монете) ---
QVariantList DatabaseManager::getCryptoHistory(int userId, int limit, int offset)
{
    QVariantList out;
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT t.id, t.operation_type, t.coin_amount, t.rub_amount, t.price_per_coin, "
        "       t.description, t.created_at, t.currency_id, "
        "       c.symbol, c.name, c.icon_color, c.icon_letter "
        "  FROM crypto_transactions t "
        "  JOIN cryptocurrencies c ON c.id = t.currency_id "
        " WHERE t.user_id = :uid "
        " ORDER BY t.created_at DESC LIMIT :lim OFFSET :off"
    );
    q.bindValue(":uid", userId);
    q.bindValue(":lim", limit);
    q.bindValue(":off", offset);

    if (!q.exec())
    {
        Logger::instance().warning("getCryptoHistory: " + q.lastError().text());
        return out;
    }
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
        m["currency_id"] = q.value(7).toInt();
        m["symbol"] = q.value(8).toString();
        m["name"] = q.value(9).toString();
        m["icon_color"] = q.value(10).toString();
        m["icon_letter"] = q.value(11).toString();
        out.append(m);
    }
    return out;
}

// --- Покупка крипты ---
DatabaseManager::BuyResult
DatabaseManager::buyCrypto(int userId, int currencyId, double rubAmount, int cardId)
{
    BuyResult r{ false, "", 0.0, 0.0, 0.0 };

    if (rubAmount <= 0) { r.error = "Сумма должна быть положительной"; return r; }
    if (rubAmount < 1.0) { r.error = "Минимальная сумма покупки — 1 ₽"; return r; }

    // 1. Карта пользователя — счёт + статус
    int  accountId = -1;
    bool cardActive = false, cardBlocked = true;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT a.id, c.is_active, c.is_blocked "
            "  FROM cards c "
            "  JOIN accounts a ON a.id = c.account_id "
            " WHERE c.id = :cid AND a.user_id = :uid AND c.card_type = 'debit'"
        );
        q.bindValue(":cid", cardId);
        q.bindValue(":uid", userId);
        if (!q.exec()) { r.error = "Ошибка проверки карты"; return r; }
        if (!q.next()) { r.error = "Карта не найдена"; return r; }
        accountId = q.value(0).toInt();
        cardActive = q.value(1).toBool();
        cardBlocked = q.value(2).toBool();
    }
    if (cardBlocked) { r.error = "Карта заблокирована"; return r; }
    if (!cardActive) { r.error = "Карта заморожена";    return r; }

    // 2. Текущая цена монеты
    QString symbol;
    double price = 0.0;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT symbol, current_price FROM cryptocurrencies "
            " WHERE id = :id AND is_active = TRUE");
        q.bindValue(":id", currencyId);
        if (!q.exec() || !q.next()) { r.error = "Криптовалюта не найдена"; return r; }
        symbol = q.value(0).toString();
        price = q.value(1).toDouble();
    }
    if (price <= 0) { r.error = "Некорректная цена"; return r; }

    double coinAmount = std::round((rubAmount / price) * 1e8) / 1e8;
    if (coinAmount <= 0) { r.error = "Слишком маленькая сумма"; return r; }

    if (!m_db.transaction()) { r.error = "Не удалось начать транзакцию"; return r; }

    // 3. Проверка баланса счёта (с блокировкой)
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT balance FROM accounts WHERE id = :aid FOR UPDATE");
        q.bindValue(":aid", accountId);
        if (!q.exec() || !q.next())
        {
            m_db.rollback();
            r.error = "Ошибка проверки баланса";
            return r;
        }
        double balance = q.value(0).toDouble();
        if (balance < rubAmount)
        {
            m_db.rollback();
            r.error = QString("Недостаточно средств. Нужно %1 ₽, доступно %2 ₽")
                .arg(rubAmount, 0, 'f', 2).arg(balance, 0, 'f', 2);
            return r;
        }
    }

    // 4. Списание со счёта
    {
        QSqlQuery q(m_db);
        q.prepare("UPDATE accounts SET balance = balance - :amt WHERE id = :aid");
        q.bindValue(":amt", rubAmount);
        q.bindValue(":aid", accountId);
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка списания"; return r; }
    }

    // 5. Банковская транзакция (external)
    int bankTxId = -1;
    {
        QSqlQuery q(m_db);
        q.prepare("INSERT INTO transactions "
            " (from_account_id, amount, transaction_type, description, status) "
            " VALUES (:from, :amt, 'external', :desc, 'completed') "
            " RETURNING id");
        q.bindValue(":from", accountId);
        q.bindValue(":amt", rubAmount);
        q.bindValue(":desc", QString("Покупка %1 %2").arg(coinAmount, 0, 'f', 8).arg(symbol));
        if (!q.exec() || !q.next())
        {
            m_db.rollback();
            r.error = "Ошибка регистрации транзакции";
            return r;
        }
        bankTxId = q.value(0).toInt();
    }

    // 6. Кошелёк (создаём если нет) + зачисление монет
    QVariantMap wallet = ensureWallet(userId, currencyId);
    if (wallet.isEmpty()) { m_db.rollback(); r.error = "Ошибка кошелька"; return r; }
    int walletId = wallet["id"].toInt();
    {
        QSqlQuery q(m_db);
        q.prepare("UPDATE crypto_wallets SET balance = balance + :amt WHERE id = :wid");
        q.bindValue(":amt", coinAmount);
        q.bindValue(":wid", walletId);
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка зачисления монет"; return r; }
    }

    // 7. Крипто-транзакция
    {
        QSqlQuery q(m_db);
        q.prepare("INSERT INTO crypto_transactions "
            " (operation_type, user_id, currency_id, coin_amount, rub_amount, "
            "  price_per_coin, card_id, related_account_id, bank_transaction_id, description) "
            " VALUES ('buy', :uid, :cid, :coins, :rub, :price, :card, :acc, :btx, :desc)");
        q.bindValue(":uid", userId);
        q.bindValue(":cid", currencyId);
        q.bindValue(":coins", coinAmount);
        q.bindValue(":rub", rubAmount);
        q.bindValue(":price", price);
        q.bindValue(":card", cardId);
        q.bindValue(":acc", accountId);
        q.bindValue(":btx", bankTxId);
        q.bindValue(":desc", QString("Покупка %1 за %2 ₽").arg(symbol).arg(rubAmount, 0, 'f', 2));
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка регистрации крипто-транзакции"; return r; }
    }

    if (!m_db.commit())
    {
        m_db.rollback();
        r.error = "Не удалось подтвердить покупку";
        return r;
    }

    r.ok = true;
    r.coinAmount = coinAmount;
    r.rubAmount = rubAmount;
    r.price = price;
    return r;
}

// --- Продажа крипты ---
DatabaseManager::SellResult
DatabaseManager::sellCrypto(int userId, int currencyId, double coinAmount, int cardId)
{
    SellResult r{ false, "", 0.0, 0.0, 0.0 };

    if (coinAmount <= 0) { r.error = "Количество должно быть положительным"; return r; }

    // 1. Карта (целевой счёт + статус)
    int  accountId = -1;
    bool cardActive = false, cardBlocked = true;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT a.id, c.is_active, c.is_blocked "
            "  FROM cards c "
            "  JOIN accounts a ON a.id = c.account_id "
            " WHERE c.id = :cid AND a.user_id = :uid AND c.card_type = 'debit'"
        );
        q.bindValue(":cid", cardId);
        q.bindValue(":uid", userId);
        if (!q.exec()) { r.error = "Ошибка проверки карты"; return r; }
        if (!q.next()) { r.error = "Карта не найдена"; return r; }
        accountId = q.value(0).toInt();
        cardActive = q.value(1).toBool();
        cardBlocked = q.value(2).toBool();
    }
    if (cardBlocked) { r.error = "Карта заблокирована"; return r; }
    if (!cardActive) { r.error = "Карта заморожена";    return r; }

    // 2. Цена и символ
    QString symbol;
    double price = 0.0;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT symbol, current_price FROM cryptocurrencies "
            " WHERE id = :id AND is_active = TRUE");
        q.bindValue(":id", currencyId);
        if (!q.exec() || !q.next()) { r.error = "Криптовалюта не найдена"; return r; }
        symbol = q.value(0).toString();
        price = q.value(1).toDouble();
    }
    if (price <= 0) { r.error = "Некорректная цена"; return r; }

    double rubAmount = std::round((coinAmount * price) * 100.0) / 100.0;
    if (rubAmount <= 0) { r.error = "Слишком маленькое количество"; return r; }

    if (!m_db.transaction()) { r.error = "Не удалось начать транзакцию"; return r; }

    // 3. Кошелёк и баланс монет (FOR UPDATE)
    int walletId = -1;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT id, balance FROM crypto_wallets "
            " WHERE user_id = :uid AND currency_id = :cid FOR UPDATE");
        q.bindValue(":uid", userId);
        q.bindValue(":cid", currencyId);
        if (!q.exec() || !q.next())
        {
            m_db.rollback();
            r.error = "Кошелёк не найден";
            return r;
        }
        walletId = q.value(0).toInt();
        double balance = q.value(1).toDouble();
        if (balance < coinAmount)
        {
            m_db.rollback();
            r.error = QString("Недостаточно %1. Доступно: %2")
                .arg(symbol).arg(balance, 0, 'f', 8);
            return r;
        }
    }

    // 4. Списание монет
    {
        QSqlQuery q(m_db);
        q.prepare("UPDATE crypto_wallets SET balance = balance - :amt WHERE id = :wid");
        q.bindValue(":amt", coinAmount);
        q.bindValue(":wid", walletId);
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка списания монет"; return r; }
    }

    // 5. Зачисление рублей на счёт карты
    {
        QSqlQuery q(m_db);
        q.prepare("UPDATE accounts SET balance = balance + :amt WHERE id = :aid");
        q.bindValue(":amt", rubAmount);
        q.bindValue(":aid", accountId);
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка зачисления"; return r; }
    }

    // 6. Банковская транзакция (приход извне)
    int bankTxId = -1;
    {
        QSqlQuery q(m_db);
        q.prepare("INSERT INTO transactions "
            " (to_account_id, amount, transaction_type, description, status) "
            " VALUES (:to, :amt, 'external', :desc, 'completed') "
            " RETURNING id");
        q.bindValue(":to", accountId);
        q.bindValue(":amt", rubAmount);
        q.bindValue(":desc", QString("Продажа %1 %2").arg(coinAmount, 0, 'f', 8).arg(symbol));
        if (!q.exec() || !q.next())
        {
            m_db.rollback();
            r.error = "Ошибка регистрации транзакции";
            return r;
        }
        bankTxId = q.value(0).toInt();
    }

    // 7. Крипто-транзакция
    {
        QSqlQuery q(m_db);
        q.prepare("INSERT INTO crypto_transactions "
            " (operation_type, user_id, currency_id, coin_amount, rub_amount, "
            "  price_per_coin, card_id, related_account_id, bank_transaction_id, description) "
            " VALUES ('sell', :uid, :cid, :coins, :rub, :price, :card, :acc, :btx, :desc)");
        q.bindValue(":uid", userId);
        q.bindValue(":cid", currencyId);
        q.bindValue(":coins", coinAmount);
        q.bindValue(":rub", rubAmount);
        q.bindValue(":price", price);
        q.bindValue(":card", cardId);
        q.bindValue(":acc", accountId);
        q.bindValue(":btx", bankTxId);
        q.bindValue(":desc", QString("Продажа %1 за %2 ₽").arg(symbol).arg(rubAmount, 0, 'f', 2));
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка регистрации крипто-транзакции"; return r; }
    }

    if (!m_db.commit())
    {
        m_db.rollback();
        r.error = "Не удалось подтвердить продажу";
        return r;
    }

    r.ok = true;
    r.coinAmount = coinAmount;
    r.rubAmount = rubAmount;
    r.price = price;
    return r;
}

// --- Перевод монет между кошельками по адресу ---
DatabaseManager::CryptoTransferResult
DatabaseManager::transferCrypto(int userId, int currencyId, double coinAmount,
    const QString& recipientAddress)
{
    CryptoTransferResult r{ false, "", 0.0, "" };

    if (coinAmount <= 0) { r.error = "Количество должно быть положительным"; return r; }

    QString addr = recipientAddress.trimmed();
    static const QRegularExpression addrRe("^0x[0-9a-fA-F]{40}$");
    if (!addrRe.match(addr).hasMatch())
    {
        r.error = "Некорректный формат адреса";
        return r;
    }

    // 1. Найти получателя по адресу + currency
    int     recipientUserId = -1, recipientWalletId = -1;
    QString recipientName;
    QString symbol;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT w.id, w.user_id, "
            "       (u.last_name || ' ' || LEFT(u.first_name,1) || '.') AS name, "
            "       c.symbol "
            "  FROM crypto_wallets w "
            "  JOIN users u ON u.id = w.user_id "
            "  JOIN cryptocurrencies c ON c.id = w.currency_id "
            " WHERE w.address = :addr AND w.currency_id = :cid"
        );
        q.bindValue(":addr", addr);
        q.bindValue(":cid", currencyId);
        if (!q.exec()) { r.error = "Ошибка поиска получателя"; return r; }
        if (!q.next())
        {
            r.error = "Кошелёк по такому адресу не найден";
            return r;
        }
        recipientWalletId = q.value(0).toInt();
        recipientUserId = q.value(1).toInt();
        recipientName = q.value(2).toString();
        symbol = q.value(3).toString();
    }
    if (recipientUserId == userId)
    {
        r.error = "Нельзя переводить самому себе";
        return r;
    }

    if (!m_db.transaction()) { r.error = "Не удалось начать транзакцию"; return r; }

    // 2. Кошелёк отправителя + проверка баланса (FOR UPDATE)
    int senderWalletId = -1;
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT id, balance FROM crypto_wallets "
            " WHERE user_id = :uid AND currency_id = :cid FOR UPDATE");
        q.bindValue(":uid", userId);
        q.bindValue(":cid", currencyId);
        if (!q.exec() || !q.next())
        {
            m_db.rollback();
            r.error = "У вас нет кошелька в этой валюте";
            return r;
        }
        senderWalletId = q.value(0).toInt();
        double balance = q.value(1).toDouble();
        if (balance < coinAmount)
        {
            m_db.rollback();
            r.error = QString("Недостаточно %1. Доступно: %2")
                .arg(symbol).arg(balance, 0, 'f', 8);
            return r;
        }
    }

    // 3. Перевод: − у отправителя, + у получателя
    {
        QSqlQuery q(m_db);
        q.prepare("UPDATE crypto_wallets SET balance = balance - :amt WHERE id = :wid");
        q.bindValue(":amt", coinAmount);
        q.bindValue(":wid", senderWalletId);
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка списания"; return r; }
    }
    {
        QSqlQuery q(m_db);
        q.prepare("UPDATE crypto_wallets SET balance = balance + :amt WHERE id = :wid");
        q.bindValue(":amt", coinAmount);
        q.bindValue(":wid", recipientWalletId);
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка зачисления"; return r; }
    }

    // 4. Две записи: transfer_out у отправителя, transfer_in у получателя
    {
        QSqlQuery q(m_db);
        q.prepare("INSERT INTO crypto_transactions "
            " (operation_type, user_id, counterparty_user_id, currency_id, coin_amount, description) "
            " VALUES ('transfer_out', :uid, :cuid, :cid, :amt, :desc)");
        q.bindValue(":uid", userId);
        q.bindValue(":cuid", recipientUserId);
        q.bindValue(":cid", currencyId);
        q.bindValue(":amt", coinAmount);
        q.bindValue(":desc", QString("Перевод %1 %2 → %3")
            .arg(coinAmount, 0, 'f', 8)
            .arg(symbol)
            .arg(recipientName));
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка регистрации"; return r; }
    }
    {
        QSqlQuery q(m_db);
        q.prepare("INSERT INTO crypto_transactions "
            " (operation_type, user_id, counterparty_user_id, currency_id, coin_amount, description) "
            " VALUES ('transfer_in', :uid, :cuid, :cid, :amt, :desc)");
        q.bindValue(":uid", recipientUserId);
        q.bindValue(":cuid", userId);
        q.bindValue(":cid", currencyId);
        q.bindValue(":amt", coinAmount);
        q.bindValue(":desc", QString("Получено %1 %2").arg(coinAmount, 0, 'f', 8).arg(symbol));
        if (!q.exec()) { m_db.rollback(); r.error = "Ошибка регистрации"; return r; }
    }

    if (!m_db.commit())
    {
        m_db.rollback();
        r.error = "Не удалось подтвердить перевод";
        return r;
    }

    r.ok = true;
    r.coinAmount = coinAmount;
    r.recipientName = recipientName;
    return r;
}

// --- Полная информация по одной монете для CryptoCoinDetailPage ---
QVariantMap DatabaseManager::getCoinDetail(int userId, int currencyId)
{
    QVariantMap out;

    // 1. Сама монета
    QVariantMap currency;
    double currentPrice = 0.0;
    double basePrice = 0.0;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT id, symbol, name, description, icon_color, icon_letter, "
            "       base_price, current_price, volatility, jump_intensity, jump_sigma, "
            "       drift, mean_reversion, is_active "
            "  FROM cryptocurrencies WHERE id = :id"
        );
        q.bindValue(":id", currencyId);
        if (!q.exec() || !q.next())
        {
            Logger::instance().warning(QString("getCoinDetail: currency %1 not found").arg(currencyId));
            return out;  // пустой ответ — клиент покажет "Загружаем"
        }
        currency["id"] = q.value(0).toInt();
        currency["symbol"] = q.value(1).toString();
        currency["name"] = q.value(2).toString();
        currency["description"] = q.value(3).toString();
        currency["icon_color"] = q.value(4).toString();
        currency["icon_letter"] = q.value(5).toString();
        currency["base_price"] = q.value(6).toDouble();
        currency["current_price"] = q.value(7).toDouble();
        currency["volatility"] = q.value(8).toDouble();
        currency["jump_intensity"] = q.value(9).toDouble();
        currency["jump_sigma"] = q.value(10).toDouble();
        currency["drift"] = q.value(11).toDouble();
        currency["mean_reversion"] = q.value(12).toDouble();
        currency["is_active"] = q.value(13).toBool();

        basePrice = currency["base_price"].toDouble();
        currentPrice = currency["current_price"].toDouble();
    }
    out["currency"] = currency;

    // 2. Кошелёк (auto-create через ensureWallet, чтобы был адрес)
    QVariantMap wallet = ensureWallet(userId, currencyId);
    double balance = 0.0;
    if (!wallet.isEmpty())
    {
        balance = wallet["balance"].toDouble();
        wallet["current_price"] = currentPrice;
        wallet["rub_value"] = std::round(balance * currentPrice * 100.0) / 100.0;
    }
    out["wallet"] = wallet;

    // 3. stats24h: цена сутки назад → дельта
    double price24h = currentPrice;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT price FROM crypto_price_history "
            " WHERE currency_id = :cid "
            "   AND recorded_at <= NOW() - INTERVAL '24 hours' "
            " ORDER BY recorded_at DESC LIMIT 1"
        );
        q.bindValue(":cid", currencyId);
        if (q.exec() && q.next())
        {
            price24h = q.value(0).toDouble();
        }
        else
        {
            // Ещё нет суточной истории — берём самую старую запись или базу
            QSqlQuery q2(m_db);
            q2.prepare("SELECT price FROM crypto_price_history "
                " WHERE currency_id = :cid "
                " ORDER BY recorded_at ASC LIMIT 1");
            q2.bindValue(":cid", currencyId);
            if (q2.exec() && q2.next())
                price24h = q2.value(0).toDouble();
            else
                price24h = basePrice;
        }
    }

    QVariantMap stats24h;
    {
        double absDelta = currentPrice - price24h;
        double pctDelta = (price24h > 0) ? (absDelta / price24h) * 100.0 : 0.0;
        stats24h["price_24h_ago"] = price24h;
        stats24h["change_abs"] = std::round(absDelta * 1e8) / 1e8;
        stats24h["change_pct"] = std::round(pctDelta * 100.0) / 100.0;
        stats24h["is_up"] = (absDelta >= 0);
    }
    out["stats24h"] = stats24h;

    // 4. portfolio: вложено / получено / current_value / 24h-дельта
    QVariantMap portfolio;
    {
        double totalBuyRub = 0.0;
        double totalSellRub = 0.0;

        QSqlQuery q(m_db);
        q.prepare(
            "SELECT operation_type, COALESCE(SUM(rub_amount),0) "
            "  FROM crypto_transactions "
            " WHERE user_id = :uid AND currency_id = :cid "
            "   AND operation_type IN ('buy','sell') "
            " GROUP BY operation_type"
        );
        q.bindValue(":uid", userId);
        q.bindValue(":cid", currencyId);
        if (q.exec())
        {
            while (q.next())
            {
                QString op = q.value(0).toString();
                double  sum = q.value(1).toDouble();
                if (op == "buy")  totalBuyRub = sum;
                else if (op == "sell") totalSellRub = sum;
            }
        }

        // Чистые вложения (купил − продал), не уходим в минус
        double netInvested = totalBuyRub - totalSellRub;
        if (netInvested < 0) netInvested = 0;

        double currentValue = std::round(balance * currentPrice * 100.0) / 100.0;
        double profitAbs = std::round((currentValue - netInvested) * 100.0) / 100.0;
        double profitPct = (netInvested > 0)
            ? std::round(((profitAbs / netInvested) * 100.0) * 100.0) / 100.0
            : 0.0;
        double change24hAbs = std::round((balance * (currentPrice - price24h)) * 100.0) / 100.0;
        double change24hPct = (price24h > 0)
            ? std::round(((currentPrice - price24h) / price24h * 100.0) * 100.0) / 100.0
            : 0.0;

        portfolio["total_buy_rub"] = totalBuyRub;
        portfolio["total_sell_rub"] = totalSellRub;
        portfolio["net_invested"] = netInvested;
        portfolio["current_value"] = currentValue;
        portfolio["profit_abs"] = profitAbs;
        portfolio["profit_pct"] = profitPct;
        portfolio["change_24h_abs"] = change24hAbs;
        portfolio["change_24h_pct"] = change24hPct;
    }
    out["portfolio"] = portfolio;

    // 5. История по конкретной монете (последние ~50)
    QVariantList history;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT t.id, t.operation_type, t.coin_amount, t.rub_amount, t.price_per_coin, "
            "       t.description, t.created_at, "
            "       c.symbol, c.icon_color, c.icon_letter "
            "  FROM crypto_transactions t "
            "  JOIN cryptocurrencies c ON c.id = t.currency_id "
            " WHERE t.user_id = :uid AND t.currency_id = :cid "
            " ORDER BY t.created_at DESC LIMIT 50"
        );
        q.bindValue(":uid", userId);
        q.bindValue(":cid", currencyId);
        if (q.exec())
        {
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
                history.append(m);
            }
        }
    }
    out["history"] = history;

    // 6. priceHistory: точки за 24 часа, прорежены до ~150
    QVariantList priceHistory;
    {
        QSqlQuery q(m_db);
        q.prepare(
            "SELECT price, "
            "       (EXTRACT(EPOCH FROM recorded_at) * 1000)::bigint AS ts_ms "
            "  FROM ( "
            "      SELECT price, recorded_at, "
            "             ROW_NUMBER() OVER (ORDER BY recorded_at) AS rn, "
            "             COUNT(*) OVER () AS total "
            "        FROM crypto_price_history "
            "       WHERE currency_id = :cid "
            "         AND recorded_at >= NOW() - INTERVAL '24 hours' "
            "  ) sub "
            " WHERE rn % GREATEST(total / 150, 1) = 0 "
            "    OR rn = 1 "
            " ORDER BY ts_ms ASC"
        );
        q.bindValue(":cid", currencyId);
        if (q.exec())
        {
            while (q.next())
            {
                QVariantMap p;
                p["price"] = q.value(0).toDouble();
                p["ts"] = q.value(1).toLongLong();
                priceHistory.append(p);
            }
        }
        // Если за 24 часа нет вообще никаких записей (только что запустили
        // сервер) — отдадим хотя бы одну точку с текущей ценой.
        if (priceHistory.isEmpty())
        {
            QVariantMap p;
            p["price"] = currentPrice;
            p["ts"] = QDateTime::currentMSecsSinceEpoch();
            priceHistory.append(p);
        }
    }
    out["priceHistory"] = priceHistory;

    return out;
}