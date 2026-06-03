#pragma once

#include <QString>
#include <QStringList>
#include <functional>
#include <stdexcept>

/*
    TestRunner — лёгкий «беговая дорожка» для сценарных тестов.

    Лямбда-кейс возвращает QString с краткими деталями того, что именно
    было проверено (выводится серым после "[ OK ]"). При несоответствии
    бросает TestFailure — runner ловит и помечает кейс провалившимся,
    не падая, чтобы выполнить остальные тесты.
*/

class TestFailure : public std::runtime_error
{
public:
    explicit TestFailure(const QString& msg)
        : std::runtime_error(msg.toStdString()), m_msg(msg) {}

    const QString& message() const { return m_msg; }

private:
    QString m_msg;
};

class TestRunner
{
public:
    TestRunner();

    // Заголовок логического раздела тестов
    void section(const QString& title);

    // Запустить один кейс. body возвращает строку с деталями (что именно проверено)
    void test(const QString& name, const std::function<QString()>& body);

    // Итоговая сводка. Возвращает 0 при полном успехе, 1 при провалах.
    int summary() const;

    int passed() const { return m_passed; }
    int failed() const { return m_failed; }

private:
    int     m_passed     = 0;
    int     m_failed     = 0;
    qint64  m_startMsec  = 0;
    QStringList m_failedNames;
};

// ---- помощники для проверки условий ----

void expect       (bool condition,         const QString& message);
void expectTrue   (bool value,             const QString& field);
void expectFalse  (bool value,             const QString& field);
void expectEq     (qint64 actual, qint64 expected, const QString& field);
void expectGt     (double actual, double  threshold, const QString& field);
void expectGe     (double actual, double  threshold, const QString& field);
void expectNonEmptyStr  (const QString&    value, const QString& field);
