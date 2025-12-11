#include "DatabaseManager.h"
#include <QCryptographicHash>
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

    qDebug() << "Попытка подключения к PostgreSQL...";

    if (!m_db.open()) {
        qWarning() << "Ошибка подключения к БД:" << m_db.lastError().text();
        emit error("Не удалось подключиться к базе данных");
        return false;
    }

    qDebug() << "✓ Успешное подключение к PostgreSQL";
    m_connected = true;
    emit connected();
    return true;
}

void DatabaseManager::disconnect()
{
    if (m_connected) {
        m_db.close();
        m_connected = false;
        qDebug() << "Отключено от PostgreSQL";
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

    // SQL запрос с новыми полями
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
        qWarning() << "Ошибка регистрации:" << query.lastError().text();
        emit error("Ошибка регистрации пользователя");
        return false;
    }

    qDebug() << "✓ Пользователь зарегистрирован:" << firstName << lastName << email;
    return true;
}

bool DatabaseManager::loginUser(const QString& phone, const QString& password)
{
    QSqlQuery query(m_db);
    query.prepare("SELECT password_hash FROM users WHERE phone = :phone");
    query.bindValue(":phone", phone);

    if (!query.exec() || !query.next()) {
        emit error("Неверный номер телефона или пароль");
        return false;
    }

    QString storedHash = query.value(0).toString();
    if (!verifyPassword(password, storedHash)) {
        emit error("Неверный номер телефона или пароль");
        return false;
    }

    qDebug() << "✓ Успешный вход:" << phone;
    return true;
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
