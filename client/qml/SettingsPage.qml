import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank

Item {
    id: root
    signal backToMain()
    signal loggedOut()

    Component.onCompleted: {
        userSession.loadUserData()
        userSession.loadCards()
    }

    FontLoader {
        id: manropeFont
        source: "assets/fonts/Manrope-Bold.ttf"
    }

    // Фон
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A1229" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    // Шапка
    Item {
        id: header
        width: parent.width
        height: 56
        z: 10

        Image {
            width: 24; height: 24
            source: "assets/arrow-left.svg"
            sourceSize: Qt.size(24, 24)
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
        

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                onClicked: root.backToMain()
            }
        }

        Text {
            anchors.centerIn: parent
            text: "Настройки"
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

    Flickable {
        id: settingsFlick
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: content.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 20
            spacing: 24

            // Ваши данные
            Rectangle {
                id: personalBlock
                width: parent.width
                radius: 16
                    
                gradient: Gradient {
                    GradientStop { position: 0.40; color: Theme.grBlockPosStart }
                    GradientStop { position: 1.0; color: Theme.grBlockAltPosEnd }
                }

                height: dataCol.height + 32

                Column {
                    id: dataCol
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    spacing: 12

                    Text {
                        text: "Ваши данные"
                        font { pixelSize: 16; bold: true; family: manropeFont.name }
                        color: "#F7F7FB"
                    }

                    SettingsField { label: "ФИО";     value: userSession.fullName }
                    SettingsField { label: "Телефон";  value: userSession.phone }
                    SettingsField { label: "Почта";    value: userSession.email }
                    SettingsField { label: "Паспорт";  value: userSession.passportSeries + " " + userSession.passportNumber }
                    SettingsField { label: "Адрес";    value: userSession.address || "Не указан" }
                }
            }

            // Основной счёт
            Column {
                id: primaryBlock
                width: parent.width
                spacing: 2

                Text {
                    text: "Основной счёт"
                    font { pixelSize: 16; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                    bottomPadding: 4
                }

                Text {
                    text: "Счёт для входящих переводов по номеру телефона"
                    font.pixelSize: 12
                    color: "#6B7280"
                    bottomPadding: 10
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: accountsList.height + 24
                    radius: 16
                    gradient: Gradient {
                        GradientStop { position: 0.40; color: Theme.grBlockPosStart }
                        GradientStop { position: 1.0; color: Theme.grBlockAltPosEnd }
                    }

                    Column {
                        id: accountsList
                        width: parent.width - 32
                        anchors.centerIn: parent
                        spacing: 0

                        Repeater {
                            model: userSession.getDebitCards()

                            delegate: Column {
                                width: parent.width

                                required property var modelData
                                required property int index

                                readonly property bool isCurrent:
                                    modelData.account_id === userSession.primaryAccountId

                                // Разделитель перед каждым элементом кроме первого
                                Rectangle {
                                    visible: index > 0
                                    width: parent.width
                                    height: 1
                                    color: "#374151"
                                }

                                Item {
                                    width: parent.width
                                    height: 56

                                    // Лого платёжной системы
                                    Image {
                                        id: brandLogo
                                        width: 36; height: 22
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        fillMode: Image.PreserveAspectFit
                                        source: {
                                            var b = modelData.card_brand ?? ""
                                            if (b === "visa")       return "assets/visa.svg"
                                            if (b === "mastercard") return "assets/mastercard.svg"
                                            return "assets/mir.svg"
                                        }
                                        sourceSize: Qt.size(36, 22)
                                    }

                                    // Инфо карты
                                    Column {
                                        anchors.left: brandLogo.right
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Text {
                                            text: "•••• " + (modelData.card_number ?? "").slice(-4)
                                            font { pixelSize: 14; bold: true; family: "Courier" }
                                            color: "#E5E7EB"
                                        }

                                        Text {
                                            text: modelData.expiry_date ?? ""
                                            font.pixelSize: 11
                                            color: "#6B7280"
                                        }
                                    }

                                    // Индикатор текущего выбора / кнопка
                                    Rectangle {
                                        width: 22; height: 22; radius: 11
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "transparent"
                                        border.color: isCurrent ? Theme.accent : "#4B5563"
                                        border.width: 2

                                        Rectangle {
                                            width: 12; height: 12; radius: 6
                                            anchors.centerIn: parent
                                            color: Theme.accent
                                            visible: isCurrent
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (!isCurrent)
                                                confirmDialog.show(modelData.account_id,
                                                    (modelData.card_number ?? "").slice(-4))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Кнопка «Выйти»
            Rectangle {
                id: logoutBtn
                width: parent.width
                height: 50
                radius: 16
                color: "#7F1D1D"

                Text {
                    anchors.centerIn: parent
                    text: "Выйти из аккаунта"
                    font { pixelSize: 15; bold: true; family: manropeFont.name }
                    color: "#FCA5A5"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: logoutDialog.visible = true
                }
            }

            Item { width: 1; height: 20 }  // нижний отступ
        }
    }

    // Диалог подтверждения
    Rectangle {
        id: confirmDialog
        anchors.fill: parent
        color: "#CC000000"
        visible: false
        z: 100

        property int pendingAccountId: -1
        property string pendingLast4: ""

        function show(accountId, last4) {
            pendingAccountId = accountId
            pendingLast4 = last4
            visible = true
        }

        function hide() {
            visible = false
        }

        // Блок клика по фону
        MouseArea {
            anchors.fill: parent
            onClicked: confirmDialog.hide()
        }

        Rectangle {
            width: parent.width - 48
            height: dialogContent.height + 40
            anchors.centerIn: parent
            radius: 20
            color: "#1F2937"

            // Не пропускать клик на фон
            MouseArea { anchors.fill: parent }

            Column {
                id: dialogContent
                width: parent.width - 40
                anchors.centerIn: parent
                spacing: 16

                Text {
                    width: parent.width
                    text: "Назначить основным?"
                    font { pixelSize: 17; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: "Карта •••• " + confirmDialog.pendingLast4 +
                          " станет основным счётом для входящих переводов по номеру телефона."
                    font.pixelSize: 13
                    color: "#9CA3AF"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.3
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: "#374151"

                        Text {
                            anchors.centerIn: parent
                            text: "Отмена"
                            font { pixelSize: 14; bold: true }
                            color: "#D1D5DB"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: confirmDialog.hide()
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: "Назначить"
                            font { pixelSize: 14; bold: true }
                            color: "#050B1A"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                userSession.setPrimaryAccount(confirmDialog.pendingAccountId)
                                confirmDialog.hide()
                            }
                        }
                    }
                }
            }
        }
    }

    // Диалог подтверждения выхода
    Rectangle {
        id: logoutDialog
        anchors.fill: parent
        color: "#CC000000"
        visible: false
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: logoutDialog.visible = false
        }

        Rectangle {
            width: parent.width - 48
            height: logoutDialogCol.height + 40
            anchors.centerIn: parent
            radius: 20
            color: "#1F2937"

            MouseArea { anchors.fill: parent }

            Column {
                id: logoutDialogCol
                width: parent.width - 40
                anchors.centerIn: parent
                spacing: 16

                Text {
                    width: parent.width
                    text: "Выйти из аккаунта?"
                    font { pixelSize: 17; bold: true; family: manropeFont.name }
                    color: "#F7F7FB"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: "Вы уверены, что хотите выйти? Для повторного входа потребуется ввести логин и пароль."
                    font.pixelSize: 13
                    color: "#9CA3AF"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.3
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: "#374151"

                        Text {
                            anchors.centerIn: parent
                            text: "Отмена"
                            font { pixelSize: 14; bold: true }
                            color: "#D1D5DB"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: logoutDialog.visible = false
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: 44
                        radius: 12
                        color: "#DC2626"

                        Text {
                            anchors.centerIn: parent
                            text: "Выйти"
                            font { pixelSize: 14; bold: true }
                            color: "#FFFFFF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                logoutDialog.visible = false
                                userSession.logout()
                                root.loggedOut()
                            }
                        }
                    }
                }
            }
        }
    }

    // INLINE-КОМПОНЕНТЫ 

    // Поле данных в стиле реквизитов (label сверху, тёмный бокс с копированием)
    component SettingsField: Column {
        property string label: ""
        property string value: ""

        width: parent.width
        spacing: 4

        Text {
            text: label
            font.pixelSize: 11
            color: "#6B7280"
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: 10
            color: "#111827"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: sfCopyBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: value
                font.pixelSize: 14
                font.family: "Courier"
                color: "#E5E7EB"
                elide: Text.ElideRight
            }

            Image {
                id: sfCopyBtn
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                source: "assets/copy.svg"
                sourceSize: Qt.size(18, 18)
                opacity: sfCopyArea.pressed ? 0.5 : 1.0

                MouseArea {
                    id: sfCopyArea
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        cardController.copyToClipboard(value)
                        sfToast.show()
                    }
                }
            }

            Rectangle {
                id: sfToast
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.bottom: parent.top
                anchors.bottomMargin: 4
                width: sfToastLabel.width + 16
                height: 24
                radius: 8
                color: Theme.green
                opacity: 0
                visible: opacity > 0

                Text {
                    id: sfToastLabel
                    anchors.centerIn: parent
                    text: "Скопировано"
                    font.pixelSize: 11
                    color: "#FFFFFF"
                }

                function show() {
                    opacity = 1
                    sfHideTimer.restart()
                }

                Timer {
                    id: sfHideTimer
                    interval: 1200
                    onTriggered: sfToast.opacity = 0
                }

                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }

    component SettingsDivider: Rectangle {
        width: parent.width
        height: 1
        color: "#374151"
    }
    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "settings"
        steps: [
            { target: personalBlock, flickable: settingsFlick, title: "Ваши данные",
              text: "Личные данные профиля: ФИО, телефон, почта, паспорт и адрес. Коснитесь значения, чтобы скопировать его." },
            { target: primaryBlock, flickable: settingsFlick, title: "Основной счёт",
              text: "Именно на этот счёт приходят входящие переводы по номеру телефона. Нажмите «Назначить» у другой карты, чтобы сменить его." },
            { target: logoutBtn, flickable: settingsFlick, title: "Выход",
              text: "Завершает сеанс. Для повторного входа понадобятся логин и пароль." }
        ]
    }
}