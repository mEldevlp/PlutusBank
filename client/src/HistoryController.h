#pragma once

#include <QAbstractListModel>
#include <QVariantList>
#include <QVariantMap>
#include "NetworkClient.h"

class HistoryController : public QAbstractListModel
{
    Q_OBJECT

        Q_PROPERTY(bool isLoading READ isLoading NOTIFY loadingChanged)
        Q_PROPERTY(bool hasMore   READ hasMore   NOTIFY hasMoreChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        AmountRole,
        TransactionTypeRole,
        DescriptionRole,
        StatusRole,
        CreatedAtRole,
        DateGroupRole,
        DirectionRole,
        FromNameRole,
        ToNameRole,
        FromCardLast4Role,
        ToCardLast4Role
    };

    explicit HistoryController(QObject* parent = nullptr);

    // QAbstractListModel
    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isLoading() const { return m_isLoading; }
    bool hasMore()   const { return m_hasMore; }

    Q_INVOKABLE void loadTransactions();   // Полный сброс
    Q_INVOKABLE void loadMore();           // Догрузка

signals:
    void loadingChanged();
    void hasMoreChanged();

private:
    static constexpr int PAGE_SIZE = 30;

    NetworkClient& m_net;
    QList<QVariantMap> m_items;
    bool m_isLoading = false;
    bool m_hasMore = true;
    int  m_offset = 0;
};