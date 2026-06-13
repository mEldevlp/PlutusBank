import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank
import "."

/*
    CryptoHistoryPage — все операции пользователя:
    buy/sell/transfer_in/transfer_out, сгруппировано по дате.
*/
Item {
    id: root

    signal backToMain()

    FontLoader { id: manropeFont; source: "assets/fonts/Manrope-Bold.ttf" }

    Component.onCompleted: cryptoController.loadHistory()

    // Группировка по дате (dd.MM.yyyy) — created_at приходит как "dd.MM.yyyy HH:mm".
    function groupByDate(list) {
        var groups = []
        var byKey = {}
        for (var i = 0; i < list.length; i++) {
            var item = list[i]
            var dateStr = (item.created_at || "").split(" ")[0] || "—"
            if (!byKey[dateStr]) {
                byKey[dateStr] = { date: dateStr, items: [] }
                groups.push(byKey[dateStr])
            }
            byKey[dateStr].items.push(item)
        }
        return groups
    }

    function opIcon(t) {
        switch (t) {
            case "buy":           return "↓"
            case "sell":          return "↑"
            case "transfer_in":   return "←"
            case "transfer_out":  return "→"
        }
        return "•"
    }

    function opColor(t) {
        switch (t) {
            case "buy":           return Theme.success
            case "sell":          return "#F59E0B"
            case "transfer_in":   return "#3B82F6"
            case "transfer_out":  return "#A855F7"
        }
        return "#6B7280"
    }

    function opTitle(t) {
        switch (t) {
            case "buy":           return "Покупка"
            case "sell":          return "Продажа"
            case "transfer_in":   return "Перевод получен"
            case "transfer_out":  return "Перевод отправлен"
        }
        return t
    }

    function trimAmount(v) {
        return Number(v).toFixed(8).replace(/0+$/, "").replace(/\.$/, "")
    }

    // ----------- Header -----------
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 60
        color: "transparent"

        Rectangle {
            width: 36; height: 36; radius: 18
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: "#1F2937"
            //Text { anchors.centerIn: parent; text: "←"; font { pixelSize: 18; bold: true }; color: "#E5E7EB" }
            Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 18; font.bold: true; color: "#E5E7EB" }
            MouseArea { anchors.fill: parent; onClicked: root.backToMain() }
        }

        Text {
            anchors.centerIn: parent
            text: "История операций"
            font { pixelSize: 17; bold: true; family: manropeFont.name }
            color: "#FFFFFF"
        }

        Rectangle {
            width: 36; height: 36; radius: 18
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: refreshMouse.pressed ? "#374151" : "#1F2937"
            Text {
                anchors.centerIn: parent
                text: cryptoController.isLoading ? "…" : "⟳"
                font { pixelSize: 18; bold: true }
                color: "#E5E7EB"
            }
            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                onClicked: cryptoController.loadHistory()
            }
        }
        GuideButton {
            width: 36; height: 36; radius: 18
            anchors.right: parent.right
            anchors.rightMargin: 62
            anchors.verticalCenter: parent.verticalCenter
            onClicked: guide.open()
        }
    }

    // ------ Пустой стейт ------
    Item {
        anchors {
            top: header.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
        }
        visible: !cryptoController.isLoading && cryptoController.history.length === 0

        Column {
            anchors.centerIn: parent
            spacing: 14
            width: parent.width - 64

            Rectangle {
                width: 80; height: 80; radius: 40
                color: "#1F2937"
                anchors.horizontalCenter: parent.horizontalCenter
                Text { anchors.centerIn: parent; text: "◈"; font.pixelSize: 36; color: "#4B5563" }
            }
            Text {
                width: parent.width
                text: "Операций пока нет"
                font { pixelSize: 17; bold: true; family: manropeFont.name }
                color: "#FFFFFF"
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                text: "Здесь будут отображаться покупки, продажи и переводы криптовалют."
                font.pixelSize: 13
                color: "#9CA3AF"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    // ------ Лоадер ------
    Item {
        anchors {
            top: header.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
        }
        visible: cryptoController.isLoading && cryptoController.history.length === 0

        Text {
            anchors.centerIn: parent
            text: "Загружаем историю…"
            font.pixelSize: 13
            color: "#9CA3AF"
        }
    }

    // ------ Список ------
    ListView {
        id: list
        anchors {
            top: header.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
            topMargin: 8; bottomMargin: 16
        }
        clip: true
        spacing: 16
        visible: cryptoController.history.length > 0

        model: groupByDate(cryptoController.history)

        delegate: Column {
            required property var modelData
            width: list.width
            spacing: 8

            // Заголовок даты
            Text {
                text: modelData.date
                font { pixelSize: 12; bold: true; family: manropeFont.name }
                color: "#6B7280"
                x: 20
            }

            // Карточки операций
            Column {
                width: parent.width
                spacing: 8

                Repeater {
                    model: modelData.items
                    delegate: Rectangle {
                        required property var modelData
                        width: list.width - 32
                        x: 16
                        height: 78
                        radius: 14
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            // Иконка с типом операции (поверх цвета монеты)
                            Item {
                                width: 48; height: 48
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 24
                                    color: modelData.icon_color || Theme.accent
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon_letter || "?"
                                        font { pixelSize: 18; bold: true; family: manropeFont.name }
                                        color: "#FFFFFF"
                                    }
                                }

                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    color: opColor(modelData.operation_type)
                                    border.color: "#0F172A"
                                    border.width: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: opIcon(modelData.operation_type)
                                        font { pixelSize: 12; bold: true }
                                        color: "#FFFFFF"
                                    }
                                }
                            }

                            // Левый блок: тип + описание
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                width: (parent.width - 48 - parent.spacing * 2) * 0.55

                                Text {
                                    width: parent.width
                                    text: opTitle(modelData.operation_type) + " " + (modelData.symbol || "")
                                    font { pixelSize: 14; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: (modelData.description && modelData.description.length > 0)
                                          ? modelData.description
                                          : (modelData.created_at || "")
                                    font.pixelSize: 11
                                    color: "#9CA3AF"
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: modelData.price_per_coin > 0
                                    width: parent.width
                                    text: "по " + Number(modelData.price_per_coin).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                    font.pixelSize: 10
                                    color: "#6B7280"
                                    elide: Text.ElideRight
                                }
                            }

                            // Правый блок: суммы
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                width: (parent.width - 48 - parent.spacing * 2) * 0.45

                                Text {
                                    width: parent.width
                                    text: {
                                        var sign = (modelData.operation_type === "buy"
                                                    || modelData.operation_type === "transfer_in")
                                                   ? "+" : "−"
                                        return sign + trimAmount(modelData.coin_amount) + " " + (modelData.symbol || "")
                                    }
                                    font { pixelSize: 14; bold: true; family: manropeFont.name }
                                    color: opColor(modelData.operation_type)
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: modelData.rub_amount > 0
                                    width: parent.width
                                    text: {
                                        var sign = (modelData.operation_type === "buy") ? "−"
                                                 : (modelData.operation_type === "sell") ? "+" : ""
                                        return sign + Number(modelData.rub_amount).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                    }
                                    font.pixelSize: 11
                                    color: "#9CA3AF"
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: (modelData.created_at || "").split(" ")[1] || ""
                                    font.pixelSize: 10
                                    color: "#6B7280"
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }
        }

        ScrollBar.vertical: ScrollBar { active: true }
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "cryptoHistory"
        steps: [
            { title: "История крипто-операций",
              text: "Все ваши покупки, продажи и переводы криптовалюты, сгруппированные по датам." },
            { target: list, padding: 0, radius: 0, title: "Список операций",
              text: "У каждой операции — тип, количество монет, курс сделки и сумма в рублях. Зелёным — поступления, красным — списания." },
            { title: "Обновление",
              text: "Кнопка «⟳» в шапке перезагрузит историю с сервера." }
        ]
    }
}
