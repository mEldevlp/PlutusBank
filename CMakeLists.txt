cmake_minimum_required(VERSION 3.21)

project(PlutusBank VERSION 1.0.0 LANGUAGES CXX)

# C++ стандарт
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt настройки
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Qt policies для QML
if(COMMAND qt_policy)
    qt_policy(SET QTP0001 NEW)
    qt_policy(SET QTP0002 NEW)
    qt_policy(SET QTP0004 NEW)
endif()

# Для Android
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
    Sql
    Quick
    QuickControls2
)

# OpenSSL - опционально
if(NOT ANDROID)
    find_package(OpenSSL)
    if(OpenSSL_FOUND)
        message(STATUS "OpenSSL найден: ${OPENSSL_VERSION}")
    else()
        message(WARNING "OpenSSL не найден")
    endif()
endif()

# Исходники
set(SOURCES
    src/main.cpp
)

if(WIN32)
    set(APP_ICON_RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/resources/app.rc")
    list(APPEND SOURCES ${APP_ICON_RESOURCE})
endif()

# QML файлы
set(QML_FILES
    qml/Main.qml
)

# Ресурсы
set(QML_RESOURCES
    qml/assets/logo.png
	qml/assets/fonts/Manrope-Bold.ttf
)

# Создание приложения
qt_add_executable(${PROJECT_NAME} ${SOURCES})

# QML модуль
qt_add_qml_module(${PROJECT_NAME}
    URI PlutusBank
    VERSION 1.0
    QML_FILES ${QML_FILES}
    RESOURCES ${QML_RESOURCES}
    RESOURCE_PREFIX /qt/qml
)

# Android настройки
if(ANDROID)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 34
    )
endif()

# Линковка Qt
target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Network
    Qt6::Sql
    Qt6::Quick
    Qt6::QuickControls2
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
    APP_VERSION="${PROJECT_VERSION}"
)

# Windows deployment
if(WIN32 AND NOT ANDROID)
    get_target_property(_qmake_executable Qt6::qmake IMPORTED_LOCATION)
    get_filename_component(_qt_bin_dir "${_qmake_executable}" DIRECTORY)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")
    
    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND "${WINDEPLOYQT_EXECUTABLE}"
                --qmldir "${CMAKE_SOURCE_DIR}/qml"
                --no-translations
                "$<TARGET_FILE:${PROJECT_NAME}>"
            COMMENT "Deploying Qt libraries..."
        )
    endif()
endif()

# Папка с QML в исходниках
set(QML_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/qml")

# Папка назначения рядом с бинарником (Debug/Release и т.д.)
set(QML_OUTPUT_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/qml")

# Копировать все .qml (и при необходимости .js, .qmltypes и т.п.)
file(GLOB_RECURSE QML_SOURCE_FILES
    "${QML_SOURCE_DIR}/*.qml"
    "${QML_SOURCE_DIR}/*.js"
    "${QML_SOURCE_DIR}/*.qmltypes"
)

# Папка с QML в исходниках
set(QML_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/qml")

# Папка назначения рядом с бинарником (Debug/Release и т.д.)
set(QML_OUTPUT_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/qml")

# Копировать все .qml (и при необходимости .js, .qmltypes и т.п.)
file(GLOB_RECURSE QML_SOURCE_FILES
    "${QML_SOURCE_DIR}/*.qml"
    "${QML_SOURCE_DIR}/*.js"
    "${QML_SOURCE_DIR}/*.qmltypes"
)

add_custom_target(copy_qml ALL
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${QML_OUTPUT_DIR}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            ${QML_SOURCE_FILES}
            "${QML_OUTPUT_DIR}"
    DEPENDS ${QML_SOURCE_FILES}
    COMMENT "Copying QML files to ${QML_OUTPUT_DIR}"
)

add_dependencies(${PROJECT_NAME} copy_qml)

# Финализация
qt_finalize_target(${PROJECT_NAME})

# Информация
message(STATUS "")
message(STATUS "=== PlutusBank Configuration ===")
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
