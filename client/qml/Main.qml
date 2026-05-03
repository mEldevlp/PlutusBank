import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "."

Window {
    id: mainWindow
    width: 350
    height: 600
    visible: true
    title: "PlutusBank"
    color: "#1a1a2e"
    property bool isUserLoggedIn: false

    Component {
        id: authComponent
        Auth {
            onLoginSuccess: {
                console.log("Переход на главную страницу")
                isUserLoggedIn = true
                stackView.replace(mainShellComponent)
            }
            onSwitchToRegister: {
                stackView.push(registerComponent)
            }
        }
    }

    Component {
        id: registerComponent
        Register {
            onRegisterSuccess: {
                console.log("Регистрация успешна, вход выполнен")
                isUserLoggedIn = true
                stackView.replace(mainShellComponent)
            }
            onBackToLogin: {
                stackView.pop()
            }
        }
    }

    // Корневой контейнер с табами «Банк / Крипто» снизу.
    // Внутренние стеки навигации находятся в самом MainShell.
    Component {
        id: mainShellComponent
        MainShell {
            onLoggedOut: {
                isUserLoggedIn = false
                stackView.replace(null, authComponent)
            }
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: isUserLoggedIn ? mainShellComponent : authComponent

        background: Rectangle {
            color: "#1a1a2e"
        }

        // ── Глобальные анимации push / pop / replace ──
        pushEnter: Transition {
            NumberAnimation {
                property: "x"
                from: stackView.width; to: 0
                duration: 300; easing.type: Easing.OutCubic
            }
        }
        pushExit: Transition {
            NumberAnimation {
                property: "x"
                from: 0; to: -stackView.width * 0.3
                duration: 300; easing.type: Easing.OutCubic
            }
        }
        popEnter: Transition {
            NumberAnimation {
                property: "x"
                from: -stackView.width * 0.3; to: 0
                duration: 300; easing.type: Easing.OutCubic
            }
        }
        popExit: Transition {
            NumberAnimation {
                property: "x"
                from: 0; to: stackView.width
                duration: 300; easing.type: Easing.OutCubic
            }
        }
        replaceEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale";   from: 0.92; to: 1.0; duration: 350; easing.type: Easing.OutCubic }
            }
        }
        replaceExit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0;   duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale";   from: 1.0; to: 0.92; duration: 350; easing.type: Easing.OutCubic }
            }
        }
    }
}
