#include "CryptoEngine.h"
#include "DatabaseManager.h"
#include "Logger.h"

#include <QSqlQuery>
#include <QSqlError>
#include <QDateTime>
#include <cmath>

CryptoEngine::CryptoEngine(QObject* parent)
    : QObject(parent)
    , m_rng(QRandomGenerator::securelySeeded())
{
    m_timer.setInterval(TICK_INTERVAL_MS);
    m_timer.setTimerType(Qt::CoarseTimer);
    connect(&m_timer, &QTimer::timeout, this, &CryptoEngine::onTick);
}

void CryptoEngine::start()
{
    Logger::instance().info(
        QString("CryptoEngine: запуск симуляции (интервал %1 мс)").arg(TICK_INTERVAL_MS));

    // При старте проверяем, не было ли длительного простоя сервера.
    // Если был — стираем старую историю цен, чтобы график не показывал
    // уродливую вертикальную полосу от последней точки до новой цены.
    if (DatabaseManager::instance().isConnected())
    {
        purgeHistoryIfGap();
        writePriceSnapshot();
    }

    m_timer.start();
}

void CryptoEngine::stop()
{
    m_timer.stop();
    Logger::instance().info("CryptoEngine: симуляция остановлена");
}

double CryptoEngine::sampleNormal()
{
    // Box-Muller: два равномерных → одно стандартное нормальное.
    double u1 = m_rng.generateDouble();
    double u2 = m_rng.generateDouble();
    if (u1 < 1e-12) u1 = 1e-12;
    return std::sqrt(-2.0 * std::log(u1)) * std::cos(2.0 * M_PI * u2);
}

void CryptoEngine::onTick()
{
    auto& dbMgr = DatabaseManager::instance();
    if (!dbMgr.isConnected())
        return;

    QSqlDatabase db = dbMgr.database();

    // 1. Тянем все активные монеты с параметрами
    QSqlQuery sel(db);
    sel.prepare(
        "SELECT id, symbol, base_price, current_price, volatility, "
        "jump_intensity, jump_sigma, drift, mean_reversion "
        "FROM cryptocurrencies WHERE is_active = TRUE"
    );

    if (!sel.exec())
    {
        Logger::instance().warning("CryptoEngine: не удалось загрузить каталог: " + sel.lastError().text());
        return;
    }

    db.transaction();

    QSqlQuery upd(db);
    upd.prepare("UPDATE cryptocurrencies SET current_price = :p, "
        "last_updated = CURRENT_TIMESTAMP WHERE id = :id");

    int updatedCount = 0;
    while (sel.next())
    {
        int     id = sel.value(0).toInt();
        QString symbol = sel.value(1).toString();
        double  basePrice = sel.value(2).toDouble();
        double  price = sel.value(3).toDouble();
        double  sigma = sel.value(4).toDouble();
        double  lambda = sel.value(5).toDouble();
        double  sigmaJump = sel.value(6).toDouble();
        double  drift = sel.value(7).toDouble();
        double  meanRev = sel.value(8).toDouble();

        //  1. Диффузионная компонента
        double diffusion = sigma * sampleNormal();

        //  2. Пуассоновский скачок (Bernoulli-приближение на тике) 
        double jump = 0.0;
        if (m_rng.generateDouble() < lambda)
            jump = sigmaJump * sampleNormal();

        //  3. Mean-reversion: −k · ln(P/P_base) 
        double reversion = -meanRev * std::log(price / basePrice);

        //  Итоговая относительная доходность 
        double r = drift + diffusion + jump + reversion;

        // Ограничим экстремум одного тика, чтобы случайный гигантский
        // скачок не привёл к выходу за пол/потолок за один шаг.
        if (r > 0.40) r = 0.40;
        if (r < -0.30) r = -0.30;

        double newPrice = price * (1.0 + r);

        // Жёсткие границы — мягкая страховка от вырождения симуляции
        const double floorPrice = basePrice * 0.01;
        const double ceilPrice = basePrice * 50.0;
        if (newPrice < floorPrice) newPrice = floorPrice;
        if (newPrice > ceilPrice)  newPrice = ceilPrice;

        // Округлим до 8 знаков (NUMERIC(20,8) в БД)
        newPrice = std::round(newPrice * 1e8) / 1e8;

        upd.bindValue(":p", newPrice);
        upd.bindValue(":id", id);
        if (!upd.exec())
        {
            Logger::instance().warning(
                QString("CryptoEngine: не обновлена цена %1: %2").arg(symbol, upd.lastError().text()));
        }
        else
        {
            ++updatedCount;
        }
    }

    if (!db.commit())
    {
        db.rollback();
        Logger::instance().warning("CryptoEngine: rollback тика");
        return;
    }

    ++m_tickCount;

    //  Срез цен в историю (раз в SNAPSHOT_EVERY_TICKS тиков) 
    if (m_tickCount % SNAPSHOT_EVERY_TICKS == 0)
        writePriceSnapshot();

    //  Очистка старой истории (раз в час) 
    if (m_tickCount % CLEANUP_EVERY_TICKS == 0)
        cleanupOldPriceHistory();

    static qint64 lastLog = 0;
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - lastLog > 30000)
    {
        Logger::instance().debug(QString("CryptoEngine: тик, обновлено %1 монет").arg(updatedCount));
        lastLog = now;
    }
}

void CryptoEngine::writePriceSnapshot()
{
    auto& dbMgr = DatabaseManager::instance();
    if (!dbMgr.isConnected()) return;

    QSqlDatabase db = dbMgr.database();

    QSqlQuery q(db);
    q.prepare(
        "INSERT INTO crypto_price_history (currency_id, price) "
        "  SELECT id, current_price FROM cryptocurrencies WHERE is_active = TRUE"
    );
    if (!q.exec())
    {
        Logger::instance().warning(
            "CryptoEngine: не записан срез цен: " + q.lastError().text());
    }
}

void CryptoEngine::cleanupOldPriceHistory()
{
    auto& dbMgr = DatabaseManager::instance();
    if (!dbMgr.isConnected()) return;

    QSqlDatabase db = dbMgr.database();
    QSqlQuery q(db);
    q.prepare(
        "DELETE FROM crypto_price_history "
        " WHERE recorded_at < NOW() - INTERVAL '7 days'"
    );
    if (!q.exec())
    {
        Logger::instance().warning(
            "CryptoEngine: не очищена старая история цен: " + q.lastError().text());
    }
    else if (q.numRowsAffected() > 0)
    {
        Logger::instance().info(
            QString("CryptoEngine: удалено %1 устаревших записей истории цен")
            .arg(q.numRowsAffected()));
    }
}

void CryptoEngine::purgeHistoryIfGap()
{
    auto& dbMgr = DatabaseManager::instance();
    if (!dbMgr.isConnected()) return;

    QSqlDatabase db = dbMgr.database();

    // Узнаём, когда был последний снимок цен.
    QSqlQuery q(db);
    q.prepare(
        "SELECT EXTRACT(EPOCH FROM (NOW() - MAX(recorded_at)))::int "
        "  FROM crypto_price_history"
    );

    if (!q.exec() || !q.next())
        return;

    // Если таблица пуста, MAX вернёт NULL → isNull() == true — разрыва нет,
    // просто первый запуск (история начнётся с нуля).
    if (q.value(0).isNull())
        return;

    int gapSeconds = q.value(0).toInt();

    if (gapSeconds > GAP_THRESHOLD_SEC)
    {
        Logger::instance().info(
            QString("CryptoEngine: обнаружен простой %1 сек (порог %2 сек) — "
                "очищаю историю цен, чтобы график стартовал с чистого листа")
            .arg(gapSeconds)
            .arg(GAP_THRESHOLD_SEC));

        QSqlQuery del(db);
        del.prepare("DELETE FROM crypto_price_history");
        if (!del.exec())
        {
            Logger::instance().warning(
                "CryptoEngine: не удалось очистить историю цен: " + del.lastError().text());
        }
        else
        {
            Logger::instance().info(
                QString("CryptoEngine: удалено %1 записей истории цен после простоя")
                .arg(del.numRowsAffected()));
        }
    }
    else
    {
        Logger::instance().debug(
            QString("CryptoEngine: разрыв %1 сек — в пределах нормы, история сохранена")
            .arg(gapSeconds));
    }
}