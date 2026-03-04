#include "HistoryController.h"
#include "UserSession.h"
#include <QDebug>

HistoryController::HistoryController(QObject* parent)
    : QObject(parent)
    , m_db(DatabaseManager::instance())
{
}

void HistoryController::loadTransactions()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;

    m_isLoading = true;
    emit loadingChanged();

    m_offset = 0;
    m_transactions.clear();

    auto batch = m_db.getTransactionHistory(userId, PAGE_SIZE, m_offset);
    m_transactions = batch;
    m_hasMore = (batch.size() == PAGE_SIZE);
    m_offset = m_transactions.size();

    m_isLoading = false;
    emit loadingChanged();
    emit transactionsChanged();
}

void HistoryController::loadMore()
{
    if (m_isLoading || !m_hasMore) return;

    int userId = UserSession::instance().userId();
    if (userId <= 0) return;

    m_isLoading = true;
    emit loadingChanged();

    auto batch = m_db.getTransactionHistory(userId, PAGE_SIZE, m_offset);
    m_transactions.append(batch);
    m_hasMore = (batch.size() == PAGE_SIZE);
    m_offset = m_transactions.size();

    m_isLoading = false;
    emit loadingChanged();
    emit transactionsChanged();
}