import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "."

Window {
    id: mainWindow
    width: 400
    height: 800
    visible: true
    title: "PlutusBank"

    property bool isUserLoggedIn: false

    Component {
        id: authComponent
        Auth {
            onLoginSuccess: {
                console.log("Переход на главную страницу")
                isUserLoggedIn = true
                stackView.replace(mainPageComponent)
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
                stackView.replace(mainPageComponent)
            }
            onBackToLogin: {
                stackView.pop()
            }
        }
    }

    Component {
        id: mainPageComponent
        MainPage {
            // ============ ДОБАВЛЕНО: Переход к созданию карты ============
            onOpenCreateCard: {
                stackView.push(createCardComponent)
            }
            // =============================================================
        }
    }
    
    // ============ ДОБАВЛЕНО: Компонент создания карты ============
    Component {
        id: createCardComponent
        CreateCardDialog {
            onBackToMain: {
                stackView.pop()
            }
            onCardCreatedSuccess: {
                // После создания карты возвращаемся на главную
                stackView.pop()
            }
        }
    }
    // =============================================================

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: isUserLoggedIn ? mainPageComponent : authComponent
    }
}
