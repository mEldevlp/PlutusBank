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

# Source Files (*.cpp)
set(SOURCE_FILES
    src/main.cpp
    src/DatabaseManager.cpp
    src/AuthController.cpp
)

# Header Files (*.h)
set(HEADER_FILES
    src/DatabaseManager.h
    src/AuthController.h
)

# QML Files - UI
set(QML_UI_FILES
    qml/Main.qml
    qml/Auth.qml
    qml/Register.qml
    qml/MainPage.qml
)

# QML Resources - Assets
set(QML_ASSET_FILES
    qml/assets/logo.png
    qml/assets/fonts/Manrope-Bold.ttf
)

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

# QML модуль
qt_add_qml_module(${PROJECT_NAME}
    URI PlutusBank
    VERSION 1.0
    QML_FILES ${QML_UI_FILES}
    RESOURCES ${QML_ASSET_FILES}
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
                --qmldir "${CMAKE_SOURCE_DIR}/qml"
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

set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT PlutusBank)

# Включаем папки
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Отложенная установка папок (выполняется в конце генерации)
cmake_language(DEFER CALL _organize_targets)

function(_organize_targets)
    message(STATUS "Организация проектов в папки...")
    
    # Функция для безопасной установки папки
    function(set_folder target_name folder_name)
        if(TARGET ${target_name})
            set_target_properties(${target_name} PROPERTIES FOLDER "${folder_name}")
            message(STATUS "  ${target_name} → ${folder_name}")
        endif()
    endfunction()
    
    # CMake служебные
    set_folder(ALL_BUILD "CMakePredefinedTargets")
    set_folder(ZERO_CHECK "CMakePredefinedTargets")
    
    # Qt автогенерация → Generated
    set_folder(${PROJECT_NAME}_autogen "Generated")
    set_folder(${PROJECT_NAME}_automoc_json_extraction "Generated")
    set_folder(${PROJECT_NAME}_qmltyperegistration "Generated")
    set_folder(${PROJECT_NAME}_qmlimportscan "Generated")
    set_folder(${PROJECT_NAME}_copy_qml "Generated")
    set_folder(${PROJECT_NAME}_copy_res "Generated")
    
    # QML Lint → Generated/QMLLint
    set_folder(${PROJECT_NAME}_qmllint "Generated/QMLLint")
    set_folder(${PROJECT_NAME}_qmllint_json "Generated/QMLLint")
    set_folder(${PROJECT_NAME}_qmllint_module "Generated/QMLLint")
    set_folder(all_qmllint "Generated/QMLLint")
    set_folder(all_qmllint_json "Generated/QMLLint")
    set_folder(all_qmllint_module "Generated/QMLLint")
    
    # AOT → Generated/AOT
    set_folder(module_${PROJECT_NAME}_aotstats_target "Generated/AOT")
    set_folder(all_aotstats "Generated/AOT")
    
    # Прочие инструменты → Generated/Tools
    set_folder(generate_qmlls_build_ini_file "Generated/Tools")
    set_folder(all_qmltyperegistrations "Generated/Tools")
    
    message(STATUS "Организация завершена")
endfunction()


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
