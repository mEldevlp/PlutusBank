cmake_minimum_required(VERSION 3.21)

project(Server VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Qt6
find_package(Qt6 REQUIRED COMPONENTS Core Network Sql)

# OpenSSLs
find_package(OpenSSL)
if(OpenSSL_FOUND)
    message(STATUS "OpenSSL найден: ${OPENSSL_VERSION}")
endif()

set(SOURCES
    src/main.cpp
    src/DatabaseManager.cpp
    src/RequestHandler.cpp
    src/BankServer.cpp
    src/ClientSession.cpp
    src/ConsoleHandler.cpp
    src/Logger.cpp
	src/CryptoEngine.cpp
)

set(HEADERS
    src/DatabaseManager.h
    src/RequestHandler.h
    src/BankServer.h
    src/ClientSession.h
    src/ConsoleHandler.h
    src/Logger.h
    src/ServerConfig.h
	src/CryptoEngine.h
    ../shared/NetworkProtocol.h
)

add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS})

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::Sql
)

if(OpenSSL_FOUND)
    target_link_libraries(${PROJECT_NAME} PRIVATE OpenSSL::SSL OpenSSL::Crypto)
    target_compile_definitions(${PROJECT_NAME} PRIVATE HAS_OPENSSL)
endif()

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/../shared
)

# Копировать settings.ini рядом с exe
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/settings.ini"
        "$<TARGET_FILE_DIR:${PROJECT_NAME}>/settings.ini"
    COMMENT "Copying settings.ini..."
)

# Windows: копирование DLL PostgreSQL
if(WIN32)
    set(POSTGRES_BIN_DIR "C:/Program Files/PostgreSQL/18/bin")
    if(EXISTS "${POSTGRES_BIN_DIR}")
        file(GLOB POSTGRES_DLLS "${POSTGRES_BIN_DIR}/*.dll")
        foreach(DLL ${POSTGRES_DLLS})
            add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${DLL}" "$<TARGET_FILE_DIR:${PROJECT_NAME}>"
            )
        endforeach()
    endif()

    # windeployqt
    get_target_property(_qmake_executable Qt6::qmake IMPORTED_LOCATION)
    get_filename_component(_qt_bin_dir "${_qmake_executable}" DIRECTORY)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")
    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND "${WINDEPLOYQT_EXECUTABLE}"
                --no-translations
                "$<TARGET_FILE:${PROJECT_NAME}>"
            COMMENT "Deploying Qt libraries for server..."
        )
    endif()
endif()

message(STATUS "")
message(STATUS "=== Server Configuration ===")
message(STATUS "Version: ${PROJECT_VERSION}")
message(STATUS "Qt: ${Qt6_VERSION}")
message(STATUS "Build: ${CMAKE_BUILD_TYPE}")
message(STATUS "======================================")
message(STATUS "")
