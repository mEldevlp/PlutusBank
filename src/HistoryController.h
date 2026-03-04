#pragma once

#include <QObject>
#include <QVariantList>
#include "DatabaseManager.h"

class HistoryController : public QObject
{
    Q_OBJECT

        Q_PROPERTY(QVariantList transactions READ transactions NOTIFY transactionsChanged)
        Q_PROPERTY(bool isLoading READ isLoading NOTIFY loadingChanged)
        Q_PROPERTY(bool hasMore READ hasMore NOTIFY transactionsChanged)

public:
    explicit HistoryController(QObject* parent = nullptr);

    QVariantList transactions() const { return m_transactions; }
    bool isLoading() const { return m_isLoading; }
    bool hasMore() const { return m_hasMore; }

    Q_INVOKABLE void loadTransactions();      // Первая загрузка (сброс)
    Q_INVOKABLE void loadMore();              // Подгрузка следующей порции

signals:
    void transactionsChanged();
    void loadingChanged();

private:
    static constexpr int PAGE_SIZE = 30;

    DatabaseManager& m_db;
    QVariantList m_transactions;
    bool m_isLoading = false;
    bool m_hasMore = true;
    int m_offset = 0;
};