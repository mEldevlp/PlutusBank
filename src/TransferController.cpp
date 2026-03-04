#include "TransferController.h"
#include "UserSession.h"
#include <QDebug>

TransferController::TransferController(QObject* parent)
    : QObject(parent)
    , m_db(DatabaseManager::instance())
{
}

void TransferController::loadAccounts()
{
    int userId = UserSession::instance().userId();
    if (userId <= 0) return;

    m_accounts = m_db.getUserDebitAccounts(userId);
    qDebug() << u"✓ Загружено счетов для перевода:" << m_accounts.size();
    emit accountsChanged();
}

void TransferController::transferInternal(int fromAccountId, int toAccountId, double amount)
{
    qDebug() << u"Перевод между счетами:" << fromAccountId << u"→" << toAccountId << amount;

    if (amount <= 0) {
        emit transferFailed("Сумма должна быть больше нуля");
        return;
    }

    if (fromAccountId == toAccountId) {
        emit transferFailed("Выберите разные счета");
        return;
    }

    // Проверка заморозки/блокировки отправителя
    if (m_db.isAccountFrozenOrBlocked(fromAccountId)) {
        emit transferFailed("Карта отправителя заморожена или заблокирована");
        return;
    }

    // Проверка заморозки/блокировки получателя
    if (m_db.isAccountFrozenOrBlocked(toAccountId)) {
        emit transferFailed("Карта получателя заморожена или заблокирована");
        return;
    }

    if (m_db.transferBetweenAccounts(fromAccountId, toAccountId, amount)) {
        UserSession::instance().refreshAll();
        loadAccounts();
        emit transferSuccess("Перевод выполнен успешно");
    }
    else {
        emit transferFailed("Не удалось выполнить перевод");
    }
}

void TransferController::transferExternal(int fromAccountId, const QString& phone, double amount)
{
    qDebug() << u"Перевод по телефону:" << phone << amount;

    if (amount <= 0) {
        emit transferFailed("Сумма должна быть больше нуля");
        return;
    }

    // Проверка заморозки/блокировки отправителя
    if (m_db.isAccountFrozenOrBlocked(fromAccountId)) {
        emit transferFailed("Карта заморожена или заблокирована. Перевод невозможен");
        return;
    }

    QString formattedPhone = phone;
    if (!phone.startsWith("+7")) {
        formattedPhone = "+7" + phone;
    }

    if (formattedPhone == UserSession::instance().phone()) {
        emit transferFailed("Для перевода себе используйте 'Между счетами'");
        return;
    }

    // Проверка блокировки/заморозки карты получателя
    int recipientAccountId = m_db.findAccountByPhone(formattedPhone, "debit");
    if (recipientAccountId > 0 && m_db.isAccountFrozenOrBlocked(recipientAccountId)) {
        emit transferFailed("Карта получателя заблокирована. Перевод невозможен");
        return;
    }

    if (m_db.transferToUser(fromAccountId, formattedPhone, amount)) {
        UserSession::instance().refreshAll();
        loadAccounts();
        emit transferSuccess("Перевод выполнен успешно");
    }
    else {
        emit transferFailed("Получатель не найден или недостаточно средств");
    }
}

QString TransferController::findRecipientName(const QString& phone)
{
    QString formattedPhone = phone;
    if (!phone.startsWith("+7")) {
        formattedPhone = "+7" + phone;
    }

    int accountId = m_db.findAccountByPhone(formattedPhone, "debit");
    if (accountId > 0) {
        QString name = m_db.getAccountOwnerName(accountId);
        emit recipientFound(name);
        return name;
    }

    emit recipientNotFound();
    return "";
}