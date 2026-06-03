#include "TestRunner.h"
#include "Console.h"

#include <QDateTime>

TestRunner::TestRunner()
{
    m_startMsec = QDateTime::currentMSecsSinceEpoch();
}

void TestRunner::section(const QString& title)
{
    Console::println();
    Console::println(QStringLiteral("%1=== %2 ===%3")
        .arg(QString::fromUtf8(Console::BOLD),
             title,
             QString::fromUtf8(Console::RESET)));
}

void TestRunner::test(const QString& name, const std::function<QString()>& body)
{
    QString details;
    QString errorMsg;
    bool    ok = false;

    try
    {
        details = body();
        ok = true;
    }
    catch (const TestFailure& e)
    {
        errorMsg = e.message();
    }
    catch (const std::exception& e)
    {
        errorMsg = QString::fromUtf8(e.what());
    }
    catch (...)
    {
        errorMsg = QStringLiteral("неизвестное исключение");
    }

    if (ok)
    {
        ++m_passed;
        QString line = QStringLiteral("  %1[ OK ]%2  %3")
            .arg(QString::fromUtf8(Console::GREEN),
                 QString::fromUtf8(Console::RESET),
                 name);
        if (!details.isEmpty())
        {
            line += QStringLiteral("  %1- %2%3")
                .arg(QString::fromUtf8(Console::GREY),
                     details,
                     QString::fromUtf8(Console::RESET));
        }
        Console::println(line);
    }
    else
    {
        ++m_failed;
        m_failedNames << name;
        const QString line = QStringLiteral("  %1[FAIL]%2  %3  %1- %4%2")
            .arg(QString::fromUtf8(Console::RED),
                 QString::fromUtf8(Console::RESET),
                 name,
                 errorMsg);
        Console::println(line);
    }
}

int TestRunner::summary() const
{
    const qint64 elapsedMs = QDateTime::currentMSecsSinceEpoch() - m_startMsec;
    const double seconds   = elapsedMs / 1000.0;

    Console::println();
    Console::println(QStringLiteral(
        "============================================================"));

    const bool allOk = (m_failed == 0);
    const char* color = allOk ? Console::GREEN : Console::RED;
    const QString headline = allOk
        ? QStringLiteral("ВСЕ ТЕСТЫ ПРОЙДЕНЫ")
        : QStringLiteral("ЕСТЬ ПРОВАЛЕННЫЕ ТЕСТЫ");

    Console::println(QStringLiteral("  %1%2%3%4")
        .arg(QString::fromUtf8(Console::BOLD),
             QString::fromUtf8(color),
             headline,
             QString::fromUtf8(Console::RESET)));

    Console::println(QStringLiteral(
        "  Пройдено: %1%2%3,  Провалено: %4%5%6,  Время: %7 с")
        .arg(QString::fromUtf8(Console::GREEN))
        .arg(m_passed)
        .arg(QString::fromUtf8(Console::RESET))
        .arg(QString::fromUtf8(Console::RED))
        .arg(m_failed)
        .arg(QString::fromUtf8(Console::RESET))
        .arg(QString::number(seconds, 'f', 2)));

    if (!allOk)
    {
        Console::println();
        Console::println(QStringLiteral("  Провалившиеся кейсы:"));
        for (const QString& name : m_failedNames)
        {
            Console::println(QStringLiteral("    %1- %2%3")
                .arg(QString::fromUtf8(Console::RED),
                     name,
                     QString::fromUtf8(Console::RESET)));
        }
    }

    Console::println(QStringLiteral(
        "============================================================"));

    return allOk ? 0 : 1;
}

// ============================================================
//  Помощники для проверки условий
// ============================================================

void expect(bool condition, const QString& message)
{
    if (!condition)
        throw TestFailure(message);
}

void expectTrue(bool value, const QString& field)
{
    if (!value)
        throw TestFailure(QStringLiteral("ожидалось true: %1").arg(field));
}

void expectFalse(bool value, const QString& field)
{
    if (value)
        throw TestFailure(QStringLiteral("ожидалось false: %1").arg(field));
}

void expectEq(qint64 actual, qint64 expected, const QString& field)
{
    if (actual != expected)
        throw TestFailure(QStringLiteral("%1: ожидалось %2, получили %3")
            .arg(field).arg(expected).arg(actual));
}

void expectGt(double actual, double threshold, const QString& field)
{
    if (!(actual > threshold))
        throw TestFailure(QStringLiteral("%1: ожидалось > %2, получили %3")
            .arg(field).arg(threshold).arg(actual));
}

void expectGe(double actual, double threshold, const QString& field)
{
    if (!(actual >= threshold))
        throw TestFailure(QStringLiteral("%1: ожидалось >= %2, получили %3")
            .arg(field).arg(threshold).arg(actual));
}

void expectNonEmptyStr(const QString& value, const QString& field)
{
    if (value.isEmpty())
        throw TestFailure(QStringLiteral("%1: ожидалась непустая строка").arg(field));
}
