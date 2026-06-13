import QtQuick
import QtCore
import PlutusBank
import "."

/*
    GuideOverlay — переиспользуемый «гид» по экрану (coach marks / spotlight tour).

    Использование на странице:

        GuideOverlay {
            id: guide
            steps: [
                { title: "Добро пожаловать", text: "Краткий обзор экрана." },        // шаг без цели — по центру
                { target: balanceBlock, flickable: flick,
                  title: "Баланс", text: "Здесь общий баланс по всем счетам." }
            ]
            guideId: "mainPage"   // ключ для автопоказа «один раз»
            autoShow: true        // показать автоматически при первом входе
        }

        GuideButton { onClicked: guide.open() }   // кнопка «?» в шапке

    Поля шага:
        target    : Item      — подсвечиваемый элемент (нет — подсказка по центру)
        title     : string    — заголовок подсказки
        text      : string    — описание
        flickable : Flickable — если цель внутри прокрутки, гид сам доскроллит
        padding   : real      — отступ «прожектора» вокруг цели (по умолч. 8)
        radius    : real      — скругление «прожектора» (по умолч. 16)
*/

Item {
    id: root
    anchors.fill: parent
    z: 999
    visible: active || dimOpacity > 0.01

    // ---------- Публичный API ----------
    property var steps: []
    property string guideId: ""
    property bool autoShow: false
    property bool active: false
    property int currentIndex: 0

    signal opened()
    signal closed()
    signal finished()   // прошёл все шаги до конца

    function open()
    {
        if (steps.length === 0)
            return
        currentIndex = 0
        active = true
        markSeen()
        opened()
        Qt.callLater(showCurrentStep)
    }

    function close()
    {
        active = false
        closed()
    }

    function next()
    {
        if (currentIndex < steps.length - 1)
        {
            currentIndex++
            showCurrentStep()
        }
        else
        {
            finished()
            close()
        }
    }

    function back()
    {
        if (currentIndex > 0)
        {
            currentIndex--
            showCurrentStep()
        }
    }

    // ---------- Внутреннее состояние ----------
    property real dimOpacity: active ? 1.0 : 0.0
    Behavior on dimOpacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    property bool hasHole: false
    property real holeX: 0
    property real holeY: 0
    property real holeW: 0
    property real holeH: 0
    property real holeR: 16

    Behavior on holeX { enabled: root.active; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on holeY { enabled: root.active; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on holeW { enabled: root.active; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on holeH { enabled: root.active; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    onHoleXChanged: scrim.requestPaint()
    onHoleYChanged: scrim.requestPaint()
    onHoleWChanged: scrim.requestPaint()
    onHoleHChanged: scrim.requestPaint()
    onHasHoleChanged: scrim.requestPaint()
    onDimOpacityChanged: scrim.requestPaint()
    onWidthChanged: if (active) Qt.callLater(measure)
    onHeightChanged: if (active) Qt.callLater(measure)

    FontLoader { id: guideFont; source: "assets/fonts/Manrope-Bold.ttf" }

    // Автопоказ «один раз» (флаг хранится в настройках приложения)
    Settings { id: guideStore; category: "Guides" }

    function markSeen()
    {
        if (guideId.length > 0)
            guideStore.setValue("seen_" + guideId, true)
    }

    Timer {
        id: autoShowTimer
        interval: 700
        repeat: false
        onTriggered: root.open()
    }

    Component.onCompleted: {
        if (autoShow && guideId.length > 0
                && !guideStore.value("seen_" + guideId, false))
            autoShowTimer.start()
    }

    // ---------- Подготовка шага ----------
    function showCurrentStep()
    {
        var s = steps[currentIndex]
        if (!s)
            return
        // Если цель внутри Flickable — доскроллить так, чтобы её было видно
        if (s.flickable && s.target)
        {
            var f = s.flickable
            var pos = s.target.mapToItem(f.contentItem, 0, 0)
            var pad = 28
            var reserve = 170   // запас под карточку подсказки
            var desired = f.contentY
            if (pos.y - pad < f.contentY)
                desired = Math.max(0, pos.y - pad)
            else if (pos.y + s.target.height + reserve > f.contentY + f.height)
                desired = Math.min(Math.max(0, f.contentHeight - f.height),
                                   pos.y + s.target.height + reserve - f.height)
            if (Math.abs(desired - f.contentY) > 1)
                f.contentY = desired
        }
        Qt.callLater(measure)
    }

    function measure()
    {
        var s = steps[currentIndex]
        if (!s || !s.target || !s.target.visible)
        {
            hasHole = false
            return
        }
        var p = (s.padding !== undefined) ? s.padding : 8
        var pos = s.target.mapToItem(root, 0, 0)
        holeR = (s.radius !== undefined) ? s.radius : 16
        holeX = pos.x - p
        holeY = pos.y - p
        holeW = s.target.width + 2 * p
        holeH = s.target.height + 2 * p
        hasHole = true
    }

    // ---------- Затемнение с «прожектором» ----------
    Canvas {
        id: scrim
        anchors.fill: parent
        opacity: root.dimOpacity

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = "rgba(3, 7, 18, 0.82)"
            ctx.fillRect(0, 0, width, height)

            if (root.hasHole)
            {
                ctx.globalCompositeOperation = "destination-out"
                roundRect(ctx, root.holeX, root.holeY, root.holeW, root.holeH, root.holeR)
                ctx.fill()
                ctx.globalCompositeOperation = "source-over"
            }
        }

        function roundRect(ctx, x, y, w, h, r)
        {
            r = Math.min(r, w / 2, h / 2)
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.arcTo(x + w, y,     x + w, y + h, r)
            ctx.arcTo(x + w, y + h, x,     y + h, r)
            ctx.arcTo(x,     y + h, x,     y,     r)
            ctx.arcTo(x,     y,     x + w, y,     r)
            ctx.closePath()
        }
    }

    // Пульсирующая рамка вокруг подсвеченного элемента
    Rectangle {
        id: pulse
        visible: root.active && root.hasHole
        x: root.holeX - 3
        y: root.holeY - 3
        width: root.holeW + 6
        height: root.holeH + 6
        radius: root.holeR + 3
        color: "transparent"
        border.color: Theme.accent
        border.width: 2
        opacity: 0.9

        SequentialAnimation on opacity {
            running: pulse.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.9; to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.35; to: 0.9; duration: 900; easing.type: Easing.InOutQuad }
        }
    }

    // Тап по затемнению — следующий шаг (стандартный паттерн онбординга)
    MouseArea {
        anchors.fill: parent
        enabled: root.active
        onClicked: root.next()
    }

    // ---------- Карточка подсказки ----------
    Item {
        id: tipWrap
        width: tip.width
        height: tip.height
        opacity: root.dimOpacity

        x: {
            if (!root.hasHole)
                return (root.width - width) / 2
            var cx = root.holeX + root.holeW / 2 - width / 2
            return Math.max(16, Math.min(cx, root.width - width - 16))
        }
        y: {
            if (!root.hasHole)
                return (root.height - height) / 2
            var below = root.holeY + root.holeH + 18
            if (below + height + 16 <= root.height)
                return below
            return Math.max(16, root.holeY - height - 18)
        }

        Behavior on x { enabled: root.active; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: root.active; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        property bool below: root.hasHole && y > root.holeY

        // Стрелка-указатель на элемент
        Rectangle {
            visible: root.hasHole
            width: 14; height: 14
            rotation: 45
            color: Theme.surface
            border.color: Theme.cardBorder
            x: {
                var holeCenter = root.holeX + root.holeW / 2 - tipWrap.x - width / 2
                return Math.max(18, Math.min(holeCenter, tipWrap.width - 32))
            }
            y: tipWrap.below ? -7 : tipWrap.height - 7
        }

        Rectangle {
            id: tip
            width: Math.min(root.width - 32, 320)
            height: tipCol.height + 36
            radius: 18
            color: Theme.surface
            border.color: Theme.cardBorder
            border.width: 1

            // Глотаем клики по карточке, чтобы тап не листал шаг
            MouseArea { anchors.fill: parent }

            // Кнопка закрытия (пропустить обучение)
            Rectangle {
                width: 28; height: 28; radius: 14
                color: closeArea.pressed ? Theme.cardLight : "transparent"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8

                Text {
                    anchors.centerIn: parent
                    text: "\u2715"
                    font.pixelSize: 12
                    color: Theme.textMuted
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            Column {
                id: tipCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 18
                spacing: 10

                Text {
                    width: parent.width - 26
                    text: {
                        var s = root.steps[root.currentIndex]
                        return s && s.title ? s.title : ""
                    }
                    font { pixelSize: 16; bold: true; family: guideFont.name }
                    color: Theme.textPrimary
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: {
                        var s = root.steps[root.currentIndex]
                        return s && s.text ? s.text : ""
                    }
                    font.pixelSize: 13
                    lineHeight: 1.25
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                }

                Item { width: 1; height: 2 }

                // Нижний ряд: точки прогресса + навигация
                Item {
                    width: parent.width
                    height: 34

                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: root.steps.length
                            Rectangle {
                                width: index === root.currentIndex ? 16 : 6
                                height: 6
                                radius: 3
                                color: index === root.currentIndex ? Theme.accent : Theme.cardBorder
                                Behavior on width { NumberAnimation { duration: 180 } }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Row {
                        spacing: 8
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        // Назад
                        Rectangle {
                            width: 64; height: 34; radius: 17
                            visible: root.currentIndex > 0
                            color: backArea2.pressed ? Theme.cardLight : Theme.card
                            border.color: Theme.cardBorder

                            Text {
                                anchors.centerIn: parent
                                text: "Назад"
                                font.pixelSize: 12
                                color: Theme.textSecondary
                            }
                            MouseArea {
                                id: backArea2
                                anchors.fill: parent
                                onClicked: root.back()
                            }
                        }

                        // Далее / Готово
                        Rectangle {
                            width: 72; height: 34; radius: 17
                            color: nextArea.pressed ? Theme.accentDark : Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: root.currentIndex === root.steps.length - 1
                                      ? "Готово" : "Далее"
                                font { pixelSize: 12; bold: true }
                                color: Theme.backgroundDeep
                            }
                            MouseArea {
                                id: nextArea
                                anchors.fill: parent
                                onClicked: root.next()
                            }
                        }
                    }
                }
            }
        }
    }
}
