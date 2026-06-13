import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: root

    // Сигналы
    signal backToMain()
    signal cardCreatedSuccess()

    // Состояние мастера
    property int    step: 1            // 1‑4
    property string cardType: ""       // "debit" | "credit"
    property string paySystem: ""      // "visa" | "mastercard" | "mir"
    property var    cardResult: ({})    // данные созданной карты

    // Вычисляемые вспомогательные свойства
    readonly property string cardTypeLabel:
        cardType === "debit" ? "Дебетовая" : "Кредитная"

    readonly property string paySystemLabel:
        paySystem === "visa"       ? "Visa" :
        paySystem === "mastercard" ? "Mastercard" : "МИР"

    readonly property string expiryPreview: {
        var d = new Date();
        d.setFullYear(d.getFullYear() + 5);
        var mm = ("0" + (d.getMonth() + 1)).slice(-2);
        var yy = String(d.getFullYear()).slice(-2);
        return mm + "/" + yy;
    }

    readonly property string stepTitle:
        step === 1 ? "Выберите тип карты" :
        step === 2 ? "Платёжная система" :
        step === 3 ? "Подтверждение"      :
                     "Карта создана!"

    // Цвета платёжных систем
    function brandAccent(brand) {
        if (brand === "visa")       return "#3B82F6";
        if (brand === "mastercard") return "#EF4444";
        if (brand === "mir")        return "#10B981";
        return "#6B7280";
    }

    function brandGradientStart(brand) {
        if (brand === "visa")       return Theme.grVisaPosStart;
        if (brand === "mastercard") return Theme.grMSPosStart;
        if (brand === "mir")        return Theme.grMirPosStart;
        return Theme.grBlockPosStart;
    }

    function brandGradientEnd(brand) {
        if (brand === "visa")       return Theme.grVisaPosEnd;
        if (brand === "mastercard") return Theme.grMSPosEnd;
        if (brand === "mir")        return Theme.grMirPosStart;
        return Theme.grBlockPosEnd;
    }

    // Фон
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0B1120" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    //  Прокручиваемая область
    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: mainLayout.height + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainLayout
            width: parent.width - 32
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Item { Layout.preferredHeight: 16 }  // верхний отступ

            // Заголовок + кнопка назад
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // Круглая кнопка «<-» — только на 1‑м шаге
                Item {
                    width: 42; height: 42;
                    visible: step === 1

                    Image {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        source: "assets/arrow-left.svg"
                        sourceSize: Qt.size(22, 22)
                    }

                    MouseArea {
                        id: backBtnArea
                        anchors.fill: parent
                        onClicked: root.backToMain()
                    }
                }

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: "Новая карта"
                        font.pixelSize: 13
                        color: "#6B7280"
                    }

                    Text {
                        text: root.stepTitle
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: "#F9FAFB"
                    }
                }
            }

            // Индикатор шагов
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: 4
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 3
                        radius: 2
                        color: (index + 1) <= root.step ? Theme.accent: Theme.card
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }
            }

            //  ШАГ 1 — Тип карты
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14
                visible: step === 1

                Text {
                    Layout.fillWidth: true
                    text: "Выберите тип карты, которую хотите открыть"
                    font.pixelSize: 14
                    color: "#9CA3AF"
                    wrapMode: Text.WordWrap
                }

                // Дебетовая
                Rectangle {
                    id: debitCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    radius: 18

                    property bool selected: root.cardType === "debit"

                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: debitCard.selected ? Qt.lighter(Theme.grBlockPosStart, 1.25)
                                                     : Theme.grBlockPosStart
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        GradientStop {
                            position: 1.0
                            color: debitCard.selected ? Qt.lighter(Theme.grBlockPosEnd, 1.25)
                                                     : Theme.grBlockPosEnd
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    border.width: selected ? 2 : 1
                    border.color: selected ? Theme.accent : Theme.card
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Image {
                            source: "assets/debit-preview.svg"
                            sourceSize: Qt.size(40, 40)
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Дебетовая карта"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: "#F3F4F6"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Обслуживание 99 ₽ / мес."
                            font.pixelSize: 12
                            color: debitCard.selected ? Theme.accent : "#6B7280"
                            Layout.alignment: Qt.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    TapHandler { onTapped: root.cardType = "debit" }
                }

                // Кредитная
                Rectangle {
                    id: creditCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    radius: 18

                    property bool selected: root.cardType === "credit"

                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: creditCard.selected ? Qt.lighter(Theme.grBlockPosStart, 1.25)
                                                      : Theme.grBlockPosStart
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        GradientStop {
                            position: 1.0
                            color: creditCard.selected ? Qt.lighter(Theme.grBlockPosEnd, 1.25)
                                                      : Theme.grBlockPosEnd
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    border.width: selected ? 2 : 1
                    border.color: selected ? Theme.purpleLight : "#1F2937"
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Image {
                            source: "assets/credit-preview.svg"
                            sourceSize: Qt.size(40, 40)
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Кредитная карта"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: "#F3F4F6"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "Лимит 20 000 ₽"
                            font.pixelSize: 12
                            color: creditCard.selected ? "#C4B5FD" : "#6B7280"
                            Layout.alignment: Qt.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    TapHandler { onTapped: root.cardType = "credit" }
                }

                // Кнопка «Далее»
                Rectangle {
                    id: step1NextBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 14
                    color: root.cardType !== ""
                           ? (step1NextArea.pressed ? Theme.accent: Theme.accent)
                           : "#1F2937"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Далее"
                        font.pixelSize: 15; font.weight: Font.Bold
                        color: root.cardType !== "" ? "#042F2E" : "#4B5563"
                    }

                    MouseArea {
                        id: step1NextArea
                        anchors.fill: parent
                        enabled: root.cardType !== ""
                        onClicked: root.step = 2
                    }
                }
            }

            //  ШАГ 2 — Платёжная система
            ColumnLayout {
                id: brandsStep
                Layout.fillWidth: true
                spacing: 12
                visible: step === 2

                Text {
                    Layout.fillWidth: true
                    text: "Выберите платёжную систему для карты"
                    font.pixelSize: 14
                    color: "#9CA3AF"
                    wrapMode: Text.WordWrap
                    Layout.bottomMargin: 4
                }

                // Модель данных
                ListModel {
                    id: brandsModel
                    ListElement { key: "visa";       label: "Visa";       desc: "Принимается по всему миру";       accent: "#3B82F6"; icon: "assets/visa.svg" }
                    ListElement { key: "mastercard"; label: "Mastercard"; desc: "Надёжность и безопасность";        accent: "#EF4444"; icon: "assets/mastercard.svg" }
                    ListElement { key: "mir";        label: "МИР";       desc: "Российская платёжная система";     accent: "#10B981"; icon: "assets/mir.svg" }
                }

                Repeater {
                    model: brandsModel

                    delegate: Rectangle {
                        id: brandDelegate
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        radius: 16

                        required property int    index
                        required property string key
                        required property string label
                        required property string desc
                        required property string accent
                        required property string icon

                        property bool isCurrent: root.paySystem === key
                        property bool isHovered: brandHover.hovered

                        color: "#111827"
                        border.width: isCurrent ? 2 : 1
                        border.color: isCurrent ? accent
                                    : isHovered ? Qt.darker(accent, 1.4)
                                                : "#1F2937"

                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        // Подсвечивающий оверлей
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            color: brandDelegate.accent
                            opacity: brandDelegate.isCurrent ? 0.08
                                   : brandDelegate.isHovered ? 0.04 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16; anchors.rightMargin: 16
                            spacing: 14

                            // Логотип
                            Rectangle {
                                width: 56; height: 40; radius: 10
                                color: "#0B1120"
                                border.color: "#1F2937"; border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    width: 42; height: 28
                                    source: brandDelegate.icon
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true; smooth: true
                                }
                            }

                            // Тексты
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: brandDelegate.label
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    color: "#E5E7EB"
                                }
                                Text {
                                    text: brandDelegate.desc
                                    font.pixelSize: 11
                                    color: "#6B7280"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            // Радио-кнопка
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: "transparent"
                                border.width: 2
                                border.color: brandDelegate.isCurrent ? brandDelegate.accent : "#374151"

                                Behavior on border.color { ColorAnimation { duration: 160 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: brandDelegate.accent
                                    scale: brandDelegate.isCurrent ? 1.0 : 0.0
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                }
                            }
                        }

                        HoverHandler { id: brandHover }
                        TapHandler   { onTapped: root.paySystem = brandDelegate.key }
                    }
                }

                Item { Layout.preferredHeight: 6 }

                // Навигация
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52; radius: 14
                        color: step2BackArea.pressed ? "#374151" : "#1F2937"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text { anchors.centerIn: parent; text: "Назад"; font.pixelSize: 15; font.weight: Font.Bold; color: "#D1D5DB" }
                        MouseArea { id: step2BackArea; anchors.fill: parent; onClicked: root.step = 1 }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52; radius: 14
                        color: root.paySystem !== ""
                               ? (step2NextArea.pressed ? "#14B8A6" : "#2DD4BF")
                               : "#1F2937"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent; text: "Далее"
                            font.pixelSize: 15; font.weight: Font.Bold
                            color: root.paySystem !== "" ? "#042F2E" : "#4B5563"
                        }
                        MouseArea { id: step2NextArea; anchors.fill: parent; enabled: root.paySystem !== ""; onClicked: root.step = 3 }
                    }
                }
            }

            //  ШАГ 3 — Подтверждение
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: step === 3

                Text {
                    text: "Проверьте данные и подтвердите выпуск"
                    font.pixelSize: 14; color: "#9CA3AF"
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }

                // Превью банковской карты
                Rectangle {
                    id: cardPreview
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    radius: 20
                    layer.enabled: true

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: brandGradientStart(root.paySystem) }
                        GradientStop { position: 1.0; color: brandGradientEnd(root.paySystem) }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 0

                        // Логотип платёжной системы — верхний левый угол
                        Image {
                            source: root.paySystem === "visa"       ? "assets/visa.svg" :
                                    root.paySystem === "mastercard" ? "assets/mastercard.svg" :
                                                                      "assets/mir.svg"
                            sourceSize.height: 24
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.9
                        }

                        Item { Layout.fillHeight: true }

                        // Номер карты (скрытый)
                        Text {
                            text: "••••    ••••    ••••    ••••"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            font.letterSpacing: 2
                            color: "#FFFFFF"
                        }

                        Item { Layout.preferredHeight: 14 }

                        // Нижняя строка: имя + срок
                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2
                                Text { text: "ДЕРЖАТЕЛЬ"; font.pixelSize: 9; color: "#FFFFFF"; opacity: 0.5 }
                                Text {
                                    text: typeof userSession !== "undefined"
                                          ? userSession.shortName.toUpperCase()
                                          : "IVANOV A."
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"; opacity: 0.9
                                }
                            }

                            Item { Layout.fillWidth: true }

                            ColumnLayout {
                                spacing: 2
                                Layout.alignment: Qt.AlignRight
                                Text { text: "VALID THRU"; font.pixelSize: 9; color: "#FFFFFF"; opacity: 0.5; Layout.alignment: Qt.AlignRight }
                                Text {
                                    text: root.expiryPreview
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"; opacity: 0.9
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }
                    }
                }

                // ── Сводка (текстом) ──
                Rectangle {
                    id: summaryBlock
                    Layout.fillWidth: true
                    Layout.preferredHeight: infoCol.height + 28
                    radius: 14; color: "#111827"
                    border.color: "#1F2937"; border.width: 1

                    ColumnLayout {
                        id: infoCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                        spacing: 12

                        // Строка‑разделитель: повторяемый компонент
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Тип карты";        font.pixelSize: 13; color: Theme.textMuted}
                            Item { Layout.fillWidth: true }
                            Text { text: root.cardTypeLabel;  font.pixelSize: 13; font.weight: Font.Bold; color: "#E5E7EB" }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#1F2937" }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Платёжная система"; font.pixelSize: 13; color: Theme.textMuted}
                            Item { Layout.fillWidth: true }
                            Text { text: root.paySystemLabel; font.pixelSize: 13; font.weight: Font.Bold; color: "#E5E7EB" }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#1F2937" }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Срок действия";     font.pixelSize: 13; color: Theme.textMuted}
                            Item { Layout.fillWidth: true }
                            Text { text: "5 лет (" + root.expiryPreview + ")"; font.pixelSize: 13; font.weight: Font.Bold; color: "#E5E7EB" }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#1F2937" }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Обслуживание";      font.pixelSize: 13; color: Theme.textMuted}
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.cardType === "debit" ? "99 ₽ / мес." : "0 ₽"
                                font.pixelSize: 13; font.weight: Font.Bold; color: "#E5E7EB"
                            }
                        }
                    }
                }

                // ── Навигация ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52; radius: 14
                        color: step3BackArea.pressed ? "#374151" : "#1F2937"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text { anchors.centerIn: parent; text: "Назад"; font.pixelSize: 15; font.weight: Font.Bold; color: "#D1D5DB" }
                        MouseArea { id: step3BackArea; anchors.fill: parent; onClicked: root.step = 2 }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52; radius: 14
                        color: step3CreateArea.pressed ? "#14B8A6" : "#2DD4BF"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text { anchors.centerIn: parent; text: "Создать карту"; font.pixelSize: 15; font.weight: Font.Bold; color: "#042F2E" }
                        MouseArea {
                            id: step3CreateArea
                            anchors.fill: parent
                            onClicked: {
                                cardController.createCard(root.cardType, root.paySystem)
                            }
                        }
                    }
                }
            }

            //  ШАГ 4 — Успешное создание
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14
                visible: step === 4

                // Заголовок
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52; radius: 14
                    color: "#052E16"
                    border.color: "#166534"; border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Карта успешно выпущена!"
                        font.pixelSize: 15; font.weight: Font.Bold
                        color: "#4ADE80"
                    }
                }

                // Блок данных
                ColumnLayout {
                    id: credsBlock
                    Layout.fillWidth: true
                    spacing: 10

                    // Номер карты
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68; radius: 12;
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4
                            Text { text: "Номер карты"; font.pixelSize: 11; color: Theme.textMuted}
                            RowLayout {
                                Text {
                                    text: root.cardResult.cardNumber || "•••• •••• •••• ••••"
                                    font.pixelSize: 17; font.weight: Font.Bold
                                    color: "#F3F4F6"
                                }
                                Item { Layout.fillWidth: true }
                                Item {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18

                                    Image {
                                        id: copyNumIcon
                                        anchors.fill: parent
                                        source: "assets/copy.svg"
                                        sourceSize: Qt.size(18, 18)
                                        opacity: copyNumArea.pressed ? 0.5 : 1.0

                                        MouseArea {
                                            id: copyNumArea
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                cardController.copyToClipboard(root.cardResult.cardNumber || "")
                                                copyNumToast.show()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: copyNumToast
                                        anchors.right: parent.right
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: 4
                                        width: copyNumToastLabel.width + 16
                                        height: 24; radius: 8
                                        color: Theme.green
                                        opacity: 0
                                        visible: opacity > 0

                                        Text {
                                            id: copyNumToastLabel
                                            anchors.centerIn: parent
                                            text: "Скопировано"
                                            font.pixelSize: 11
                                            color: "#FFFFFF"
                                        }

                                        function show() {
                                            opacity = 1
                                            copyNumTimer.restart()
                                        }

                                        Timer {
                                            id: copyNumTimer
                                            interval: 1200
                                            onTriggered: copyNumToast.opacity = 0
                                        }

                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                        }
                    }

                    // Держатель
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68; radius: 12;
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4
                            Text { text: "Держатель карты"; font.pixelSize: 11; color: Theme.textMuted}
                            Text {
                                text: root.cardResult.cardHolder || ""
                                font.pixelSize: 15; font.weight: Font.Bold; color: "#F3F4F6"
                            }
                        }
                    }

                    // Срок действия + CVC
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 68; radius: 12;
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                                GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                            }
                            border.color: Theme.card

                            ColumnLayout {
                                anchors { fill: parent; margins: 12 }
                                spacing: 4
                                Text { text: "Срок действия"; font.pixelSize: 11; color: Theme.textMuted}
                                Text {
                                    text: root.cardResult.expiryDate || ""
                                    font.pixelSize: 15; font.weight: Font.Bold; color: "#F3F4F6"
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 68; radius: 12; 
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                                GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                            }
                            border.color: Theme.card

                            ColumnLayout {
                                anchors { fill: parent; margins: 12 }
                                spacing: 4
                                Text { text: "CVC-код"; font.pixelSize: 11; color: Theme.textMuted}
                                RowLayout {
                                    Text {
                                        text: root.cardResult.cvc || "***"
                                        font.pixelSize: 17; font.weight: Font.Bold; color: "#F3F4F6"
                                    }
                                    
                                    Item {
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18

                                        Image {
                                            id: copyCvcIcon
                                            anchors.fill: parent
                                            source: "assets/copy.svg"
                                            sourceSize: Qt.size(18, 18)
                                            opacity: copyCvcArea.pressed ? 0.5 : 1.0

                                            MouseArea {
                                                id: copyCvcArea
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    cardController.copyToClipboard(root.cardResult.cvc || "")
                                                    copyCvcToast.show()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: copyCvcToast
                                            anchors.right: parent.right
                                            anchors.bottom: parent.top
                                            anchors.bottomMargin: 4
                                            width: copyCvcToastLabel.width + 16
                                            height: 24; radius: 8
                                            color: Theme.green
                                            opacity: 0
                                            visible: opacity > 0

                                            Text {
                                                id: copyCvcToastLabel
                                                anchors.centerIn: parent
                                                text: "Скопировано"
                                                font.pixelSize: 11
                                                color: "#FFFFFF"
                                            }

                                            function show() {
                                                opacity = 1
                                                copyCvcTimer.restart()
                                            }

                                            Timer {
                                                id: copyCvcTimer
                                                interval: 1200
                                                onTriggered: copyCvcToast.opacity = 0
                                            }

                                            Behavior on opacity { NumberAnimation { duration: 200 } }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // PIN-код (акцентный блок)
                    Rectangle {
                        id: pinBlock
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76; radius: 12
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.grBlockPosStart }
                            GradientStop { position: 1.0; color: Theme.grBlockPosEnd }
                        }
                        border.color: Theme.card

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4
                            Text { text: "PIN-код  (запишите в надёжном месте!)"; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.textMuted }
                            RowLayout {
                                Text {
                                    text: root.cardResult.pin || "****"
                                    font.pixelSize: 22; font.weight: Font.Bold; color: "#FFFFFF"
                                }
                               
                                Item {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18

                                    Image {
                                        id: copyPinIcon
                                        anchors.fill: parent
                                        source: "assets/copy.svg"
                                        sourceSize: Qt.size(18, 18)
                                        opacity: copyPinArea.pressed ? 0.5 : 1.0

                                        MouseArea {
                                            id: copyPinArea
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                cardController.copyToClipboard(root.cardResult.pin || "")
                                                copyPinToast.show()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: copyPinToast
                                        anchors.right: parent.right
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: 4
                                        width: copyPinToastLabel.width + 16
                                        height: 24; radius: 8
                                        color: Theme.green
                                        opacity: 0
                                        visible: opacity > 0

                                        Text {
                                            id: copyPinToastLabel
                                            anchors.centerIn: parent
                                            text: "Скопировано"
                                            font.pixelSize: 11
                                            color: "#FFFFFF"
                                        }

                                        function show() {
                                            opacity = 1
                                            copyPinTimer.restart()
                                        }

                                        Timer {
                                            id: copyPinTimer
                                            interval: 1200
                                            onTriggered: copyPinToast.opacity = 0
                                        }

                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                        }
                    }
                }

                // Предупреждение
                Rectangle {
                    id: warningBlock
                    Layout.fillWidth: true
                    Layout.preferredHeight: warningRow.height + 24
                    radius: 12; color: "#450A0A"
                    border.color: "#7F1D1D"; border.width: 1

                    RowLayout {
                        id: warningRow
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 10

                        Image {
                            width: 28; height: 28
                            source: "assets/warning.svg"
                            sourceSize: Qt.size(28, 28)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Никому не сообщайте PIN-код и CVC-код карты. После закрытия этого экрана PIN-код будет недоступен."
                            font.pixelSize: 12; color: "#FCA5A5"
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Кнопка «Готово»
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52; radius: 14
                    color: Theme.accent
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text { anchors.centerIn: parent; text: "На главную"; font.pixelSize: 15; font.weight: Font.Bold; color: "#042F2E" }

                    MouseArea {
                        id: doneArea
                        anchors.fill: parent
                        onClicked: {
                            root.cardCreatedSuccess()
                            // Сброс
                            root.step       = 1
                            root.cardType   = ""
                            root.paySystem  = ""
                            root.cardResult = {}
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }  // нижний отступ
        }
    }

    //  Связь с контроллером
    Connections {
        target: cardController

        function onCardCreated(cardData) {
            console.log("Карта создана:", JSON.stringify(cardData))
            root.cardResult = cardData
            root.step = 4
        }

        function onCardCreationFailed(error) {
            console.error("Ошибка:", error)
        }

        function onCreationProgress(message) {
            console.log("wait..", message)
        }
    }
    GuideButton {
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 16
        z: 11
        onClicked: guide.open()
    }

    // ---------- Гид по экрану ----------
    GuideOverlay {
        id: guide
        guideId: "createCard"
        steps: step === 2 ? [
            { target: brandsStep, flickable: flick, title: "Платёжная система",
              text: "Visa, Mastercard или МИР — выберите, какой системой будет ваша карта. На условия обслуживания это не влияет." }
        ] : step === 3 ? [
            { target: cardPreview, flickable: flick, title: "Превью карты",
              text: "Так будет выглядеть ваша карта. Номер сгенерируется автоматически при выпуске." },
            { target: summaryBlock, flickable: flick, title: "Проверьте данные",
              text: "Сводка по выбранным параметрам. Если что-то не так — вернитесь назад и поменяйте." }
        ] : step === 4 ? [
            { target: credsBlock, flickable: flick, title: "Реквизиты карты",
              text: "Номер карты, срок действия, CVC и PIN. Коснитесь значка копирования, чтобы сохранить значение." },
            { target: warningBlock, flickable: flick, title: "Важно!",
              text: "PIN-код показывается только один раз — после закрытия этого экрана восстановить его будет нельзя. Сохраните его в надёжном месте." }
        ] : [
            { title: "Выпуск новой карты",
              text: "Мастер из нескольких шагов: тип карты, платёжная система, подтверждение — и карта готова. Индикатор сверху показывает прогресс." },
            { target: debitCard, flickable: flick, title: "Дебетовая карта",
              text: "Для повседневных трат: храните свои деньги и расплачивайтесь ими." },
            { target: creditCard, flickable: flick, title: "Кредитная карта",
              text: "Карта с кредитным лимитом банка." },
            { target: step1NextBtn, flickable: flick, title: "Дальше",
              text: "Выберите тип карты — и кнопка станет активной. Подсказка «?» доступна и на следующих шагах." }
        ]
    }
}
