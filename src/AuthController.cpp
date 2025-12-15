#include "AuthController.h"
#include "UserSession.h"
#include <QDebug>
#include <QRegularExpression>

AuthController::AuthController(QObject* parent)
    : QObject(parent)
    , m_db(DatabaseManager::instance())
{
}

bool AuthController::registerUser(
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
    qDebug() << u"Попытка регистрации:" << firstName << lastName << email;

    // Проверка подключения к БД
    if (!m_db.isConnected()) {
        qWarning() << u"База данных не подключена";
        emit registrationFailed("База данных недоступна");
        return false;
    }

    // Валидация ФИО
    if (firstName.length() < 2 || lastName.length() < 2) {
        emit registrationFailed("Имя и фамилия должны содержать минимум 2 символа");
        return false;
    }

    // Валидация даты рождения (формат YYYY-MM-DD)
    QRegularExpression dateRegex("^\\d{4}-\\d{2}-\\d{2}$");
    if (!dateRegex.match(dateOfBirth).hasMatch()) {
        emit registrationFailed("Некорректный формат даты рождения");
        return false;
    }

    // Валидация паспорта
    if (passportSeries.length() != 4 || passportNumber.length() != 6) {
        emit registrationFailed("Некорректные паспортные данные");
        return false;
    }

    // Валидация email
    QRegularExpression emailRegex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");
    if (!emailRegex.match(email).hasMatch()) {
        emit registrationFailed("Некорректный email");
        return false;
    }

    // Валидация телефона
    if (phone.length() < 10) {
        emit registrationFailed("Некорректный номер телефона");
        return false;
    }

    // Валидация пароля
    if (password.length() < 8) {
        emit registrationFailed("Пароль должен содержать минимум 8 символов");
        return false;
    }

    // Форматируем телефон (+7...)
    QString formattedPhone = phone;
    if (!phone.startsWith("+7")) {
        formattedPhone = "+7" + phone;
    }

    // Регистрация в БД
    if (m_db.registerUser(firstName, lastName, middleName, dateOfBirth,
        passportSeries, passportNumber, email, formattedPhone, password)) {
        qDebug() << u"✓ Регистрация успешна:" << firstName << lastName;
        emit registrationSuccess();
        return true;
    }
    else {
        qWarning() << u"✗ Ошибка регистрации";
        emit registrationFailed("Пользователь с таким email или телефоном уже существует");
        return false;
    }
}

bool AuthController::loginUser(const QString& phone, const QString& password)
{
    qDebug() << u"Попытка входа:" << phone;

    if (!m_db.isConnected()) {
        emit loginFailed("База данных недоступна");
        return false;
    }

    QString formattedPhone = phone;
    if (!phone.startsWith("+7")) {
        formattedPhone = "+7" + phone;
    }

    int userId = m_db.loginUser(formattedPhone, password);

    if (userId > 0) {
        qDebug() << u"✓ Вход успешен. User ID:" << userId;

        QVariantMap userData = m_db.getUserData(userId);

        UserSession::instance().setUserData(
            userId,
            userData["first_name"].toString(),
            userData["last_name"].toString(),
            userData["middle_name"].toString(),
            userData["email"].toString(),
            userData["phone"].toString()
        );

        emit loginSuccess();
        return true;
    }
    else {
        qWarning() << u"✗ Ошибка входа";
        emit loginFailed("Введён неверный логин или пароль");
        return false;
    }
}
