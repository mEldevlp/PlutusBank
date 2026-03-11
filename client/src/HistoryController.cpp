#include "HistoryController.h"
#include "UserSession.h"
#include <QDebug>

HistoryController::HistoryController(QObject* parent)
    : QAbstractListModel(parent)
    , 
    m_net(NetworkClient::instance())
{}

int HistoryController::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant HistoryController::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};

    const auto& item = m_items[index.row()];

    switch (role) 
    {
    case IdRole:              return item["id"];
    case AmountRole:          return item["amount"];
    case TransactionTypeRole: return item["transaction_type"];
    case DescriptionRole:     return item["description"];
    case StatusRole:          return item["status"];
    case CreatedAtRole:       return item["created_at"];
    case DateGroupRole:       return item["date_group"];
    case DirectionRole:       return item["direction"];
    case FromNameRole:        return item["from_name"];
    case ToNameRole:          return item["to_name"];
    case FromCardLast4Role:   return item["from_card_last4"];
    case ToCardLast4Role:     return item["to_card_last4"];
    default:                  return {};
    }
}

QHash<int, QByteArray> HistoryController::roleNames() const
{
    return {
        { IdRole,              "tx_id" },
        { AmountRole,          "amount" },
        { TransactionTypeRole, "transaction_type" },
        { DescriptionRole,     "description" },
        { StatusRole,          "status" },
        { CreatedAtRole,       "created_at" },
        { DateGroupRole,       "date_group" },
        { DirectionRole,       "direction" },
        { FromNameRole,        "from_name" },
        { ToNameRole,          "to_name" },
        { FromCardLast4Role,   "from_card_last4" },
        { ToCardLast4Role,     "to_card_last4" }
    };
}

void HistoryController::loadTransactions()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;

    m_isLoading = true;
    emit loadingChanged();

    beginResetModel();
    m_items.clear();
    m_offset = 0;
    endResetModel();

    auto batch = m_net.getTransactionHistory(userId, kPAGE_SIZE, m_offset);

    if (!batch.isEmpty()) 
    {
        beginInsertRows({}, 0, batch.size() - 1);
        for (const auto& v : batch)
            m_items.append(v.toMap());
        endInsertRows();
    }

    m_hasMore = (batch.size() == kPAGE_SIZE);
    m_offset = m_items.size();

    m_isLoading = false;
    emit loadingChanged();
    emit hasMoreChanged();
}

void HistoryController::loadMore()
{
    if (m_isLoading || !m_hasMore) return;

    int userId = UserSession::instance().userId();
    if (userId <= 0) return;

    m_isLoading = true;
    emit loadingChanged();

    auto batch = m_net.getTransactionHistory(userId, kPAGE_SIZE, m_offset);

    if (!batch.isEmpty()) 
    {
        int first = m_items.size();
        int last = first + batch.size() - 1;

        beginInsertRows({}, first, last);
        for (const auto& v : batch)
            m_items.append(v.toMap());
        endInsertRows();
    }

    m_hasMore = (batch.size() == kPAGE_SIZE);
    m_offset = m_items.size();

    m_isLoading = false;
    emit loadingChanged();
    emit hasMoreChanged();
}