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
    color: "#1a1a2e"
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
            onOpenCreateCard: {
                stackView.push(createCardComponent)
            }
            onOpenTransfer: {
                stackView.push(transferComponent)
            }
            onOpenHistory: {
                stackView.push(historyComponent)
            }
            onOpenCardDetail: function(cardData) {
                stackView.push(cardDetailComponent, { "cardData": cardData })
            }
            onOpenTopUp: {
                stackView.push(topUpComponent)
            }
            onOpenSettings: {
                stackView.push(settingsComponent)
            }
        }
    }

    // ============ Компонент создания карты ============
    Component {
        id: createCardComponent
        CreateCardDialog {
            onBackToMain: {
                stackView.pop()
            }
            onCardCreatedSuccess: {
                stackView.pop()
            }
        }
    }

    // ============ Компонент истории транзакций ============
    Component {
        id: historyComponent
        HistoryPage {
            onBackToMain: {
                stackView.pop()
            }
        }
    }

    // ============ Компонент переводов ============
    Component {
        id: transferComponent
        TransferPage {
            onBackToMain: {
                stackView.pop()
            }
        }
    }

    // ============ Детали карты ============
    Component {
        id: cardDetailComponent
        CardDetailPage {
            onBackToMain: {
                stackView.pop()
            }
            onOpenTopUp: function(accountId) {
                stackView.push(topUpComponent, { "preselectedAccountId": accountId })
            }
            onOpenPayOrTransfer: function(accountId) {
                stackView.push(transferComponent)
            }
        }
    }

    // ============ Пополнение ============
    Component {
        id: topUpComponent
        TopUpPage {
            onBackToMain: {
                stackView.pop()
            }
        }
    }

    // ============ Настройки ============
    Component {
        id: settingsComponent
        SettingsPage {
            onBackToMain: {
                stackView.pop()
            }
            onLoggedOut: {
                isUserLoggedIn = false
                stackView.replace(null, authComponent)
            }
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: isUserLoggedIn ? mainPageComponent : authComponent

        background: Rectangle {
            color: "#1a1a2e"
        }

        // ── Глобальные анимации push / pop / replace ──
        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "x"
                    from: stackView.width
                    to: 0
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }

        pushExit: Transition {
            NumberAnimation {
                property: "x"
                from: 0
                to: -stackView.width * 0.3
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        popEnter: Transition {
            NumberAnimation {
                property: "x"
                from: -stackView.width * 0.3
                to: 0
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        popExit: Transition {
            NumberAnimation {
                property: "x"
                from: 0
                to: stackView.width
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        replaceEnter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0; to: 1
                    duration: 350
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.92; to: 1.0
                    duration: 350
                    easing.type: Easing.OutCubic
                }
            }
        }

        replaceExit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 1; to: 0
                    duration: 350
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 1.0; to: 0.92
                    duration: 350
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
