import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank

Item {
    id: root

    signal backToMain()
    signal openSavings()
    signal openNewDeposit()      // открыть форму нового вклада
    signal openDepositDetail(var deposit)
    signal openHistory()

    Component.onCompleted: {
        depositController.refreshAll()
    }

    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A1229" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: mainCol.height + 40
        clip: true

        Column {
            id: mainCol
            width: parent.width
            spacing: 18

            // Шапка
            Item {
                width: parent.width
                height: 56

                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: "transparent"
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        source: "assets/arrow-left.svg"
                        sourceSize: Qt.size(24, 24)
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.backToMain() }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Копить"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }
                GuideButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: guide.open()
                }
            }

            // Большой заголовок (как на референсе)
            Text {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Копить"
                font { pixelSize: 34; bold: true; family: manropeFont.name }
                color: "#FFFFFF"
                topPadding: 8
                bottomPadding: 8
            }

            // ----- Вклад -----
            Rectangle {
                id: depositBanner
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 130
                radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    // «Иконка»
                    Rectangle {
                        width: 96; height: 96; radius: 16
                        color: "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "💰"
                            font.pixelSize: 48
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 96 - 16
                        spacing: 6

                        Text {
                            text: "Вклад"
                            font { pixelSize: 18; bold: true; family: manropeFont.name }
                            color: "#FFFFFF"
                        }

                        Text {
                            // Покажем ставку для 6 мес как пример
                            property double demoRate: depositController.rateForTerm(6)
                            text: "Доходность до " + demoRate.toFixed(1).replace(".", ",") + "% годовых\nна срок до 12 месяцев"
                            font.pixelSize: 13
                            color: "#9CA3AF"
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Text {
                            visible: depositController.deposits.length > 0
                            text: "Активных: " + depositController.deposits.length
                            font { pixelSize: 12; bold: true }
                            color: Theme.accent
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    // Список существующих вкладов уже виден ниже на этой же странице,
                    // поэтому верхняя карточка-баннер всегда открывает форму нового вклада.
                    onClicked: root.openNewDeposit()
                }
            }

            // ----- Накопительный счёт -----
            Rectangle {
                id: savingsBanner
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 130
                radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    Rectangle {
                        width: 96; height: 96; radius: 16
                        color: "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "🪙"
                            font.pixelSize: 48
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 96 - 16
                        spacing: 6

                        Text {
                            text: "Накопительный счёт"
                            font { pixelSize: 18; bold: true; family: manropeFont.name }
                            color: "#FFFFFF"
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Text {
                            text: "Ставка до 10%, снятие денег\nбез потери процентов"
                            font.pixelSize: 13
                            color: "#9CA3AF"
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Text {
                            visible: depositController.hasSavings
                            text: depositController.hasSavings
                                  ? Number(depositController.savings.balance ?? 0)
                                        .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                  : ""
                            font { pixelSize: 13; bold: true }
                            color: Theme.accent
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.openSavings()
                }
            }

            // ----- История операций -----
            Rectangle {
                id: historyBanner
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 56
                radius: 14
                color: "#111827"
                border.color: Theme.card

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Image {
                        width: 22; height: 22
                        source: "assets/history.svg"
                        sourceSize: Qt.size(22, 22)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "История закрытых вкладов"
                        font.pixelSize: 14
                        color: "#E5E7EB"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea { anchors.fill: parent; onClicked: root.openHistory() }
            }

            // Активные вклады (превью списком)
            Column {
                id: activeDeposits
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                visible: depositController.deposits.length > 0

                Text {
                    text: "Мои вклады"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }

                Repeater {
                    model: depositController.deposits

                    delegate: Rectangle {
                        required property var modelData

                        width: parent.width
                        height: 78
                        radius: 14
                        color: "#111827"
                        border.color: Theme.card

                        Row {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 90
                                spacing: 4

                                Row {
                                    spacing: 8
                                    Text {
                                        text: "Вклад на " + modelData.term_months + " мес"
                                        font { pixelSize: 14; bold: true }
                                        color: "#E5E7EB"
                                    }
                                    Rectangle {
                                        visible: modelData.can_claim
                                        width: claimLbl.width + 12; height: 20; radius: 10
                                        color: Theme.success
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            id: claimLbl
                                            anchors.centerIn: parent
                                            text: "Готово"
                                            font { pixelSize: 10; bold: true }
                                            color: "#0A1229"
                                        }
                                    }
                                }

                                Text {
                                    text: Number(modelData.current_balance ?? 0)
                                            .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                                    color: "#FFFFFF"
                                }

                                Text {
                                    text: "+" + Number(modelData.total_interest ?? 0)
                                            .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽ · "
                                          + Number(modelData.annual_rate ?? 0)
                                            .toLocaleString(Qt.locale("ru_RU"), 'f', 2) + "%"
                                    font.pixelSize: 11
                                    color: Theme.success
                                }
                            }

                            Image {
                                width: 16; height: 16
                                source: "assets/arrow-left.svg"
                                sourceSize: Qt.size(16, 16)
                                rotation: 180
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: 0.5
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.openDepositDetail(modelData)
                        }
                    }
                }
            }
        }
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "depositMain"
        steps: [
            { target: depositBanner, flickable: flick, title: "Срочный вклад",
              text: "Откройте вклад на срок от 1 до 12 месяцев — чем дольше срок, тем выше ставка. Нажмите на карточку, чтобы подобрать условия." },
            { target: savingsBanner, flickable: flick, title: "Накопительный счёт",
              text: "Гибкая альтернатива вкладу: ставка до 10%, пополнение и снятие в любой момент без потери процентов." },
            { target: activeDeposits, flickable: flick, title: "Мои вклады",
              text: "Список ваших активных вкладов. Нажмите на вклад, чтобы посмотреть детали, пополнить его или забрать деньги по окончании срока." },
            { target: historyBanner, flickable: flick, title: "История",
              text: "Архив закрытых вкладов: сколько внесли, сколько получили и какая вышла прибыль." }
        ]
    }
}
