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

private slots:
    void onTick();

private:
    QTimer m_timer;
    QRandomGenerator m_rng;

    // Box-Muller — стандартное нормальное распределение
    double sampleNormal();
};
