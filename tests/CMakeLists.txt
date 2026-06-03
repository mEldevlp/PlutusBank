cmake_minimum_required(VERSION 3.21)

project(PlutusBankTests
    VERSION 1.0.0
    DESCRIPTION "End-to-end тесты PlutusBank: клиент → сервер → БД"
    LANGUAGES CXX)

# ------------------------------------------------------------------
# Стандарт C++
# ------------------------------------------------------------------
set(CMAKE_CXX_STANDARD          17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS        OFF)

# ------------------------------------------------------------------
# Qt
# ------------------------------------------------------------------
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Network)

# ------------------------------------------------------------------
# Путь к общему заголовку NetworkProtocol.h
# По умолчанию ожидаем, что эта папка лежит рядом с client/, server/, shared/
#   <project_root>/tests/   (этот проект)
#   <project_root>/shared/  (NetworkProtocol.h)
# Переопределить путь можно через -DPLUTUSBANK_SHARED_DIR=...
# ------------------------------------------------------------------
set(PLUTUSBANK_SHARED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../shared"
    CACHE PATH "Путь к каталогу shared/ исходного проекта PlutusBank")

if(NOT EXISTS "${PLUTUSBANK_SHARED_DIR}/NetworkProtocol.h")
    message(FATAL_ERROR
        "\n"
        "Не найден файл NetworkProtocol.h по пути:\n"
        "    ${PLUTUSBANK_SHARED_DIR}/NetworkProtocol.h\n"
        "\n"
        "Передайте корректный путь через -DPLUTUSBANK_SHARED_DIR=<...>"
        " или положите каталог tests/ рядом с shared/.")
endif()

# ------------------------------------------------------------------
# Исполняемый файл
# ------------------------------------------------------------------
add_executable(PlutusBankTests
    src/main.cpp
    src/Console.cpp
    src/Console.h
    src/TestClient.cpp
    src/TestClient.h
    src/TestRunner.cpp
    src/TestRunner.h
)

target_include_directories(PlutusBankTests PRIVATE
    src
    ${PLUTUSBANK_SHARED_DIR}
)

target_link_libraries(PlutusBankTests PRIVATE
    Qt6::Core
    Qt6::Network
)

# Консольное приложение, не WIN32-GUI
set_target_properties(PlutusBankTests PROPERTIES
    WIN32_EXECUTABLE OFF
    FOLDER "Tests"
)

# UTF-8 в исходниках под MSVC + отключение шумных предупреждений
if(MSVC)
    target_compile_options(PlutusBankTests PRIVATE /utf-8 /W4)
    target_compile_definitions(PlutusBankTests PRIVATE
        _CRT_SECURE_NO_WARNINGS
        NOMINMAX
        WIN32_LEAN_AND_MEAN
    )
else()
    target_compile_options(PlutusBankTests PRIVATE -Wall -Wextra)
endif()

# ------------------------------------------------------------------
# Регистрация в CTest (опционально: ctest -V из директории сборки)
# ------------------------------------------------------------------
include(CTest)
if(BUILD_TESTING)
    add_test(NAME PlutusBankTests
             COMMAND PlutusBankTests
             WORKING_DIRECTORY $<TARGET_FILE_DIR:PlutusBankTests>)
endif()

# ------------------------------------------------------------------
# Сводка
# ------------------------------------------------------------------
message(STATUS "")
message(STATUS "=== PlutusBank Tests ===")
message(STATUS "  shared dir : ${PLUTUSBANK_SHARED_DIR}")
message(STATUS "  Qt6        : ${Qt6_VERSION}")
message(STATUS "  build type : ${CMAKE_BUILD_TYPE}")
message(STATUS "========================")
message(STATUS "")
