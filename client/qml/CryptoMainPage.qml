import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank
import "."

/*
    CryptoMainPage — корневая страница криптомодуля.

    - сверху: общий рублёвый баланс всех кошельков
    - блок "Криптовалюты": единый список всех монет каталога.
        * если у пользователя есть баланс по монете — карточка
          с количеством монет, рублёвой стоимостью и ценой за монету
          (как раньше выглядел блок "Мои кошельки");
        * если баланса нет — компактная карточка: тикер + текущая цена.
      Тап по любой монете — переход на детальную страницу (CryptoCoinDetailPage),
      откуда уже можно купить/продать/перевести.
    - кнопка "История крипто-операций" — в шапке.
*/
Item {
    id: root

    signal openBuy(var currency)
    signal openSell(var currency, real currentBalance)
    signal openTransfer(var currency, real currentBalance)
    signal openHistory()
    signal openCoinDetail(var currency)

    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

    Component.onCompleted: {
        cryptoController.loadCurrencies()
        cryptoController.loadWallets()
    }

    // Локальный helper для форматирования числа монет: до 8 знаков, без хвостовых нулей
    function fmtCoins(n) {
        if (typeof n !== "number") n = Number(n)
        if (!isFinite(n) || n === 0) return "0"
        var s = n.toFixed(8)
        return s.replace(/0+$/, "").replace(/\.$/, "")
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: mainCol.height + 32
        clip: true
        boundsBehavior: Flickable.DragAndOvershootBounds

        property bool readyToRefresh: false

        onContentYChanged: {
            if (contentY < -70 && !cryptoController.isLoading && atYBeginning)
                readyToRefresh = true
            else if (contentY >= -70)
                readyToRefresh = false
        }
        onDraggingChanged: {
            if (!dragging && readyToRefresh) {
                cryptoController.refreshAll()
                readyToRefresh = false
            }
        }

        Column {
            id: mainCol
            width: parent.width
            spacing: 24
            topPadding: 24
            bottomPadding: 24

            // --- Заголовок ---
            Item {
                width: parent.width - 32
                height: 36
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    text: "Крипто-кошелёк"
                    font { pixelSize: 22; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 36; height: 36; radius: 18
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#1F2937"

                    Image {
                        anchors.centerIn: parent
                        width: 18; height: 18
                        source: "assets/history.svg"
                        sourceSize: Qt.size(18, 18)
                    }

                    MouseArea { anchors.fill: parent; onClicked: root.openHistory() }
                }
            }

            // --- Общий баланс портфеля ---
            Rectangle {
                width: parent.width - 32
                height: 124
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Column {
                    anchors {
                        left: parent.left; leftMargin: 24
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    Text {
                        text: "Стоимость портфеля"
                        font.pixelSize: 14
                        color: "#9CA3AF"
                        opacity: 0.7
                    }

                    Text {
                        text: cryptoController.totalRubValue.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                        font { pixelSize: 28; bold: true; family: manropeFont.name }
                        color: "#FFFFFF"
                    }

                    Text {
                        text: "Котировки обновляются в реальном времени"
                        font.pixelSize: 11
                        color: "#9CA3AF"
                        opacity: 0.6
                    }
                }

                // Анимированный пульс — индикация live-обновления
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Theme.success
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: cryptoController.autoRefreshEnabled
                        NumberAnimation { from: 0.4; to: 1.0; duration: 800 }
                        NumberAnimation { from: 1.0; to: 0.4; duration: 800 }
                    }
                }
            }

            // --- Криптовалюты (единый список: каталог + текущие балансы) ---
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                // Объединяем каталог валют с кошельками пользователя.
                // Для каждой валюты добавляем поля balance / rub_value (0, если не куплена).
                property var mergedCurrencies: {
                    var result = []
                    var wallets = cryptoController.wallets
                    for (var i = 0; i < cryptoController.currencies.length; i++) {
                        var cur = cryptoController.currencies[i]
                        var entry = {
                            "id":            cur.id,
                            "symbol":        cur.symbol,
                            "name":          cur.name,
                            "current_price": cur.current_price,
                            "icon_color":    cur.icon_color,
                            "icon_letter":   cur.icon_letter,
                            "balance":       0,
                            "rub_value":     0
                        }
                        for (var j = 0; j < wallets.length; j++) {
                            if (wallets[j].currency_id === cur.id && wallets[j].balance > 0) {
                                entry.balance   = wallets[j].balance
                                entry.rub_value = wallets[j].rub_value
                                break
                            }
                        }
                        result.push(entry)
                    }
                    return result
                }

                Text {
                    text: "Криптовалюты"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }

                Repeater {
                    model: parent.mergedCurrencies

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isOwned: modelData.balance > 0

                        width: parent.width
                        height: isOwned ? 88 : 76
                        radius: 16
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            // Цветной "значок" монеты — крупнее, если монета куплена
                            Rectangle {
                                width: isOwned ? 48 : 44
                                height: width
                                radius: width / 2
                                color: modelData.icon_color
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon_letter
                                    font { pixelSize: isOwned ? 22 : 20; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }
                            }

                            // Левая текстовая колонка: тикер (+ количество монет, если куплена)
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    text: modelData.symbol
                                    font { pixelSize: isOwned ? 16 : 14; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }
                                Text {
                                    visible: isOwned
                                    text: fmtCoins(modelData.balance) + " " + modelData.symbol
                                    font.pixelSize: 12
                                    color: "#9CA3AF"
                                }
                            }

                            // Правая часть: цена / стоимость портфеля по этой монете
                            Item {
                                width: parent.width - parent.children[0].width - parent.children[1].width - parent.spacing * 2
                                height: parent.height

                                // ── Не куплена: одна цифра — текущая цена за монету
                                Text {
                                    visible: !isOwned
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Number(modelData.current_price).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                    font { pixelSize: 15; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"

                                    // Тонкая анимация смены цены
                                    Behavior on text {
                                        SequentialAnimation {
                                            NumberAnimation { target: parent; property: "opacity"; to: 0.4; duration: 100 }
                                            PropertyAction  { }
                                            NumberAnimation { target: parent; property: "opacity"; to: 1.0; duration: 200 }
                                        }
                                    }
                                }

                                // ── Куплена: рублёвая стоимость портфеля + цена за монету
                                Column {
                                    visible: isOwned
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Text {
                                        anchors.right: parent.right
                                        text: modelData.rub_value.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                        font { pixelSize: 16; bold: true; family: manropeFont.name }
                                        color: "#FFFFFF"
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: modelData.current_price.toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽/" + modelData.symbol
                                        font.pixelSize: 11
                                        color: "#9CA3AF"
                                    }
                                }
                            }
                        }

                        // Тап по любой монете — открыть детальную страницу
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openCoinDetail(modelData)
                        }
                    }
                }
            }
        }
    }
}
