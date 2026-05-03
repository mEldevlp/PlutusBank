import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlutusBank
import "."

Item {
    id: shell
    anchors.fill: parent

    property int activeTab: 0  // 0 — банк, 1 — крипто [cite: 60]

    // Сигналы наверх (Main.qml)
    signal loggedOut()

    onActiveTabChanged: {
        cryptoController.autoRefreshEnabled = (activeTab === 1)
        if (activeTab === 1) {
            cryptoController.loadCurrencies()
            cryptoController.loadWallets()
        }
    }

    Component.onCompleted: {
        cryptoController.autoRefreshEnabled = false
    }

    Component.onDestruction: {
        cryptoController.autoRefreshEnabled = false
    }

    // Фон приложения
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0A1229" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    // Зона контента
    Item {
        id: contentArea
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }

        StackLayout {
            id: tabStack
            anchors.fill: parent
            currentIndex: shell.activeTab

            // Вкладка 1: БАНК 
            StackView {
                id: bankStack
                clip: true
                initialItem: bankPageComponent

                // Анимации перехода
                pushEnter: Transition { NumberAnimation { property: "x"; from: bankStack.width; to: 0; duration: 300; easing.type: Easing.OutCubic } }
                pushExit:  Transition { NumberAnimation { property: "x"; from: 0; to: -bankStack.width * 0.3; duration: 300; easing.type: Easing.OutCubic } }
                popEnter:  Transition { NumberAnimation { property: "x"; from: -bankStack.width * 0.3; to: 0; duration: 300; easing.type: Easing.OutCubic } }
                popExit:   Transition { NumberAnimation { property: "x"; from: 0; to: bankStack.width; duration: 300; easing.type: Easing.OutCubic } } 

                Component {
                    id: bankPageComponent
                    MainPage {
                        onOpenCreateCard: bankStack.push(createCardComponent) 
                        onOpenTransfer:   bankStack.push(transferComponent) 
                        onOpenHistory:    bankStack.push(historyComponent)
                        onOpenCardDetail: (cardData) => bankStack.push(cardDetailComponent, { "cardData": cardData }) 
                        onOpenTopUp:      bankStack.push(topUpComponent)
                        onOpenSettings:   bankStack.push(settingsComponent)
                        onOpenLoan:       bankStack.push(loanCatalogComponent) 
                    }
                }

                Component {
                    id: createCardComponent
                    CreateCardDialog { 
                        onBackToMain: bankStack.pop()
                        onCardCreatedSuccess: bankStack.pop() 
                    }
                }

                Component { 
                    id: historyComponent
                    HistoryPage { onBackToMain: bankStack.pop() } 
                }

                Component { 
                    id: transferComponent
                    TransferPage { onBackToMain: bankStack.pop() } 
                }

                Component { 
                    id: cardDetailComponent
                    CardDetailPage {
                        onBackToMain: bankStack.pop()
                        onOpenTopUp: (accountId) => bankStack.push(topUpComponent, { "preselectedAccountId": accountId }) 
                        onOpenPayOrTransfer: (accountId) => bankStack.push(transferComponent) 
                    }
                }

                Component { 
                    id: topUpComponent
                    TopUpPage { onBackToMain: bankStack.pop() } 
                }

                Component {
                    id: settingsComponent
                    SettingsPage {
                        onBackToMain: bankStack.pop()
                        onLoggedOut: shell.loggedOut() 
                    }
                }

                Component {
                    id: loanCatalogComponent
                    LoanCatalogPage {
                        onBackToMain: bankStack.pop()
                        onOpenCalculator: (product) => bankStack.push(loanCalculatorComponent, { "product": product })
                        onOpenMyLoans: bankStack.push(myLoansComponent) 
                        onOpenLoanHistory: bankStack.push(loanHistoryComponent)
                    }
                }

                Component { 
                    id: loanHistoryComponent
                    LoanHistoryPage {
                        onBackToCatalog: bankStack.pop()
                        onOpenSchedule: (loanData) => bankStack.push(loanScheduleComponent, { "loanData": loanData }) 
                    }
                }

                Component { 
                    id: loanCalculatorComponent
                    LoanCalculatorPage {
                        onBackToCatalog: bankStack.pop() 
                        onGoToMyLoans: { 
                            bankStack.pop()
                            bankStack.push(myLoansComponent) 
                        }
                    }
                }

                Component { 
                    id: myLoansComponent
                    MyLoansPage {
                        onBackToCatalog: bankStack.pop()
                        onOpenSchedule: (loanData) => bankStack.push(loanScheduleComponent, { "loanData": loanData }) 
                    }
                }

                Component { 
                    id: loanScheduleComponent
                    LoanSchedulePage { onBackToLoans: bankStack.pop() } 
                }
            }

            // ============ Вкладка 2: КРИПТО ============
            StackView {
                id: cryptoStack
                clip: true
                initialItem: cryptoMainComponent 

                pushEnter: Transition { NumberAnimation { property: "x"; from: cryptoStack.width; to: 0; duration: 300; easing.type: Easing.OutCubic } } 
                pushExit:  Transition { NumberAnimation { property: "x"; from: 0; to: -cryptoStack.width * 0.3; duration: 300; easing.type: Easing.OutCubic } } 
                popEnter:  Transition { NumberAnimation { property: "x"; from: -cryptoStack.width * 0.3; to: 0; duration: 300; easing.type: Easing.OutCubic } } 
                popExit:   Transition { NumberAnimation { property: "x"; from: 0; to: cryptoStack.width; duration: 300; easing.type: Easing.OutCubic } } 

                Component {
                    id: cryptoMainComponent
                    CryptoMainPage {
                        onOpenBuy: (currency) => cryptoStack.push(cryptoBuyComponent, { "currency": currency }) 
                        onOpenSell: (currency, balance) => cryptoStack.push(cryptoSellComponent, { "currency": currency, "currentBalance": balance })
                        onOpenTransfer: (currency, balance) => cryptoStack.push(cryptoTransferComponent, { "currency": currency, "currentBalance": balance })
                        onOpenHistory: cryptoStack.push(cryptoHistoryComponent) 
                    }
                }

                Component { 
                    id: cryptoBuyComponent
                    CryptoBuyPage { onBackToMain: cryptoStack.pop() } 
                }

                Component { 
                    id: cryptoSellComponent
                    CryptoSellPage { onBackToMain: cryptoStack.pop() } 
                }

                Component { 
                    id: cryptoTransferComponent
                    CryptoTransferPage { onBackToMain: cryptoStack.pop() }
                }

                Component { 
                    id: cryptoHistoryComponent
                    CryptoHistoryPage { onBackToMain: cryptoStack.pop() } 
                }
            }
        }
    }

    // Нижняя панель вкладок
    BottomTabBar {
        id: bottomBar
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right 
        }
        currentIndex: shell.activeTab
        onTabClicked: (idx) => { shell.activeTab = idx } 
    }
}