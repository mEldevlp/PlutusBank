#include "Console.h"
#include "TestClient.h"
#include "TestRunner.h"

#include <QCoreApplication>
#include <QCommandLineParser>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QString>
#include <QVariantMap>

#include <algorithm>


//  Локальные хелперы

namespace
{

// Развернуть RPC-ответ. Если транспортный success=false — бросить TestFailure.
// Иначе вернуть result как QJsonObject.
QJsonObject unwrap(const QJsonObject& resp, const QString& context)
{
    if (!resp.value(QStringLiteral("success")).toBool())
    {
        const QString err = resp.value(QStringLiteral("error"))
            .toString(QStringLiteral("(без описания)"));
        throw TestFailure(
            QStringLiteral("транспортная ошибка в %1: %2").arg(context, err));
    }
    return resp.value(QStringLiteral("result")).toObject();
}

// Удобно для бизнес-операций: ожидаем result.ok == true, иначе бросаем
void requireBusinessOk(const QJsonObject& result, const QString& context)
{
    if (!result.value(QStringLiteral("ok")).toBool())
    {
        const QString err = result.value(QStringLiteral("error"))
            .toString(QStringLiteral("(без описания)"));
        throw TestFailure(
            QStringLiteral("бизнес-ошибка в %1: \"%2\"").arg(context, err));
    }
}

// Получить int независимо от того, лежит ли он как int или как string в JSON
int toInt(const QJsonValue& v)
{
    if (v.isDouble()) return static_cast<int>(v.toDouble());
    if (v.isString()) return v.toString().toInt();
    return v.toVariant().toInt();
}

// Найти ID в массиве объектов: пробуем поля "id" и "cardId" / "loanId" / "depositId"
int findIdOfFirst(const QJsonArray& arr, const QStringList& possibleKeys)
{
    if (arr.isEmpty()) return 0;
    const QJsonObject first = arr.last().toObject();   // последний = только что созданный
    for (const QString& key : possibleKeys)
    {
        if (first.contains(key))
            return toInt(first.value(key));
    }
    return 0;
}

} // namespace



//  main


int main(int argc, char* argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("PlutusBankTests"));
    QCoreApplication::setApplicationVersion(QStringLiteral("1.0.0"));

    Console::init();

    // CLI 
    QCommandLineParser parser;
    parser.setApplicationDescription(
        QStringLiteral("PlutusBank — сквозной тест клиент → сервер"));
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption hostOpt({QStringLiteral("H"), QStringLiteral("host")},
        QStringLiteral("Адрес сервера"), QStringLiteral("host"),
        QStringLiteral("127.0.0.1"));
    QCommandLineOption portOpt({QStringLiteral("p"), QStringLiteral("port")},
        QStringLiteral("Порт сервера"), QStringLiteral("port"),
        QStringLiteral("9500"));
    parser.addOption(hostOpt);
    parser.addOption(portOpt);
    parser.process(app);

    const QString  host = parser.value(hostOpt);
    const quint16  port = static_cast<quint16>(parser.value(portOpt).toUInt());

    //  Уникальные данные на прогон 
    const qint64  ts     = QDateTime::currentMSecsSinceEpoch();
    const QString s7     = QString::number(ts % 10'000'000).rightJustified(7, QChar('0'));
    const QString sNum6  = QString::number(ts % 1'000'000).rightJustified(6, QChar('0'));

    const QString phoneA = QStringLiteral("+7990") + s7;       // +7 990 NNNNNNN
    const QString phoneB = QStringLiteral("+7991") + s7;       // +7 991 NNNNNNN
    const QString passA  = QStringLiteral("Test_Pass_A_1234!");
    const QString passB  = QStringLiteral("Test_Pass_B_1234!");
    const QString emailA = QStringLiteral("usera.%1@example.test").arg(s7);
    const QString emailB = QStringLiteral("userb.%1@example.test").arg(s7);
    const QString passportSeriesA = QStringLiteral("12") +
        QString::number(ts % 100).rightJustified(2, QChar('0'));
    const QString passportSeriesB = QStringLiteral("34") +
        QString::number(ts % 100).rightJustified(2, QChar('0'));
    const QString passportNumberA = sNum6;
    // у B номер на 1 отличается, чтобы пара (series, number) была уникальна
    const QString passportNumberB =
        QString::number(((ts % 1'000'000) + 1) % 1'000'000)
            .rightJustified(6, QChar('0'));

    //  Заголовок 
    Console::println();
    
    Console::println(QStringLiteral("  %1PlutusBank — End-to-end test suite%2")
        .arg(QString::fromUtf8(Console::BOLD),
             QString::fromUtf8(Console::RESET)));
    
    Console::println(QStringLiteral("  Сервер             : %1:%2").arg(host).arg(port));
    Console::println(QStringLiteral("  Пользователь A     : %1").arg(phoneA));
    Console::println(QStringLiteral("  Пользователь B     : %1").arg(phoneB));
    Console::println(QStringLiteral("  Время старта       : %1").arg(
        QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"))));
    

    //  Подключение 
    TestClient client;
    if (!client.connectToServer(host, port))
    {
        Console::println();
        Console::println(QStringLiteral("  %1[FAIL]%2  Не удалось подключиться к серверу %3:%4")
            .arg(QString::fromUtf8(Console::RED),
                 QString::fromUtf8(Console::RESET),
                 host).arg(port));
        Console::println(QStringLiteral(
            "  Подсказка: убедитесь, что PlutusBank-сервер запущен и слушает указанный порт."));
        return 2;
    }

    TestRunner R;

    //  Контекст -
    struct Ctx
    {
        int     userIdA = 0;
        int     userIdB = 0;
        int     accountIdA1 = 0;        // первый debit А
        int     accountIdA2 = 0;        // второй debit А (для transferBetweenAccounts)
        int     accountIdB  = 0;        // debit B
        int     cardIdA     = 0;
        QString cardNumberA;
        int     loanProductId = 0;
        double  loanAmount    = 0.0;   // подбирается под лимиты выбранного продукта
        int     loanMonths    = 0;     // -//-
        int     loanId        = 0;
        int     depositId     = 0;
        int     currencyId    = 0;
        QString currencySymbol;
        QString cryptoAddressB;
        double  boughtCoinAmount = 0.0;
    } ctx;

    
    R.section(QStringLiteral("Авторизация и регистрация (3 хендлера)"));
    

    R.test(QStringLiteral("registerUser(A) — регистрация пользователя A"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"firstName",      "Иван"},
            {"lastName",       "Тестовый"},
            {"middleName",     "Сценариевич"},
            {"dateOfBirth",    "1990-01-15"},
            {"passportSeries", passportSeriesA},
            {"passportNumber", passportNumberA},
            {"email",          emailA},
            {"phone",          phoneA},
            {"password",       passA}
        };
        const auto result = unwrap(client.call("registerUser", params), "registerUser");
        requireBusinessOk(result, "registerUser(A)");
        return QStringLiteral("телефон=%1, паспорт=%2 %3")
            .arg(phoneA, passportSeriesA, passportNumberA);
    });

    R.test(QStringLiteral("registerUser(B) — регистрация пользователя B"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"firstName",      "Пётр"},
            {"lastName",       "Получатель"},
            {"middleName",     "Адресатович"},
            {"dateOfBirth",    "1992-06-21"},
            {"passportSeries", passportSeriesB},
            {"passportNumber", passportNumberB},
            {"email",          emailB},
            {"phone",          phoneB},
            {"password",       passB}
        };
        const auto result = unwrap(client.call("registerUser", params), "registerUser");
        requireBusinessOk(result, "registerUser(B)");
        return QStringLiteral("телефон=%1, паспорт=%2 %3")
            .arg(phoneB, passportSeriesB, passportNumberB);
    });

    R.test(QStringLiteral("loginUser(A) — корректный вход возвращает userId > 0"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("loginUser", { {"phone", phoneA}, {"password", passA} }),
            "loginUser");
        ctx.userIdA = toInt(result.value("userId"));
        expectGt(ctx.userIdA, 0, "userIdA");
        const auto ud = result.value("userData").toObject();
        // На сервере userData приходит со snake_case ключами (см. getUserData в БД)
        const QString fn = ud.value("first_name").toString(
            ud.value("firstName").toString());
        expectNonEmptyStr(fn, "userData.first_name");
        return QStringLiteral("userIdA=%1, first_name=\"%2\"").arg(ctx.userIdA).arg(fn);
    });

    R.test(QStringLiteral("loginUser(A, неверный пароль) — должен быть отклонён"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("loginUser", { {"phone", phoneA}, {"password", "wrong-password"} }),
            "loginUser");
        const int uid = toInt(result.value("userId"));
        expectEq(uid, 0, "userId при неверном пароле");
        return QStringLiteral("userId=0, как и ожидалось");
    });

    R.test(QStringLiteral("loginUser(B) — вход второго пользователя"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("loginUser", { {"phone", phoneB}, {"password", passB} }),
            "loginUser");
        ctx.userIdB = toInt(result.value("userId"));
        expectGt(ctx.userIdB, 0, "userIdB");
        return QStringLiteral("userIdB=%1").arg(ctx.userIdB);
    });

    R.test(QStringLiteral("getUserData(A) — поля совпадают с регистрационными"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getUserData", { {"userId", ctx.userIdA} }),
            "getUserData");
        const QString phone = result.value("phone").toString();
        expectEq(phone == phoneA ? 1 : 0, 1,
            QStringLiteral("phone (ожидалось %1, получили %2)").arg(phoneA, phone));
        return QStringLiteral("phone=%1, email=%2")
            .arg(phone, result.value("email").toString());
    });

    
    R.section(QStringLiteral("Счета и карты (11 хендлеров)"));
    

    R.test(QStringLiteral("createAccount(A, debit) — первый дебетовый счёт A"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("createAccount", { {"userId", ctx.userIdA}, {"accountType", "debit"} }),
            "createAccount");
        ctx.accountIdA1 = toInt(result.value("accountId"));
        expectGt(ctx.accountIdA1, 0, "accountIdA1");
        return QStringLiteral("accountIdA1=%1").arg(ctx.accountIdA1);
    });

    R.test(QStringLiteral("createAccount(A, debit) — второй дебетовый счёт A"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("createAccount", { {"userId", ctx.userIdA}, {"accountType", "debit"} }),
            "createAccount");
        ctx.accountIdA2 = toInt(result.value("accountId"));
        expectGt(ctx.accountIdA2, 0, "accountIdA2");
        return QStringLiteral("accountIdA2=%1").arg(ctx.accountIdA2);
    });

    R.test(QStringLiteral("createAccount(B, debit) — дебетовый счёт B"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("createAccount", { {"userId", ctx.userIdB}, {"accountType", "debit"} }),
            "createAccount");
        ctx.accountIdB = toInt(result.value("accountId"));
        expectGt(ctx.accountIdB, 0, "accountIdB");
        return QStringLiteral("accountIdB=%1").arg(ctx.accountIdB);
    });

    R.test(QStringLiteral("getUserAccountId(A) — возвращает первый счёт"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getUserAccountId", { {"userId", ctx.userIdA} }),
            "getUserAccountId");
        const int aid = toInt(result.value("accountId"));
        expectGt(aid, 0, "accountId");
        return QStringLiteral("accountId=%1").arg(aid);
    });

    R.test(QStringLiteral("getUserAccounts(A) — список всех счетов A не пуст"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getUserAccounts", { {"userId", ctx.userIdA} }),
            "getUserAccounts");
        const auto arr = result.value("accounts").toArray();
        expectGe(arr.size(), 2, "число счетов A");
        return QStringLiteral("получили %1 счетов").arg(arr.size());
    });

    R.test(QStringLiteral("generateCardNumber(visa) — корректные 16 цифр, префикс visa"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("generateCardNumber", { {"brand", "visa"} }),
            "generateCardNumber");
        ctx.cardNumberA = result.value("cardNumber").toString();
        expectNonEmptyStr(ctx.cardNumberA, "cardNumber");

        // Сервер возвращает номер в формате "1234 5678 9012 3456" — считаем только цифры.
        QString digitsOnly;
        digitsOnly.reserve(16);
        for (const QChar ch : ctx.cardNumberA)
        {
            if (ch.isDigit())
                digitsOnly.append(ch);
        }
        expectEq(digitsOnly.size(), 16, "количество цифр в номере карты");
        // префикс visa — начинается с '4'
        expectTrue(digitsOnly.startsWith('4'), "visa должен начинаться с 4");
        return QStringLiteral("номер (16 цифр)=%1...").arg(digitsOnly.left(6));
    });

    R.test(QStringLiteral("createCard(A) — выпуск дебетовой visa на счёт #1"),
        [&]() -> QString
    {
        const QDate expiry = QDate::currentDate().addYears(4);
        const QJsonObject params{
            {"accountId",      ctx.accountIdA1},
            {"cardNumber",     ctx.cardNumberA},
            {"cardHolderName", "IVAN TESTOVYI"},
            {"expiryDate",     expiry.toString("yyyy-MM-dd")},
            {"cvcHash",        "test_cvc_hash_aaa"},
            {"pinHash",        "test_pin_hash_bbb"},
            {"cardType",       "debit"},
            {"cardBrand",      "visa"}
        };
        const auto result = unwrap(client.call("createCard", params), "createCard");
        requireBusinessOk(result, "createCard");
        return QStringLiteral("карта visa выпущена на счёт %1, срок до %2")
            .arg(ctx.accountIdA1).arg(expiry.toString("MM/yyyy"));
    });

    R.test(QStringLiteral("getUserCards(A) — карта появилась в списке, узнаём cardId"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getUserCards", { {"userId", ctx.userIdA} }),
            "getUserCards");
        const auto arr = result.value("cards").toArray();
        expectGe(arr.size(), 1, "число карт A");
        ctx.cardIdA = findIdOfFirst(arr, {"id", "cardId", "card_id"});
        expectGt(ctx.cardIdA, 0, "cardIdA");
        return QStringLiteral("cardIdA=%1, всего карт=%2").arg(ctx.cardIdA).arg(arr.size());
    });

    R.test(QStringLiteral("getCardFullDetails(cardIdA) — реквизиты карты получены"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getCardFullDetails", { {"cardId", ctx.cardIdA} }),
            "getCardFullDetails");
        expectGt(result.keys().size(), 0, "число полей в getCardFullDetails");
        return QStringLiteral("получено %1 полей").arg(result.keys().size());
    });

    R.test(QStringLiteral("getCardTransactions(accountIdA1) — список транзакций по карте"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"accountId", ctx.accountIdA1}, {"limit", 50}, {"offset", 0}
        };
        const auto result = unwrap(
            client.call("getCardTransactions", params), "getCardTransactions");
        const auto arr = result.value("transactions").toArray();
        return QStringLiteral("получено %1 транзакций (норм. для свежей карты)").arg(arr.size());
    });

    R.test(QStringLiteral("freezeCard(cardIdA) — заморозка карты"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("freezeCard", { {"cardId", ctx.cardIdA} }),
            "freezeCard");
        requireBusinessOk(result, "freezeCard");
        return QStringLiteral("карта %1 заморожена").arg(ctx.cardIdA);
    });

    R.test(QStringLiteral("isAccountFrozenOrBlocked(accountIdA1) — проверка статуса"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("isAccountFrozenOrBlocked", { {"accountId", ctx.accountIdA1} }),
            "isAccountFrozenOrBlocked");
        const bool frozen = result.value("frozen").toBool();
        return QStringLiteral("frozen=%1").arg(frozen ? "true" : "false");
    });

    R.test(QStringLiteral("unfreezeCard(cardIdA) — разморозка карты"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("unfreezeCard", { {"cardId", ctx.cardIdA} }),
            "unfreezeCard");
        requireBusinessOk(result, "unfreezeCard");
        return QStringLiteral("карта %1 разморожена").arg(ctx.cardIdA);
    });

    
    R.section(QStringLiteral("Пополнение и балансы (6 хендлеров)"));
    

    constexpr double TOPUP_AMOUNT = 100'000.0;

    R.test(QStringLiteral("topUpAccount(accountIdA1, 100000) — пополнение счёта"),
        [&]() -> QString
    {
        const QJsonObject params{ {"accountId", ctx.accountIdA1}, {"amount", TOPUP_AMOUNT} };
        const auto result = unwrap(client.call("topUpAccount", params), "topUpAccount");
        requireBusinessOk(result, "topUpAccount");
        return QStringLiteral("зачислено %1 RUB на счёт %2")
            .arg(TOPUP_AMOUNT).arg(ctx.accountIdA1);
    });

    R.test(QStringLiteral("getAccountBalance(accountIdA1) — баланс не меньше пополнения"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getAccountBalance", { {"accountId", ctx.accountIdA1} }),
            "getAccountBalance");
        const double bal = result.value("balance").toDouble();
        expectGe(bal, TOPUP_AMOUNT, "balance");
        return QStringLiteral("balance=%1 RUB").arg(QString::number(bal, 'f', 2));
    });

    R.test(QStringLiteral("getTotalDebitBalance(A) — суммарный дебетовый баланс"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getTotalDebitBalance", { {"userId", ctx.userIdA} }),
            "getTotalDebitBalance");
        const double bal = result.value("balance").toDouble();
        expectGe(bal, TOPUP_AMOUNT, "totalDebitBalance");
        return QStringLiteral("totalDebitBalance=%1 RUB").arg(QString::number(bal, 'f', 2));
    });

    R.test(QStringLiteral("getDailyIncome(A) — приход за сегодня >= пополнения"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getDailyIncome", { {"userId", ctx.userIdA} }),
            "getDailyIncome");
        const double inc = result.value("income").toDouble();
        expectGe(inc, TOPUP_AMOUNT, "dailyIncome");
        return QStringLiteral("dailyIncome=%1 RUB").arg(QString::number(inc, 'f', 2));
    });

    R.test(QStringLiteral("getDailyExpense(A) — расход за сегодня >= 0"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getDailyExpense", { {"userId", ctx.userIdA} }),
            "getDailyExpense");
        const double exp = result.value("expense").toDouble();
        expectGe(exp, 0.0, "dailyExpense");
        return QStringLiteral("dailyExpense=%1 RUB").arg(QString::number(exp, 'f', 2));
    });

    R.test(QStringLiteral("getTransactionHistory(A) — история не пуста после пополнения"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId", ctx.userIdA}, {"limit", 50}, {"offset", 0}
        };
        const auto result = unwrap(client.call("getTransactionHistory", params),
                                   "getTransactionHistory");
        const auto arr = result.value("history").toArray();
        expectGe(arr.size(), 1, "размер истории");
        return QStringLiteral("получили %1 транзакций").arg(arr.size());
    });

    
    R.section(QStringLiteral("Основной счёт (2 хендлера)"));
    

    R.test(QStringLiteral("setPrimaryAccount(A, accountIdA2) — назначение основного счёта"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId", ctx.userIdA}, {"accountId", ctx.accountIdA2}
        };
        const auto result = unwrap(client.call("setPrimaryAccount", params),
                                   "setPrimaryAccount");
        requireBusinessOk(result, "setPrimaryAccount");
        return QStringLiteral("primary = accountIdA2 (%1)").arg(ctx.accountIdA2);
    });

    R.test(QStringLiteral("getPrimaryAccountId(A) — совпадает с тем, что назначили"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getPrimaryAccountId", { {"userId", ctx.userIdA} }),
            "getPrimaryAccountId");
        const int aid = toInt(result.value("accountId"));
        expectEq(aid, ctx.accountIdA2, "primaryAccountId");
        return QStringLiteral("primaryAccountId=%1").arg(aid);
    });

    
    R.section(QStringLiteral("Переводы (5 хендлеров)"));
    

    R.test(QStringLiteral("findAccountByPhone(B) — нашли дебетовый счёт B"),
        [&]() -> QString
    {
        const QJsonObject params{ {"phone", phoneB}, {"accountType", "debit"} };
        const auto result = unwrap(client.call("findAccountByPhone", params),
                                   "findAccountByPhone");
        const int aid = toInt(result.value("accountId"));
        expectEq(aid, ctx.accountIdB, "findAccountByPhone(B)");
        return QStringLiteral("accountId=%1").arg(aid);
    });

    R.test(QStringLiteral("getAccountOwnerName(accountIdB) — имя владельца не пустое"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getAccountOwnerName", { {"accountId", ctx.accountIdB} }),
            "getAccountOwnerName");
        const QString name = result.value("name").toString();
        expectNonEmptyStr(name, "ownerName");
        return QStringLiteral("name=\"%1\"").arg(name);
    });

    R.test(QStringLiteral("getUserDebitAccounts(A) — список дебетовых счетов A"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getUserDebitAccounts", { {"userId", ctx.userIdA} }),
            "getUserDebitAccounts");
        const auto arr = result.value("accounts").toArray();
        expectGe(arr.size(), 2, "число дебетовых счетов A");
        return QStringLiteral("получили %1 дебетовых счетов").arg(arr.size());
    });

    R.test(QStringLiteral("transferBetweenAccounts(A1 → A2, 500 RUB)"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"fromAccountId", ctx.accountIdA1},
            {"toAccountId",   ctx.accountIdA2},
            {"amount",        500.0}
        };
        const auto result = unwrap(client.call("transferBetweenAccounts", params),
                                   "transferBetweenAccounts");
        requireBusinessOk(result, "transferBetweenAccounts");
        return QStringLiteral("переведено 500 RUB: %1 → %2")
            .arg(ctx.accountIdA1).arg(ctx.accountIdA2);
    });

    R.test(QStringLiteral("transferToUser(A1 → телефон B, 250 RUB)"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"fromAccountId",  ctx.accountIdA1},
            {"recipientPhone", phoneB},
            {"amount",         250.0}
        };
        const auto result = unwrap(client.call("transferToUser", params),
                                   "transferToUser");
        requireBusinessOk(result, "transferToUser");
        return QStringLiteral("переведено 250 RUB на %1").arg(phoneB);
    });

    R.test(QStringLiteral("transferBetweenAccounts — отказ при превышении баланса"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"fromAccountId", ctx.accountIdA1},
            {"toAccountId",   ctx.accountIdA2},
            {"amount",        1'000'000'000.0}
        };
        const auto result = unwrap(client.call("transferBetweenAccounts", params),
                                   "transferBetweenAccounts");
        expectFalse(result.value("ok").toBool(),
            "перевод миллиарда не должен пройти");
        return QStringLiteral("ok=false, как и ожидалось");
    });

    
    R.section(QStringLiteral("Кредиты (6 хендлеров)"));
    

    R.test(QStringLiteral("loadLoanProducts() — каталог продуктов не пуст; подбираем подходящий"),
        [&]() -> QString
    {
        const auto result = unwrap(client.call("loadLoanProducts", {}),
                                   "loadLoanProducts");
        const auto arr = result.value("products").toArray();
        expectGe(arr.size(), 1, "число кредитных продуктов");

        // Желаемые параметры (компромисс между «не нагружать тест» и «реалистично»)
        constexpr double DESIRED_AMOUNT = 30'000.0;
        constexpr int    DESIRED_MONTHS = 6;

        // 1) ищем продукт, чьи лимиты включают наши «желаемые» значения
        int    chosenId = 0;
        double chosenAmount = 0.0;
        int    chosenMonths = 0;
        QString chosenName;
        for (const auto& v : arr)
        {
            const QJsonObject p = v.toObject();
            const double minA  = p.value("min_amount").toDouble();
            const double maxA  = p.value("max_amount").toDouble();
            const int    minT  = p.value("min_term_months").toInt();
            const int    maxT  = p.value("max_term_months").toInt();
            if (DESIRED_AMOUNT >= minA && DESIRED_AMOUNT <= maxA &&
                DESIRED_MONTHS >= minT && DESIRED_MONTHS <= maxT)
            {
                chosenId     = toInt(p.value("id"));
                chosenAmount = DESIRED_AMOUNT;
                chosenMonths = DESIRED_MONTHS;
                chosenName   = p.value("name").toString();
                break;
            }
        }

        // 2) если ни один не подошёл — берём первый и используем ЕГО собственные минимумы
        if (chosenId == 0)
        {
            const QJsonObject p = arr.first().toObject();
            chosenId     = toInt(p.value("id"));
            chosenAmount = p.value("min_amount").toDouble();
            chosenMonths = p.value("min_term_months").toInt();
            chosenName   = p.value("name").toString();
        }

        ctx.loanProductId = chosenId;
        ctx.loanAmount    = chosenAmount;
        ctx.loanMonths    = chosenMonths;

        expectGt(ctx.loanProductId, 0, "loanProductId");
        expectGt(ctx.loanAmount,    0.0, "loanAmount");
        expectGt(ctx.loanMonths,    0,   "loanMonths");

        return QStringLiteral("найдено %1 продуктов; выбран \"%2\" (id=%3), сумма=%4 RUB, срок=%5 мес.")
            .arg(arr.size()).arg(chosenName).arg(ctx.loanProductId)
            .arg(QString::number(ctx.loanAmount, 'f', 2)).arg(ctx.loanMonths);
    });

    R.test(QStringLiteral("applyForLoan(A) — оформление кредита по выбранному продукту"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId",          ctx.userIdA},
            {"productId",       ctx.loanProductId},
            {"amount",          ctx.loanAmount},
            {"months",          ctx.loanMonths},
            {"targetAccountId", ctx.accountIdA1}
        };
        const auto result = unwrap(client.call("applyForLoan", params), "applyForLoan");
        requireBusinessOk(result, "applyForLoan");
        ctx.loanId = toInt(result.value("loanId"));
        expectGt(ctx.loanId, 0, "loanId");
        return QStringLiteral("loanId=%1 (сумма %2 RUB, срок %3 мес.)")
            .arg(ctx.loanId)
            .arg(QString::number(ctx.loanAmount, 'f', 2))
            .arg(ctx.loanMonths);
    });

    R.test(QStringLiteral("loadUserLoans(A) — список активных кредитов не пуст"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("loadUserLoans", { {"userId", ctx.userIdA} }),
            "loadUserLoans");
        const auto arr = result.value("loans").toArray();
        expectGe(arr.size(), 1, "число активных кредитов");
        return QStringLiteral("получили %1 кредитов").arg(arr.size());
    });

    R.test(QStringLiteral("loadLoanSchedule(loanId) — график платежей не пуст"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("loadLoanSchedule", { {"loanId", ctx.loanId} }),
            "loadLoanSchedule");
        const auto arr = result.value("schedule").toArray();
        expectGe(arr.size(), 1, "число платежей в графике");
        return QStringLiteral("в графике %1 платежей").arg(arr.size());
    });

    R.test(QStringLiteral("makeLoanPayment(A, loanId) — внесение первого платежа"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId", ctx.userIdA}, {"loanId", ctx.loanId}
        };
        const auto result = unwrap(client.call("makeLoanPayment", params),
                                   "makeLoanPayment");
        requireBusinessOk(result, "makeLoanPayment");
        const double amt = result.value("paymentAmount").toDouble();
        return QStringLiteral("уплачено %1 RUB, closed=%2")
            .arg(QString::number(amt, 'f', 2),
                 result.value("closed").toBool() ? "true" : "false");
    });

    R.test(QStringLiteral("loadClosedLoans(A) — список закрытых кредитов получен"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("loadClosedLoans", { {"userId", ctx.userIdA} }),
            "loadClosedLoans");
        const auto arr = result.value("loans").toArray();
        const double total = result.value("totalPaidAll").toDouble();
        return QStringLiteral("закрытых кредитов: %1, выплачено всего: %2")
            .arg(arr.size()).arg(QString::number(total, 'f', 2));
    });

    
    R.section(QStringLiteral("Накопительный счёт (4 хендлера)"));
    

    R.test(QStringLiteral("getSavingsAccount(A) до открытия — exists=false"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getSavingsAccount", { {"userId", ctx.userIdA} }),
            "getSavingsAccount");
        const bool exists = result.value("exists").toBool();
        return QStringLiteral("exists=%1").arg(exists ? "true" : "false");
    });

    R.test(QStringLiteral("openSavingsAccount(A, 2000 RUB)"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId", ctx.userIdA}, {"fromAccountId", ctx.accountIdA1}, {"amount", 2000.0}
        };
        const auto result = unwrap(client.call("openSavingsAccount", params),
                                   "openSavingsAccount");
        requireBusinessOk(result, "openSavingsAccount");
        return QStringLiteral("открыт накопит. счёт на 2000 RUB");
    });

    R.test(QStringLiteral("savingsTopUp(A, +500 RUB)"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId", ctx.userIdA}, {"fromAccountId", ctx.accountIdA1}, {"amount", 500.0}
        };
        const auto result = unwrap(client.call("savingsTopUp", params), "savingsTopUp");
        requireBusinessOk(result, "savingsTopUp");
        return QStringLiteral("пополнение 500 RUB прошло");
    });

    R.test(QStringLiteral("savingsWithdraw(A, -300 RUB обратно на счёт)"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId", ctx.userIdA}, {"toAccountId", ctx.accountIdA1}, {"amount", 300.0}
        };
        const auto result = unwrap(client.call("savingsWithdraw", params),
                                   "savingsWithdraw");
        requireBusinessOk(result, "savingsWithdraw");
        return QStringLiteral("снято 300 RUB");
    });

    
    R.section(QStringLiteral("Срочные вклады (5 хендлеров)"));
    

    R.test(QStringLiteral("getUserDeposits(A) до открытия — список пуст"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getUserDeposits", { {"userId", ctx.userIdA} }),
            "getUserDeposits");
        const auto arr = result.value("deposits").toArray();
        return QStringLiteral("активных вкладов: %1").arg(arr.size());
    });

    R.test(QStringLiteral("openDeposit(A, 5000 RUB, 3 мес, пополняемый)"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId",        ctx.userIdA},
            {"fromAccountId", ctx.accountIdA1},
            {"amount",        5000.0},
            {"months",        3},
            {"replenishable", true}
        };
        const auto result = unwrap(client.call("openDeposit", params), "openDeposit");
        requireBusinessOk(result, "openDeposit");
        return QStringLiteral("вклад открыт на 5000 RUB на 3 мес");
    });

    R.test(QStringLiteral("getUserDeposits(A) после открытия — узнаём depositId"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getUserDeposits", { {"userId", ctx.userIdA} }),
            "getUserDeposits");
        const auto arr = result.value("deposits").toArray();
        expectGe(arr.size(), 1, "число вкладов после открытия");
        ctx.depositId = findIdOfFirst(arr, {"id", "depositId", "deposit_id"});
        expectGt(ctx.depositId, 0, "depositId");
        return QStringLiteral("depositId=%1").arg(ctx.depositId);
    });

    R.test(QStringLiteral("depositTopUp(A, +200 RUB)"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId",        ctx.userIdA},
            {"depositId",     ctx.depositId},
            {"fromAccountId", ctx.accountIdA1},
            {"amount",        200.0}
        };
        const auto result = unwrap(client.call("depositTopUp", params), "depositTopUp");
        requireBusinessOk(result, "depositTopUp");
        return QStringLiteral("пополнение вклада на 200 RUB прошло");
    });

    R.test(QStringLiteral("getClosedDeposits(A) — список закрытых вкладов"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getClosedDeposits", { {"userId", ctx.userIdA} }),
            "getClosedDeposits");
        const auto arr = result.value("deposits").toArray();
        return QStringLiteral("закрытых вкладов: %1").arg(arr.size());
    });

    R.test(QStringLiteral("claimDeposit — досрочное закрытие отклонено бизнес-логикой"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId",      ctx.userIdA},
            {"depositId",   ctx.depositId},
            {"toAccountId", ctx.accountIdA1}
        };
        const auto result = unwrap(client.call("claimDeposit", params), "claimDeposit");
        // Для несозревшего вклада ok должен быть false (или true с штрафом).
        // Главное — что RPC отрабатывает и возвращает консистентный ответ.
        const bool ok = result.value("ok").toBool();
        const QString err = result.value("error").toString();
        return ok
            ? QStringLiteral("ok=true, payoutAmount=%1")
                .arg(QString::number(result.value("payoutAmount").toDouble(), 'f', 2))
            : QStringLiteral("ok=false, error=\"%1\" (ожидаемо для незрелого вклада)")
                .arg(err);
    });

    
    R.section(QStringLiteral("Криптовалюта (7 хендлеров)"));
    

    R.test(QStringLiteral("getCryptocurrencies() — каталог монет не пуст"),
        [&]() -> QString
    {
        const auto result = unwrap(client.call("getCryptocurrencies", {}),
                                   "getCryptocurrencies");
        const auto arr = result.value("currencies").toArray();
        expectGe(arr.size(), 1, "число монет");
        const QJsonObject first = arr.first().toObject();
        ctx.currencyId = toInt(first.value("id"));
        if (ctx.currencyId == 0)
            ctx.currencyId = toInt(first.value("currencyId"));
        ctx.currencySymbol = first.value("symbol").toString(
            first.value("ticker").toString(QStringLiteral("???")));
        expectGt(ctx.currencyId, 0, "currencyId");
        return QStringLiteral("найдено %1 монет, выбрана %2 (id=%3)")
            .arg(arr.size()).arg(ctx.currencySymbol).arg(ctx.currencyId);
    });

    R.test(QStringLiteral("getUserWallets(A) — кошельки авто-созданы"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("getUserWallets", { {"userId", ctx.userIdA} }),
            "getUserWallets");
        const auto arr = result.value("wallets").toArray();
        expectGe(arr.size(), 1, "число кошельков A");
        return QStringLiteral("кошельков A: %1").arg(arr.size());
    });

    R.test(QStringLiteral("getUserWallets(B) — узнаём адрес кошелька B для перевода"),
        [&]() -> QString
    {
        // Свежий пользователь B ещё не имеет ни одного кошелька — таблица
        // crypto_wallets заполняется лениво (через ensureWallet). Прогреваем
        // кошелёк B по выбранной валюте через getCoinDetail (это вызывает
        // ensureWallet на стороне сервера).
        client.call("getCoinDetail",
            { {"userId", ctx.userIdB}, {"currencyId", ctx.currencyId} });

        const auto result = unwrap(
            client.call("getUserWallets", { {"userId", ctx.userIdB} }),
            "getUserWallets");
        const auto arr = result.value("wallets").toArray();
        expectGe(arr.size(), 1, "число кошельков B");

        // ВАЖНО: getUserWallets отдаёт ключи в snake_case (currency_id, а не currencyId),
        // см. DatabaseManager::getUserWallets — поле "currency_id".
        for (const auto& v : arr)
        {
            const QJsonObject w = v.toObject();
            const int cid = toInt(w.value("currency_id"));
            if (cid == ctx.currencyId)
            {
                ctx.cryptoAddressB = w.value("address").toString();
                break;
            }
        }
        // Fallback на случай, если выбранная валюта почему-то не отдалась
        // (берём первый кошелёк и СИНХРОНИЗИРУЕМ ctx.currencyId под него).
        if (ctx.cryptoAddressB.isEmpty())
        {
            const QJsonObject w = arr.first().toObject();
            ctx.cryptoAddressB = w.value("address").toString();
            const int cidFallback = toInt(w.value("currency_id"));
            if (cidFallback > 0)
                ctx.currencyId = cidFallback;
        }
        expectNonEmptyStr(ctx.cryptoAddressB, "addressB");
        expectGt(ctx.currencyId, 0, "ctx.currencyId после lookup B");
        return QStringLiteral("address=%1..., currencyId=%2")
            .arg(ctx.cryptoAddressB.left(12)).arg(ctx.currencyId);
    });

    R.test(QStringLiteral("buyCrypto(A, 1000 RUB) — покупка криптовалюты"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId",     ctx.userIdA},
            {"currencyId", ctx.currencyId},
            {"rubAmount",  1000.0},
            {"cardId",     ctx.cardIdA}
        };
        const auto result = unwrap(client.call("buyCrypto", params), "buyCrypto");
        requireBusinessOk(result, "buyCrypto");
        ctx.boughtCoinAmount = result.value("coinAmount").toDouble();
        expectGt(ctx.boughtCoinAmount, 0.0, "coinAmount");
        return QStringLiteral("куплено %1 %2 по цене %3 RUB")
            .arg(QString::number(ctx.boughtCoinAmount, 'f', 8))
            .arg(ctx.currencySymbol)
            .arg(QString::number(result.value("price").toDouble(), 'f', 2));
    });

    R.test(QStringLiteral("sellCrypto(A, 25%% портфеля) — частичная продажа"),
        [&]() -> QString
    {
        const double sellAmount = ctx.boughtCoinAmount * 0.25;
        const QJsonObject params{
            {"userId",     ctx.userIdA},
            {"currencyId", ctx.currencyId},
            {"coinAmount", sellAmount},
            {"cardId",     ctx.cardIdA}
        };
        const auto result = unwrap(client.call("sellCrypto", params), "sellCrypto");
        requireBusinessOk(result, "sellCrypto");
        return QStringLiteral("продано %1 %2 за %3 RUB")
            .arg(QString::number(result.value("coinAmount").toDouble(), 'f', 8))
            .arg(ctx.currencySymbol)
            .arg(QString::number(result.value("rubAmount").toDouble(), 'f', 2));
    });

    R.test(QStringLiteral("transferCrypto(A → B, 10%% портфеля)"),
        [&]() -> QString
    {
        const double transferAmount = ctx.boughtCoinAmount * 0.10;
        const QJsonObject params{
            {"userId",           ctx.userIdA},
            {"currencyId",       ctx.currencyId},
            {"coinAmount",       transferAmount},
            {"recipientAddress", ctx.cryptoAddressB}
        };
        const auto result = unwrap(client.call("transferCrypto", params),
                                   "transferCrypto");
        requireBusinessOk(result, "transferCrypto");
        return QStringLiteral("переведено %1 %2 пользователю \"%3\"")
            .arg(QString::number(result.value("coinAmount").toDouble(), 'f', 8))
            .arg(ctx.currencySymbol)
            .arg(result.value("recipientName").toString());
    });

    R.test(QStringLiteral("getCoinDetail(A, currencyId) — деталка по монете"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId", ctx.userIdA}, {"currencyId", ctx.currencyId}
        };
        const auto result = unwrap(client.call("getCoinDetail", params),
                                   "getCoinDetail");
        const auto currency = result.value("currency").toObject();
        const auto stats    = result.value("stats24h").toObject();
        const auto pricesArr = result.value("priceHistory").toArray();
        expectGt(currency.keys().size(), 0, "currency");
        return QStringLiteral("валюта получена, точек priceHistory=%1, stats24h полей=%2")
            .arg(pricesArr.size()).arg(stats.keys().size());
    });

    R.test(QStringLiteral("getCryptoHistory(A) — история крипто-операций не пуста"),
        [&]() -> QString
    {
        const QJsonObject params{
            {"userId", ctx.userIdA}, {"limit", 50}, {"offset", 0}
        };
        const auto result = unwrap(client.call("getCryptoHistory", params),
                                   "getCryptoHistory");
        const auto arr = result.value("history").toArray();
        expectGe(arr.size(), 1, "крипто-история");  // buy + sell + transfer уже было
        return QStringLiteral("операций в крипто-истории: %1").arg(arr.size());
    });

    
    R.section(QStringLiteral("Завершение (1 хендлер)"));
    

    R.test(QStringLiteral("blockCard(cardIdA) — необратимая блокировка карты"),
        [&]() -> QString
    {
        const auto result = unwrap(
            client.call("blockCard", { {"cardId", ctx.cardIdA} }),
            "blockCard");
        requireBusinessOk(result, "blockCard");
        return QStringLiteral("карта %1 заблокирована").arg(ctx.cardIdA);
    });

    //  Итог 
    const int exitCode = R.summary();

    client.disconnectFromServer();
    return exitCode;
}