#pragma once

#include <QObject>
#include <QTimer>
#include <QRandomGenerator>

/*
    CryptoEngine — фоновый "симулятор биржи".

    Каждые TICK_INTERVAL_MS миллисекунд читает каталог монет из БД,
    применяет к каждой ценовую модель:

        ΔP/P  =  drift  +  σ · N(0,1)        ← диффузионный шум
                 +  JumpFlag · N(0, σ_jump)  ← пуассоновский скачок
                 −  k · ln(P / P_base)       ← mean-reversion к "якорной" цене

    где JumpFlag = Bernoulli(λ · dt) — приближение Пуассоновского процесса
    на малом интервале dt (одно "событие на тик" с вероятностью λ).

    Параметры (volatility, jump_intensity, jump_sigma, drift, mean_reversion)
    хранятся в таблице cryptocurrencies — каждая монета настраивается отдельно.

    Цена не может уйти ниже 1% от base_price (жёсткий пол) и выше 50× — иначе
    случайный гигантский скачок мог бы сломать симуляцию навсегда.

    Каждые SNAPSHOT_EVERY_TICKS тиков движок пишет цену каждой монеты в
    crypto_price_history — это даёт точки для графика на CryptoCoinDetailPage.
    Раз в CLEANUP_EVERY_TICKS — чистит записи старше 7 суток.
*/

class CryptoEngine : public QObject
{
    Q_OBJECT

public:
    explicit CryptoEngine(QObject* parent = nullptr);

    void start();
    void stop();

    // Шаг симуляции в миллисекундах. По умолчанию 3 секунды — комфортно
    // и для глаз пользователя, и для нагрузки на БД.
    static constexpr int TICK_INTERVAL_MS = 3000;

    // Раз в столько тиков снимаем срез цен в crypto_price_history.
    // 10 тиков × 3 сек = 30 сек между точками → 2880 точек/сутки на монету.
    static constexpr int SNAPSHOT_EVERY_TICKS = 10;

    // Раз в столько тиков чистим записи старше 7 суток (примерно раз в час).
    static constexpr int CLEANUP_EVERY_TICKS = 1200;

    // Если между последним снимком в БД и текущим моментом прошло больше
    // GAP_THRESHOLD_SEC секунд, значит сервер был в отключке — старая
    // история цен стирается, чтобы на графике не появлялась уродливая
    // вертикальная полоса от последней «доаварийной» точки к новой цене.
    // 5 минут — комфортный порог: нормальный интервал снимков ~30 сек,
    // а любая содержательная перезагрузка длится дольше 5 минут.
    static constexpr int GAP_THRESHOLD_SEC = 18000;

private slots:
    void onTick();

private:
    QTimer m_timer;
    QRandomGenerator m_rng;
    quint64 m_tickCount = 0;

    // Box-Muller — стандартное нормальное распределение
    double sampleNormal();

    // Записать срез текущих цен в crypto_price_history
    void writePriceSnapshot();

    // Удалить старые записи из crypto_price_history (>7 суток)
    void cleanupOldPriceHistory();

    // Проверяет разрыв между последним снимком и текущим временем;
    // если он больше GAP_THRESHOLD_SEC — стирает историю цен,
    // чтобы график стартовал с чистого листа.
    void purgeHistoryIfGap();
};