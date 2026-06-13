cmake_minimum_required(VERSION 3.21)

project(Client VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
if(COMMAND qt_policy)
    qt_policy(SET QTP0001 NEW)
    qt_policy(SET QTP0002 NEW)
    qt_policy(SET QTP0004 NEW)
endif()

if(ANDROID)
	if(NOT DEFINED QT_HOST_PATH)
		message(FATAL_ERROR "QT_HOST_PATH must be set for Android builds")
	endif()
	if(NOT DEFINED ANDROID_SDK_ROOT)
		message(FATAL_ERROR "ANDROID_SDK_ROOT must be set for Android builds")
	endif()
	message(STATUS "Android SDK: ${ANDROID_SDK_ROOT}")
	message(STATUS "Android NDK: ${ANDROID_NDK}")
endif()

# Поиск Qt6
find_package(Qt6 REQUIRED COMPONENTS
	Core
	Gui
	Widgets
	Network
	Quick
	QuickControls2
	Svg
)

# OpenSSL
if(NOT ANDROID)
    find_package(OpenSSL)
    if(OpenSSL_FOUND)
        message(STATUS "OpenSSL найден: ${OPENSSL_VERSION}")
    else()
        message(WARNING "OpenSSL не найден")
    endif()
endif()

# Source Files
set(SOURCE_FILES
	src/main.cpp
	src/NetworkClient.cpp
	src/AuthController.cpp
	src/UserSession.cpp
	src/CardController.cpp
	src/TransferController.cpp
	src/HistoryController.cpp
	src/LoanController.cpp
	src/CryptoController.cpp
    src/DepositController.cpp
)

# Header Files
set(HEADER_FILES
	src/NetworkClient.h
	src/AuthController.h
	src/UserSession.h
	src/CardController.h
	src/TransferController.h
	src/HistoryController.h
	src/LoanController.h
	src/CryptoController.h
	src/DepositController.h
	
	../shared/NetworkProtocol.h
)

# QML Files - UI
set(QML_UI_FILES
	qml/Auth.qml
	qml/BottomTabBar.qml
	qml/CardDetailPage.qml
	qml/CreateCardDialog.qml
	qml/CryptoBuyPage.qml
	qml/CryptoCoinDetailPage.qml
	qml/CryptoHistoryPage.qml
	qml/CryptoMainPage.qml
	qml/CryptoSellPage.qml
	qml/CryptoTransferPage.qml
	qml/HistoryPage.qml
	qml/LoanCatalogPage.qml
	qml/LoanCalculatorPage.qml
	qml/LoanSchedulePage.qml
	qml/LoanHistoryPage.qml
	qml/Main.qml
	qml/MainPage.qml
	qml/MainShell.qml
	qml/MyLoansPage.qml
	qml/Register.qml
	qml/SettingsPage.qml
	qml/Theme.qml  
	qml/TransferPage.qml
	qml/TopUpPage.qml
	qml/DepositMainPage.qml
    qml/DepositOpenPage.qml
    qml/SavingsAccountPage.qml
    qml/DepositDetailPage.qml
    qml/DepositHistoryPage.qml
	qml/GuideOverlay.qml
	qml/GuideButton.qml
)

# QML Resources - Assets
file(GLOB_RECURSE QML_ASSET_FILES
    CONFIGURE_DEPENDS
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    "qml/assets/*.svg"
    "qml/assets/*.png"
    "qml/assets/*.jpg"
    "qml/assets/fonts/*.ttf"
    "qml/assets/fonts/*.otf"
)

message(STATUS "Found ${CMAKE_CURRENT_SOURCE_DIR}/qml/assets:")
foreach(asset ${QML_ASSET_FILES})
    message(STATUS "  ${asset}")
endforeach()

# Объединяем все исходники
set(SOURCES
    ${SOURCE_FILES}
    ${HEADER_FILES}
)

# Windows Resource File
if(WIN32)
    set(APP_ICON_RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/resources/app.rc")
    list(APPEND SOURCES ${APP_ICON_RESOURCE})
endif()

source_group("Source Files" FILES ${SOURCE_FILES})

source_group("Header Files" FILES ${HEADER_FILES})

source_group("QML\\UI" FILES ${QML_UI_FILES})

source_group("QML\\Assets" FILES ${QML_ASSET_FILES})

if(WIN32)
    source_group("Resources" FILES ${APP_ICON_RESOURCE})
endif()

# Группа "Generated" для автогенерированных файлов
source_group("Generated" REGULAR_EXPRESSION ".*moc_.*|.*qrc_.*|.*ui_.*")

# Создание приложения
qt_add_executable(${PROJECT_NAME} ${SOURCES})

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# QML модуль
qt_add_qml_module(${PROJECT_NAME}
    URI PlutusBank
    VERSION 1.0
    QML_FILES ${QML_UI_FILES}
    RESOURCES ${QML_ASSET_FILES}
    RESOURCE_PREFIX /qt/qml
)

qt_add_resources(${PROJECT_NAME} "config_files"
    PREFIX "/"
    FILES connection.ini
)

# Версионирование
execute_process(
    COMMAND git rev-list --count HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE BUILD_NUMBER
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(NOT BUILD_NUMBER)
    set(BUILD_NUMBER 0)
endif()

set(APP_VERSION_FULL "${PROJECT_VERSION}.${BUILD_NUMBER}")

math(EXPR VERSION_CODE
    "${PROJECT_VERSION_MAJOR} * 1000000 + \
     ${PROJECT_VERSION_MINOR} * 10000 + \
     ${PROJECT_VERSION_PATCH} * 100 + \
     ${BUILD_NUMBER}"
)

# Android настройки
if(ANDROID)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_MIN_SDK_VERSION 34
        QT_ANDROID_TARGET_SDK_VERSION 36
        QT_ANDROID_VERSION_CODE ${VERSION_CODE}
        QT_ANDROID_VERSION_NAME "${APP_VERSION_FULL}"
    )
endif()

# Линковка Qt
target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Network
    Qt6::Quick
    Qt6::QuickControls2
	Qt6::Svg
)

# OpenSSL
if(OpenSSL_FOUND AND NOT ANDROID)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        OpenSSL::SSL
        OpenSSL::Crypto
    )
    target_compile_definitions(${PROJECT_NAME} PRIVATE HAS_OPENSSL)
endif()

# Заголовки
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Определения
target_compile_definitions(${PROJECT_NAME} PRIVATE
    QT_QML_DEBUG
    APP_VERSION="${APP_VERSION_FULL}"
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
    APP_VERSION="${APP_VERSION_FULL}"
    APP_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
    APP_VERSION_MINOR=${PROJECT_VERSION_MINOR}
    APP_VERSION_PATCH=${PROJECT_VERSION_PATCH}
    APP_BUILD_NUMBER=${BUILD_NUMBER}
)

# Копирование QML и ресурсов в папку сборки (Debug/Release)
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/qml"
        "$<TARGET_FILE_DIR:${PROJECT_NAME}>/qml"
    COMMENT "Copying QML files to build directory..."
)

# Windows deployment
if(WIN32 AND NOT ANDROID)
    get_target_property(_qmake_executable Qt6::qmake IMPORTED_LOCATION)
    get_filename_component(_qt_bin_dir "${_qmake_executable}" DIRECTORY)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")
    
    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND "${WINDEPLOYQT_EXECUTABLE}"
                --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/qml"
                --no-translations
                "$<TARGET_FILE:${PROJECT_NAME}>"
            COMMENT "Deploying Qt libraries..."
        )
    endif()
endif()

# Копирование ВСЕХ DLL из PostgreSQL/bin
if(WIN32 AND NOT ANDROID)
    set(POSTGRES_BIN_DIR "C:/Program Files/PostgreSQL/18/bin")
    
    if(EXISTS "${POSTGRES_BIN_DIR}")
        file(GLOB POSTGRES_DLLS "${POSTGRES_BIN_DIR}/*.dll")
        
        foreach(DLL ${POSTGRES_DLLS})
            add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${DLL}"
                    "$<TARGET_FILE_DIR:${PROJECT_NAME}>"
            )
        endforeach()
        
        message(STATUS "Будут скопированы все DLL из PostgreSQL 18")
    endif()
endif()

# Финализация
qt_finalize_target(${PROJECT_NAME})

if(TARGET ${PROJECT_NAME}_autogen)
    set_target_properties(${PROJECT_NAME}_autogen PROPERTIES FOLDER "_Infrastructure/Generated")
endif()

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/connection.ini"
        "$<TARGET_FILE_DIR:${PROJECT_NAME}>/connection.ini"
)

# Информация
message(STATUS "")
message(STATUS "=== Client Configuration ===")
message(STATUS "Version: ${PROJECT_VERSION}")
message(STATUS "Qt: ${Qt6_VERSION}")
message(STATUS "Build: ${CMAKE_BUILD_TYPE}")
if(ANDROID)
    message(STATUS "Target: Android ${ANDROID_ABI}")
    message(STATUS "Min SDK: 28 (Android 9.0)")
    message(STATUS "Target SDK: 34 (Android 14)")
else()
    message(STATUS "Target: Windows")
endif()
message(STATUS "=================================")
message(STATUS "")
