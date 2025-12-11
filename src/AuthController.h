#pragma once

#include <QObject>
#include <QString>
#include "DatabaseManager.h"

class AuthController : public QObject
{
    Q_OBJECT

public:
    explicit AuthController(QObject* parent = nullptr);

    // Регистрация с полными данными
    Q_INVOKABLE bool registerUser(
        const QString& firstName,
        const QString& lastName,
        const QString& middleName,
        const QString& dateOfBirth,
        const QString& passportSeries,
        const QString& passportNumber,
        const QString& email,
        const QString& phone,
        const QString& password
    );

    Q_INVOKABLE bool loginUser(const QString& phone, const QString& password);

signals:
    void registrationSuccess();
    void registrationFailed(const QString& error);
    void loginSuccess();
    void loginFailed(const QString& error);

private:
    DatabaseManager& m_db;
};