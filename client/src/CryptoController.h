#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include "NetworkClient.h"

/*
    CryptoController — фронт-контроллер криптомодуля.

    - currencies   — каталог 4 криптовалют (актуальные цены).
    - wallets      — кошельки текущего пользователя (количество монет
                     + рублёвый эквивалент по текущей цене).
    - history      — история крипто-операций.
    - totalRubValue — сумма всех кошельков в рублях.

    refreshPrices() запускается из QML по таймеру (каждые ~3-5 сек),
    чтобы пользователь видел "живые" котировки.
*/
class CryptoController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList currencies   READ currencies   NOTIFY currenciesChanged)
    Q_PROPERTY(QVariantList wallets      READ wallets      NOTIFY walletsChanged)
    Q_PROPERTY(QVariantList history      READ history      NOTIFY historyChanged)
    Q_PROPERTY(double totalRubValue      READ totalRubValue NOTIFY walletsChanged)
    Q_PROPERTY(bool isLoading            READ isLoading    NOTIFY loadingChanged)
    Q_PROPERTY(bool autoRefreshEnabled   READ autoRefreshEnabled
                                         WRITE setAutoRefreshEnabled
                                         NOTIFY autoRefreshChanged)

public:
    explicit CryptoController(QObject* parent = nullptr);

    QVariantList currencies()  const { return m_currencies; }
    QVariantList wallets()     const { return m_wallets; }
    QVariantList history()     const { return m_history; }
    double totalRubValue()     const { return m_totalRubValue; }
    bool isLoading()           const { return m_isLoading; }
    bool autoRefreshEnabled()  const { return m_autoRefresh.isActive(); }

    void setAutoRefreshEnabled(bool on);

    Q_INVOKABLE void loadCurrencies();          // только котировки (быстро)
    Q_INVOKABLE void loadWallets();             // кошельки + цены
    Q_INVOKABLE void loadHistory();             // история операций
    Q_INVOKABLE void refreshAll();              // всё сразу

    Q_INVOKABLE void buy   (int currencyId, double rubAmount, int cardId);
    Q_INVOKABLE void sell  (int currencyId, double coinAmount, int cardId);
    Q_INVOKABLE void transfer(int currencyId, double coinAmount, const QString& recipientAddress);

    // Мгновенный пересчёт цены сделки на клиенте без обращения к серверу
    Q_INVOKABLE QVariantMap previewBuy(double currentPrice, double rubAmount);
    Q_INVOKABLE QVariantMap previewSell(double currentPrice, double coinAmount);

signals:
    void currenciesChanged();
    void walletsChanged();
    void historyChanged();
    void loadingChanged();
    void autoRefreshChanged();

    void buySuccess(const QString& message);
    void buyFailed(const QString& error);
    void sellSuccess(const QString& message);
    void sellFailed(const QString& error);
    void transferSuccess(const QString& message);
    void transferFailed(const QString& error);

private slots:
    void onAutoRefreshTick();

private:
    void recalcTotal();

    NetworkClient& m_net;
    QVariantList   m_currencies;
    QVariantList   m_wallets;
    QVariantList   m_history;
    double         m_totalRubValue = 0.0;
    bool           m_isLoading     = false;

    QTimer m_autoRefresh;
};
