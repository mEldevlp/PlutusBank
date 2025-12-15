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
    m_db.setPort(5432);
    m_db.setDatabaseName("plutusbank");
    m_db.setUserName("postgres");
    m_db.setPassword("root");

    qDebug() << u"Попытка подключения к PostgreSQL...";

    if (!m_db.open()) {
        qWarning() << u"Ошибка подключения к БД:" << m_db.lastError().text();
        emit error("Не удалось подключиться к базе данных");
        return false;
    }

    qDebug() << u"✓ Успешное подключение к PostgreSQL";
    m_connected = true;
    emit connected();
    return true;
}

void DatabaseManager::disconnect()
{
    if (m_connected) {
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

    if (!query.exec()) {
        qWarning() << u"Ошибка регистрации:" << query.lastError().text();
        emit error("Ошибка регистрации пользователя");
        return false;
    }

    qDebug() << u"✓ Пользователь зарегистрирован:" << firstName << lastName << email;
    return true;
}

int DatabaseManager::loginUser(const QString& phone, const QString& password)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT id, password_hash FROM users WHERE phone = :phone");
    query.bindValue(":phone", phone);

    if (!query.exec() || !query.next()) {
        emit error("Неверный номер телефона или пароль");
        return -1;  // -1 означает ошибку
    }

    int userId = query.value(0).toInt();
    QString storedHash = query.value(1).toString();

    if (!verifyPassword(password, storedHash)) {
        emit error("Неверный номер телефона или пароль");
        return -1;
    }

    qDebug() << u"✓ Успешный вход. User ID:" << userId;
    return userId;
}

QVariantMap DatabaseManager::getUserData(int userId)
{
    QVariantMap userData;
    QSqlQuery query(m_db);

    query.prepare(
        "SELECT first_name, last_name, middle_name, email, phone "
        "FROM users WHERE id = :userId"
    );
    query.bindValue(":userId", userId);

    if (query.exec() && query.next()) {
        userData["first_name"] = query.value(0).toString();
        userData["last_name"] = query.value(1).toString();
        userData["middle_name"] = query.value(2).toString();
        userData["email"] = query.value(3).toString();
        userData["phone"] = query.value(4).toString();

        qDebug() << u"✓ Данные пользователя загружены:" << userData["last_name"].toString();
    }
    else {
        qWarning() << u"Ошибка загрузки данных пользователя:" << query.lastError().text();
    }

    return userData;
}

int DatabaseManager::getUserAccountId(int userId)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT id FROM accounts WHERE user_id = :userId LIMIT 1");
    query.bindValue(":userId", userId);

    if (query.exec() && query.next()) {
        return query.value(0).toInt();
    }

    return -1;
}

QVariantList DatabaseManager::getUserCards(int userId)
{
    QVariantList cards;

    // Сначала получаем account_id пользователя
    int accountId = getUserAccountId(userId);
    if (accountId <= 0) {
        qDebug() << u"У пользователя нет счета, карты отсутствуют";
        return cards;
    }

    QSqlQuery query(m_db);
    query.prepare(
        "SELECT id, card_number, card_holder_name, card_type, card_brand, "
        "is_active, is_blocked, expiry_date, daily_limit, monthly_limit "
        "FROM cards "
        "WHERE account_id = :accountId "
        "ORDER BY created_at DESC"
    );
    query.bindValue(":accountId", accountId);

    if (query.exec()) {
        while (query.next()) {
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

            cards.append(card);
        }
        qDebug() << u"✓ Загружено карт:" << cards.size();
    }
    else {
        qWarning() << u"Ошибка загрузки карт:" << query.lastError().text();
    }

    return cards;
}

double DatabaseManager::getTotalDebitBalance(int userId)
{
    // Сначала получаем account_id пользователя
    int accountId = getUserAccountId(userId);
    if (accountId <= 0) {
        qDebug() << u"У пользователя нет счета";
        return 0.0;
    }

    QSqlQuery query(m_db);

    // Получаем баланс счета (accounts.balance)
    // В текущей схеме БД баланс хранится в таблице accounts, а не cards
    query.prepare("SELECT balance FROM accounts WHERE id = :accountId");
    query.bindValue(":accountId", accountId);

    if (query.exec() && query.next()) {
        double balance = query.value(0).toDouble();
        qDebug() << u"✓ Баланс счета:" << balance;
        return balance;
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

int DatabaseManager::createAccount(int userId, const QString& accountType)
{
    QSqlQuery query(m_db);

    // Генерируем номер счёта (20 цифр)
    QString accountNumber = "40817810";  // Префикс для физлиц РФ
    for (int i = 0; i < 12; i++) {
        accountNumber += QString::number(QRandomGenerator::global()->bounded(10));
    }

    // Определяем начальный баланс
    double initialBalance = 0.0;
    if (accountType == "credit") {
        initialBalance = 50000.0;  // Кредитный лимит
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

    if (!query.exec() || !query.next()) {
        qWarning() << u"Ошибка создания счёта:" << query.lastError().text();
        return -1;
    }

    int accountId = query.value(0).toInt();
    qDebug() << u"✓ Счёт создан:" << accountNumber << "ID:" << accountId;

    return accountId;
}

QString DatabaseManager::generateCardNumber(const QString& brand)
{
    QSqlQuery query(m_db);

    // Вызываем PostgreSQL функцию generate_valid_card_number
    query.prepare("SELECT generate_valid_card_number(:brand)");
    query.bindValue(":brand", brand);

    if (!query.exec() || !query.next()) {
        qWarning() << u"Ошибка генерации номера карты:" << query.lastError().text();
        return QString();
    }

    QString cardNumber = query.value(0).toString();
    qDebug() << u"✓ Сгенерирован номер карты:" << cardNumber;

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

    if (!query.exec()) {
        qWarning() << u"Ошибка создания карты:" << query.lastError().text();
        return false;
    }

    qDebug() << u"✓ Карта создана в БД";
    return true;
}