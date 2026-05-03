#include "CryptoController.h"
#include "UserSession.h"

#include <QDebug>
#include <cmath>

CryptoController::CryptoController(QObject* parent)
    : QObject(parent)
    , m_net(NetworkClient::instance())
{
    // Каждые 4 секунды тихо подтягиваем котировки.
    // Включается/выключается через autoRefreshEnabled из QML
    // (стартует, когда пользователь зашёл на крипто-вкладку — экономим запросы).
    m_autoRefresh.setInterval(4000);
    m_autoRefresh.setTimerType(Qt::CoarseTimer);
    connect(&m_autoRefresh, &QTimer::timeout, this, &CryptoController::onAutoRefreshTick);
}

void CryptoController::setAutoRefreshEnabled(bool on)
{
    if (on == m_autoRefresh.isActive()) return;
    if (on) m_autoRefresh.start();
    else    m_autoRefresh.stop();
    emit autoRefreshChanged();
}

void CryptoController::onAutoRefreshTick()
{
    // Лёгкий тик: только цены (короткий запрос). Кошельки/история обновляются по требованию.
    m_currencies = m_net.getCryptocurrencies();
    emit currenciesChanged();

    // Если кошельки уже были загружены — пересчитаем рублёвую стоимость
    // локально по новым ценам (быстрее, чем тащить с сервера).
    if (!m_wallets.isEmpty())
    {
        for (int i = 0; i < m_wallets.size(); ++i)
        {
            QVariantMap w = m_wallets[i].toMap();
            int cid = w["currency_id"].toInt();
            for (const auto& cv : std::as_const(m_currencies))
            {
                auto cm = cv.toMap();
                if (cm["id"].toInt() == cid)
                {
                    double price = cm["current_price"].toDouble();
                    w["current_price"] = price;
                    w["rub_value"] = std::round(w["balance"].toDouble() * price * 100.0) / 100.0;
                    break;
                }
            }
            m_wallets[i] = w;
        }
        recalcTotal();
        emit walletsChanged();
    }
}

void CryptoController::loadCurrencies()
{
    m_currencies = m_net.getCryptocurrencies();
    emit currenciesChanged();
}

void CryptoController::loadWallets()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;
    m_wallets = m_net.getUserWallets(userId);
    recalcTotal();
    emit walletsChanged();
}

void CryptoController::loadHistory()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;
    m_history = m_net.getCryptoHistory(userId, 100, 0);
    emit historyChanged();
}

void CryptoController::refreshAll()
{
    m_isLoading = true; emit loadingChanged();
    loadCurrencies();
    loadWallets();
    loadHistory();
    m_isLoading = false; emit loadingChanged();
}

void CryptoController::recalcTotal()
{
    double total = 0.0;
    for (const auto& v : std::as_const(m_wallets))
        total += v.toMap()["rub_value"].toDouble();
    m_totalRubValue = std::round(total * 100.0) / 100.0;
}

QVariantMap CryptoController::previewBuy(double currentPrice, double rubAmount)
{
    QVariantMap out;
    if (currentPrice <= 0 || rubAmount <= 0)
    {
        out["coinAmount"] = 0.0;
        out["pricePerCoin"] = currentPrice;
        out["valid"] = false;
        return out;
    }
    double coins = std::round((rubAmount / currentPrice) * 1e8) / 1e8;
    out["coinAmount"] = coins;
    out["pricePerCoin"] = currentPrice;
    out["valid"] = (coins > 0);
    return out;
}

QVariantMap CryptoController::previewSell(double currentPrice, double coinAmount)
{
    QVariantMap out;
    if (currentPrice <= 0 || coinAmount <= 0)
    {
        out["rubAmount"] = 0.0;
        out["pricePerCoin"] = currentPrice;
        out["valid"] = false;
        return out;
    }
    double rub = std::round((coinAmount * currentPrice) * 100.0) / 100.0;
    out["rubAmount"] = rub;
    out["pricePerCoin"] = currentPrice;
    out["valid"] = (rub > 0);
    return out;
}

void CryptoController::buy(int currencyId, double rubAmount, int cardId)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit buyFailed("Пользователь не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();
    auto r = m_net.buyCrypto(userId, currencyId, rubAmount, cardId);
    m_isLoading = false; emit loadingChanged();

    if (!r.ok)
    {
        emit buyFailed(r.error.isEmpty() ? "Не удалось выполнить покупку" : r.error);
        return;
    }

    // Обновляем всё после успеха: и крипто-данные, и банковский баланс
    loadWallets();
    loadHistory();
    UserSession::instance().refreshAll();

    emit buySuccess(QString("Куплено %1 монет за %2 ₽")
                    .arg(r.coinAmount, 0, 'f', 8)
                    .arg(r.rubAmount, 0, 'f', 2));
}

void CryptoController::sell(int currencyId, double coinAmount, int cardId)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit sellFailed("Пользователь не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();
    auto r = m_net.sellCrypto(userId, currencyId, coinAmount, cardId);
    m_isLoading = false; emit loadingChanged();

    if (!r.ok)
    {
        emit sellFailed(r.error.isEmpty() ? "Не удалось выполнить продажу" : r.error);
        return;
    }

    loadWallets();
    loadHistory();
    UserSession::instance().refreshAll();

    emit sellSuccess(QString("Продано %1 монет за %2 ₽")
                     .arg(r.coinAmount, 0, 'f', 8)
                     .arg(r.rubAmount, 0, 'f', 2));
}

void CryptoController::transfer(int currencyId, double coinAmount, const QString& recipientAddress)
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) { emit transferFailed("Пользователь не авторизован"); return; }

    m_isLoading = true; emit loadingChanged();
    auto r = m_net.transferCrypto(userId, currencyId, coinAmount, recipientAddress);
    m_isLoading = false; emit loadingChanged();

    if (!r.ok)
    {
        emit transferFailed(r.error.isEmpty() ? "Не удалось выполнить перевод" : r.error);
        return;
    }

    loadWallets();
    loadHistory();

    emit transferSuccess(QString("%1 монет отправлены: %2")
                         .arg(r.coinAmount, 0, 'f', 8)
                         .arg(r.recipientName));
}
