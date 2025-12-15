#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include "DatabaseManager.h"

class CardController : public QObject
{
    Q_OBJECT

public:
    explicit CardController(QObject* parent = nullptr);

    // ============ ДОБАВЛЕНО: Методы для создания карты ============
    Q_INVOKABLE void createCard(
        const QString& cardType,    // "debit" или "credit"
        const QString& cardBrand    // "visa", "mastercard", "mir"
    );

    Q_INVOKABLE QString generateCVC();    // Генерация 3-значного CVC
    Q_INVOKABLE QString generatePIN();    // Генерация 4-значного PIN
    // ==============================================================

signals:
    // ============ ДОБАВЛЕНО: Сигналы для QML ============
    void cardCreated(const QVariantMap& cardData);  // Успешное создание
    void cardCreationFailed(const QString& error);  // Ошибка
    void creationProgress(const QString& message);  // Прогресс создания
    // ====================================================

private:
    DatabaseManager& m_db;

    QString hashData(const QString& data);  // Хеширование CVC/PIN
};