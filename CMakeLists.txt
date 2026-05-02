cmake_minimum_required(VERSION 3.21)

project(PlutusBank VERSION 0.9.0 LANGUAGES CXX)

# build-номер
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

set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "_Infrastructure/CMake")

set(CMAKE_AUTOGEN_TARGETS_FOLDER "_Infrastructure/Generated")
option(BUILD_CLIENT "Build PlutusBank Client" ON)

set(SHARED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/shared")


if(BUILD_CLIENT)
    add_subdirectory(client)
endif()


# Чтобы Client стартовал по F5 без выбора через ПКМ
if(BUILD_CLIENT)
    set_property(DIRECTORY "${CMAKE_SOURCE_DIR}"
                 PROPERTY VS_STARTUP_PROJECT Client)
endif()


cmake_language(DEFER CALL _cleanup_solution)

function(_cleanup_solution)
    function(_set_folder target folder)
        if(TARGET ${target})
            set_target_properties(${target} PROPERTIES FOLDER "${folder}")
        endif()
    endfunction()

    # Qt автогенерация (Client)
    _set_folder(Client_automoc_json_extraction      "_Infrastructure/Generated")
    _set_folder(Client_qmltyperegistration          "_Infrastructure/Generated")
    _set_folder(Client_qmlimportscan                "_Infrastructure/Generated")
    _set_folder(Client_copy_qml                     "_Infrastructure/Generated")
    _set_folder(Client_copy_res                     "_Infrastructure/Generated")
    _set_folder(all_qmltyperegistrations            "_Infrastructure/Generated")

    # QML Lint
    _set_folder(Client_qmllint          "_Infrastructure/QMLLint")
    _set_folder(Client_qmllint_json     "_Infrastructure/QMLLint")
    _set_folder(Client_qmllint_module   "_Infrastructure/QMLLint")
    _set_folder(all_qmllint             "_Infrastructure/QMLLint")
    _set_folder(all_qmllint_json        "_Infrastructure/QMLLint")
    _set_folder(all_qmllint_module      "_Infrastructure/QMLLint")

    # AOT
    _set_folder(module_Client_aotstats_target  "_Infrastructure/AOT")
    _set_folder(all_aotstats                   "_Infrastructure/AOT")

    # Прочее
    _set_folder(generate_qmlls_build_ini_file  "_Infrastructure/Tools")
endfunction()

# Информация
message(STATUS "")
message(STATUS "=== PlutusBank Root ===")
message(STATUS "Client : ${BUILD_CLIENT}")
message(STATUS "========================")
message(STATUS "")