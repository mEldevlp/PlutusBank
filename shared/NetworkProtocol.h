#pragma once

#include <QByteArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDataStream>
#include <cstdint>

/*
    Протокол: [4 байта длина (big-endian uint32)] + [JSON payload UTF-8]

    Запрос клиента:
    {
        "method": "loginUser",
        "params": { "phone": "+7...", "password": "..." },
        "id": 42
    }

    Ответ сервера (успех):
    {
        "id": 42,
        "success": true,
        "result": { ... }
    }

    Ответ сервера (ошибка):
    {
        "id": 42,
        "success": false,
        "error": "Описание ошибки"
    }
*/

namespace Protocol
{

    constexpr quint32 HEADER_SIZE = 4;
    constexpr quint32 MAX_PAYLOAD = 16 * 1024 * 1024; // 16 MB

    // --- Сериализация ---

    inline QByteArray pack(const QJsonObject& json)
    {
        QByteArray payload = QJsonDocument(json).toJson(QJsonDocument::Compact);
        QByteArray frame;
        QDataStream stream(&frame, QIODevice::WriteOnly);
        stream.setByteOrder(QDataStream::BigEndian);
        stream << static_cast<quint32>(payload.size());
        frame.append(payload);
        return frame;
    }

    // --- Фрейминг: разбор буфера на отдельные сообщения ---

    inline bool tryExtract(QByteArray& buffer, QJsonObject& out)
    {
        if (static_cast<quint32>(buffer.size()) < HEADER_SIZE)
            return false;

        QDataStream stream(buffer.left(HEADER_SIZE));
        stream.setByteOrder(QDataStream::BigEndian);
        quint32 payloadLen = 0;
        stream >> payloadLen;

        if (payloadLen > MAX_PAYLOAD)
        {
            buffer.clear();
            return false;
        }

        quint32 totalLen = HEADER_SIZE + payloadLen;
        if (static_cast<quint32>(buffer.size()) < totalLen)
            return false;

        QByteArray payload = buffer.mid(HEADER_SIZE, payloadLen);
        buffer.remove(0, totalLen);

        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(payload, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject())
            return false;

        out = doc.object();
        return true;
    }

    // --- Хелперы для формирования запросов/ответов ---

    inline QJsonObject makeRequest(const QString& method, const QJsonObject& params, qint64 id)
    {
        return {
            {"method", method},
            {"params", params},
            {"id",     id}
        };
    }

    inline QJsonObject makeSuccess(qint64 id, const QJsonValue& result)
    {
        return {
            {"id",      id},
            {"success", true},
            {"result",  result}
        };
    }

    inline QJsonObject makeError(qint64 id, const QString& error)
    {
        return {
            {"id",      id},
            {"success", false},
            {"error",   error}
        };
    }

} // namespace Protocol