import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank
import "."

/*
    CryptoMainPage — корневая страница криптомодуля.

    - сверху: общий рублёвый баланс всех кошельков
    - блок "Мои кошельки": кошельки, где есть монеты — карточкой
      с балансом монет и эквивалентом в ₽
    - блок "Каталог": все 4 монеты с актуальной ценой
      (тап — переход к покупке)
    - кнопка "История крипто-операций"
*/
Item {
    id: root

    signal openBuy(var currency)
    signal openSell(var currency, real currentBalance)
    signal openTransfer(var currency, real currentBalance)
    signal openHistory()

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

            // --- Мои кошельки (только с ненулевым балансом) ---
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                property var ownedWallets: {
                    var arr = []
                    for (var i = 0; i < cryptoController.wallets.length; i++) {
                        if (cryptoController.wallets[i].balance > 0)
                            arr.push(cryptoController.wallets[i])
                    }
                    return arr
                }

                Text {
                    text: "Мои кошельки"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                    visible: parent.ownedWallets.length > 0
                }

                Repeater {
                    model: parent.ownedWallets

                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 88
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

                            // Цветной "значок" монеты
                            Rectangle {
                                width: 48; height: 48; radius: 24
                                color: modelData.icon_color
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon_letter
                                    font { pixelSize: 22; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    text: modelData.symbol
                                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }
                                Text {
                                    text: fmtCoins(modelData.balance) + " " + modelData.symbol
                                    font.pixelSize: 12
                                    color: "#9CA3AF"
                                }
                            }

                            Item {
                                width: parent.width - parent.children[0].width - parent.children[1].width - parent.spacing * 2
                                height: parent.height
                                Column {
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

                        // Кнопочный ряд (Купить / Продать / Перевести) на длительный тап? Нет, просто меню снизу через диалог:
                        MouseArea {
                            anchors.fill: parent
                            onClicked: walletActionDialog.show(modelData)
                        }
                    }
                }
            }

            // --- Каталог монет ---
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Text {
                    text: "Купить криптовалюту"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }

                Repeater {
                    model: cryptoController.currencies

                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 76
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

                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: modelData.icon_color
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon_letter
                                    font { pixelSize: 20; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    text: modelData.name
                                    font { pixelSize: 14; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }
                                Text {
                                    text: modelData.symbol
                                    font.pixelSize: 11
                                    color: "#9CA3AF"
                                }
                            }

                            Item {
                                width: parent.width - parent.children[0].width - parent.children[1].width - parent.spacing * 2
                                height: parent.height
                                Text {
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
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openBuy(modelData)
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    //   Диалог "что сделать с этим кошельком"
    // ============================================================
    Rectangle {
        id: walletActionDialog
        anchors.fill: parent
        color: "#CC000000"
        visible: false
        z: 100

        property var wallet: ({})

        function show(w) {
            wallet = w
            visible = true
        }
        function hide() { visible = false }

        MouseArea { anchors.fill: parent; onClicked: walletActionDialog.hide() }

        Rectangle {
            width: parent.width - 48
            anchors.centerIn: parent
            radius: 20
            color: "#1F2937"
            height: dlgCol.height + 40

            MouseArea { anchors.fill: parent }  // блокировать клик-сквозь

            Column {
                id: dlgCol
                width: parent.width - 32
                anchors.centerIn: parent
                spacing: 14

                Text {
                    width: parent.width
                    text: walletActionDialog.wallet.symbol ? walletActionDialog.wallet.symbol + " · " + fmtCoins(walletActionDialog.wallet.balance) : ""
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                }

                Repeater {
                    model: [
                        { label: "Докупить", action: "buy" },
                        { label: "Продать",  action: "sell" },
                        { label: "Перевести другому", action: "transfer" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 50
                        radius: 14
                        color: actMouse.pressed ? "#374151" : "#111827"
                        border.color: Theme.card

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font { pixelSize: 14; bold: true; family: manropeFont.name }
                            color: "#E5E7EB"
                        }

                        MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            onClicked: {
                                var w = walletActionDialog.wallet
                                walletActionDialog.hide()
                                // Конструируем "currency"-объект (без поля balance)
                                var currency = {
                                    "id": w.currency_id,
                                    "symbol": w.symbol,
                                    "name": w.name,
                                    "current_price": w.current_price,
                                    "icon_color": w.icon_color,
                                    "icon_letter": w.icon_letter
                                }
                                if (modelData.action === "buy") {
                                    root.openBuy(currency)
                                } else if (modelData.action === "sell") {
                                    root.openSell(currency, w.balance)
                                } else if (modelData.action === "transfer") {
                                    root.openTransfer(currency, w.balance)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
