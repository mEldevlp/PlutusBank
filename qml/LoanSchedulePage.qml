import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var loanData: ({})

    signal backToLoans()

    property string resultMessage: ""
    property bool   resultSuccess: false

    Component.onCompleted: {
        loanController.loadSchedule(loanData.id ?? 0)
    }

    Connections {
        target: loanController
        function onPaymentSuccess(message) {
            resultSuccess = true
            resultMessage = message
        }
        function onPaymentFailed(error) {
            resultSuccess = false
            resultMessage = error
        }
        function onLoanClosed() {
            closedDialog.open()
        }
        function onScheduleChanged() {
            // Обновляем данные кредита при изменении графика
            loanController.loadUserLoans()
        }
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
        anchors.fill: parent
        contentHeight: mainCol.height + 40
        clip: true

        Column {
            id: mainCol
            width: parent.width
            spacing: 20

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

                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        onClicked: root.backToLoans()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: loanData.product_name ?? "График"
                    font { pixelSize: 18; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }
            }

            // Сводка кредита
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: summaryCol.height + 28
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                }
                border.color: Theme.card

                Column {
                    id: summaryCol
                    width: parent.width - 28
                    anchors.centerIn: parent
                    spacing: 12

                    Row {
                        width: parent.width
                        Column {
                            width: parent.width / 2; spacing: 2
                            Text { text: "Сумма кредита"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: Number(loanData.principal ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                font { pixelSize: 16; bold: true }
                                color: "#F7F7FB"
                            }
                        }
                        Column {
                            width: parent.width / 2; spacing: 2
                            Text { text: "Ставка"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: Number(loanData.annual_rate ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 1) + "% годовых"
                                font { pixelSize: 16; bold: true }
                                color: "#F7F7FB"
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#374151" }

                    Row {
                        width: parent.width
                        Column {
                            width: parent.width / 3; spacing: 2
                            Text { text: "Выплачено"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: Number(loanData.total_paid ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                font { pixelSize: 13; bold: true }
                                color: Theme.accent
                            }
                        }
                        Column {
                            width: parent.width / 3; spacing: 2
                            Text { text: "Остаток"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: Number(loanData.remaining_balance ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0) + " ₽"
                                font { pixelSize: 13; bold: true }
                                color: "#EF4444"
                            }
                        }
                        Column {
                            width: parent.width / 3; spacing: 2
                            Text { text: "След. платёж"; font.pixelSize: 11; color: "#6B7280" }
                            Text {
                                text: loanData.next_payment_date ?? "—"
                                font { pixelSize: 13; bold: true }
                                color: "#E5E7EB"
                            }
                        }
                    }
                }
            }

            // Кнопка оплаты
            Rectangle {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                height: 52; radius: 16
                color: (loanData.status === "active" && !loanController.isLoading) ? Theme.accent : "#374151"
                opacity: (loanData.status === "active" && !loanController.isLoading) ? 1.0 : 0.5
                visible: loanData.status !== "closed"

                Text {
                    anchors.centerIn: parent
                    text: loanController.isLoading ? "Обработка..." :
                          "Внести платёж " + Number(loanData.monthly_payment ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 2) + " ₽"
                    font { pixelSize: 15; bold: true; family: manropeFont.name }
                    color: "#0A1229"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: loanData.status === "active" && !loanController.isLoading
                    onClicked: {
                        resultMessage = ""
                        loanController.makePayment(loanData.id)
                    }
                }
            }

            // Результат
            Text {
                visible: resultMessage.length > 0
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                text: resultMessage
                font { pixelSize: 14; bold: true }
                color: resultSuccess ? Theme.accent : "#EF4444"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // График платежей
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: "График платежей"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                }

                // Заголовок таблицы
                Row {
                    width: parent.width
                    height: 32

                    Text { width: parent.width * 0.10; text: "№";      font.pixelSize: 11; font.bold: true; color: "#6B7280"; verticalAlignment: Text.AlignVCenter }
                    Text { width: parent.width * 0.22; text: "Дата";    font.pixelSize: 11; font.bold: true; color: "#6B7280"; verticalAlignment: Text.AlignVCenter }
                    Text { width: parent.width * 0.22; text: "Тело";    font.pixelSize: 11; font.bold: true; color: "#6B7280"; verticalAlignment: Text.AlignVCenter }
                    Text { width: parent.width * 0.22; text: "%";       font.pixelSize: 11; font.bold: true; color: "#6B7280"; verticalAlignment: Text.AlignVCenter }
                    Text { width: parent.width * 0.24; text: "Статус";  font.pixelSize: 11; font.bold: true; color: "#6B7280"; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight }
                }
                Rectangle { width: parent.width; height: 1; color: "#374151" }

                // Строки
                Repeater {
                    model: loanController.schedule

                    delegate: Column {
                        width: parent.width

                        required property var modelData
                        required property int index


                        readonly property string rowStatusIcon: {
                            var s = modelData.status ?? ""
                            if (s === "paid")    return "assets/check-mark-blue.svg"
                            if (s === "overdue") return "assets/exclamation-orange.svg"
                            return "assets/empty.svg"
                        }

                        Row {
                            width: parent.width
                            height: 36

                            Text {
                                width: parent.width * 0.10
                                height: parent.height 
                                text: modelData.payment_number ?? ""
                                font.pixelSize: 12; color: Theme.accent
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                width: parent.width * 0.22
                                height: parent.height 
                                text: modelData.due_date ?? ""
                                font.pixelSize: 12; color: "#E5E7EB"
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                width: parent.width * 0.22
                                height: parent.height 
                                text: Number(modelData.principal_part ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0)
                                font.pixelSize: 12; color: "#E5E7EB"
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                width: parent.width * 0.22
                                height: parent.height 
                                text: Number(modelData.interest_part ?? 0).toLocaleString(Qt.locale("ru_RU"), 'f', 0)
                                font.pixelSize: 12; color: Theme.accent
                                verticalAlignment: Text.AlignVCenter
                            }
                            Item {
                                width: parent.width * 0.24
                                height: parent.height

                                Image {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20; height: 20
                                    source: rowStatusIcon
                                    sourceSize: Qt.size(20, 20)
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width; height: 1
                            color: "#1F2937"
                            visible: index < loanController.schedule.length - 1
                        }
                    }
                }
            }

            Item { width: 1; height: 30 }
        }
    }

    // Диалог успешного закрытия
    Dialog {
        id: closedDialog
        anchors.centerIn: parent
        width: parent.width - 48
        modal: true
        closePolicy: Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 20
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
            }
            border.color: Theme.accent
        }

        contentItem: Column {
            spacing: 16
            padding: 24
            width: parent.width

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56; height: 56
                source: "assets/congratulate.svg"
                sourceSize: Qt.size(56, 56)
            }

            Text {
                text: "Успешное закрытие кредита"
                font { pixelSize: 18; bold: true; family: manropeFont.name }
                color: "#F7F7FB"
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: "Поздравляем! Вы полностью погасили кредит\n«" +
                      (loanData.product_name ?? "") + "».\nВсе обязательства выполнены."
                font.pixelSize: 14
                color: "#9CA3AF"
                width: parent.width - 48
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: parent.width - 48
                height: 48; radius: 14
                color: Theme.accent
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "Отлично!"
                    font { pixelSize: 15; bold: true; family: manropeFont.name }
                    color: "#0A1229"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        closedDialog.close()
                        root.backToLoans()
                    }
                }
            }
        }
    }
}
