#pragma once

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <functional>
#include <QHash>

class DatabaseManager;

class RequestHandler : public QObject
{
    Q_OBJECT

public:
    explicit RequestHandler(QObject* parent = nullptr);

    // Обработать запрос, вернуть JSON-ответ
    QJsonObject handle(const QJsonObject& request, const QString& clientTag);

private:
    using Handler = std::function<QJsonObject(const QJsonObject& params, const QString& clientTag)>;
    QHash<QString, Handler> m_handlers;

    DatabaseManager& m_db;

    void registerHandlers();

    // Конвертеры QVariant <-> QJson
    static QJsonArray    variantListToJson(const QVariantList& list);
    static QJsonObject   variantMapToJson(const QVariantMap& map);
};
