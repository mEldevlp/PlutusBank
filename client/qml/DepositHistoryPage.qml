import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank

/*
    DepositHistoryPage — закрытые вклады.
    Список вкладов со status='closed': срок, тело, итоговая сумма,
    заработанные проценты, даты открытия/закрытия.
*/
Item {
    id: root

    signal backToMain()

    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

    function fmtRub(n) {
        if (typeof n !== "number") n = Number(n)
        if (!isFinite(n)) n = 0
        return Number(n).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
    }

    function fmtDate(s) {
        if (!s) return "—"
        var d = new Date(s)
        if (isNaN(d.getTime())) return s
        return d.toLocaleDateString(Qt.locale("ru_RU"), "d MMM yyyy")
    }

    function termLabel(months) {
        var n = parseInt(months)
        if (n === 1) return "1 месяц"
        if (n >= 2 && n <= 4) return n + " месяца"
        return n + " месяцев"
    }

    Component.onCompleted: {
        depositController.loadClosedDeposits()
    }

    // Фон
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A1229" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    Flickable {
        id: pageFlick
        anchors.fill: parent
        contentHeight: mainCol.height + 32
        clip: true

        Column {
            id: mainCol
            width: parent.width
            spacing: 20
            topPadding: 8
            bottomPadding: 24

            // ---- Заголовок ----
            Item {
                width: parent.width
                height: 56

                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: Theme.card
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16

                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        font.pixelSize: 20
                        color: Theme.textPrimary
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.backToMain()
                    }
                }

                Text {
                    text: "История вкладов"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: Theme.textPrimary
                    anchors.centerIn: parent
                }
                GuideButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: guide.open()
                }
            }

            // ---- Сводка ----
            Rectangle {
                id: summaryBlock
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 96
                radius: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "Закрытых вкладов: " + depositController.closedDeposits.length
                        font { pixelSize: 14; family: manropeFont.name }
                        color: "#9CA3AF"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: {
                            var total = 0
                            for (var i = 0; i < depositController.closedDeposits.length; i++) {
                                var d = depositController.closedDeposits[i]
                                total += Number(d.total_interest || 0)
                            }
                            return "+" + root.fmtRub(total)
                        }
                        font { pixelSize: 22; bold: true; family: manropeFont.name }
                        color: Theme.success
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "заработано всего"
                        font.pixelSize: 12
                        color: Theme.textMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // ---- Пустое состояние ----
            Item {
                width: parent.width
                height: 200
                visible: depositController.closedDeposits.length === 0 && !depositController.isLoading

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "📂"
                        font.pixelSize: 48
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "У вас пока нет закрытых вкладов"
                        font { pixelSize: 15; family: manropeFont.name }
                        color: Theme.textMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // ---- Список ----
            Repeater {
                id: closedList
                model: depositController.closedDeposits

                delegate: Rectangle {
                    required property var modelData
                    width: mainCol.width - 32
                    height: cardCol.height + 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 16
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                        GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                    }
                    border.color: Theme.card

                    Column {
                        id: cardCol
                        width: parent.width - 32
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        // Шапка строки
                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: Theme.success
                                opacity: 0.15
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "💰"
                                    font.pixelSize: 22
                                }
                            }

                            Column {
                                width: parent.width - 60
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Вклад на " + root.termLabel(modelData.term_months)
                                    font { pixelSize: 15; bold: true; family: manropeFont.name }
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: "ставка " + Number(modelData.annual_rate).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + "% годовых"
                                    font.pixelSize: 12
                                    color: Theme.textMuted
                                }
                            }
                        }

                        // Разделитель
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.cardBorder
                            opacity: 0.4
                        }

                        // Тело и итог
                        Row {
                            width: parent.width

                            Column {
                                width: parent.width / 2
                                spacing: 4
                                Text {
                                    text: "Внесено"
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                }
                                Text {
                                    text: root.fmtRub(Number(modelData.principal) + Number(modelData.total_topups || 0))
                                    font { pixelSize: 14; bold: true; family: manropeFont.name }
                                    color: Theme.textPrimary
                                }
                            }

                            Column {
                                width: parent.width / 2
                                spacing: 4
                                Text {
                                    text: "Получено"
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                    horizontalAlignment: Text.AlignRight
                                    width: parent.width
                                }
                                Text {
                                    text: root.fmtRub(modelData.final_balance || 0)
                                    font { pixelSize: 14; bold: true; family: manropeFont.name }
                                    color: Theme.textPrimary
                                    horizontalAlignment: Text.AlignRight
                                    width: parent.width
                                }
                            }
                        }

                        // Прибыль
                        Rectangle {
                            width: parent.width
                            height: 38
                            radius: 10
                            color: Theme.success
                            opacity: 0.12

                            Text {
                                anchors.centerIn: parent
                                text: "Прибыль:  +" + root.fmtRub(modelData.total_interest || 0)
                                font { pixelSize: 13; bold: true; family: manropeFont.name }
                                color: Theme.success
                                opacity: 1.0
                            }
                        }

                        // Даты
                        Row {
                            width: parent.width
                            Column {
                                width: parent.width / 2
                                spacing: 2
                                Text {
                                    text: "Открыт"
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                }
                                Text {
                                    text: root.fmtDate(modelData.opened_at)
                                    font.pixelSize: 12
                                    color: "#9CA3AF"
                                }
                            }
                            Column {
                                width: parent.width / 2
                                spacing: 2
                                Text {
                                    text: "Закрыт"
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                    horizontalAlignment: Text.AlignRight
                                    width: parent.width
                                }
                                Text {
                                    text: root.fmtDate(modelData.closed_at)
                                    font.pixelSize: 12
                                    color: "#9CA3AF"
                                    horizontalAlignment: Text.AlignRight
                                    width: parent.width
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 12 }
        }
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "depositHistory"
        steps: [
            { target: summaryBlock, flickable: pageFlick, title: "Сводка",
              text: "Сколько вкладов вы уже закрыли и сколько всего заработали на процентах." },
            { target: closedList, flickable: pageFlick, title: "Закрытые вклады",
              text: "По каждому вкладу — сколько внесли, сколько получили, прибыль и даты открытия и закрытия." }
        ]
    }
}
