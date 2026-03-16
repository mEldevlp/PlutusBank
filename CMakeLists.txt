cmake_minimum_required(VERSION 3.21)

project(PlutusBank VERSION 1.0.0 LANGUAGES CXX)

# ── Включаем папки в Solution Explorer ────────────
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# ── CMakePredefinedTargets → _Infrastructure ──────
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "_Infrastructure/CMake")

# ── Autogen таргеты (moc, uic, rcc) → _Infrastructure ──
set(CMAKE_AUTOGEN_TARGETS_FOLDER "_Infrastructure/Generated")

# ── Опции сборки ──────────────────────────────────
option(BUILD_CLIENT "Build PlutusBank Client" ON)
option(BUILD_SERVER "Build PlutusBank Server"  ON)

# ── Общая папка shared ────────────────────────────
set(SHARED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/shared")

# ── Подпроекты ────────────────────────────────────
if(BUILD_CLIENT)
    add_subdirectory(client)
endif()

if(BUILD_SERVER)
    add_subdirectory(server)
endif()

# ── Убираем мусор из Solution Explorer ────────────
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

# ── Информация ────────────────────────────────────
message(STATUS "")
message(STATUS "=== PlutusBank Root ===")
message(STATUS "Client : ${BUILD_CLIENT}")
message(STATUS "Server : ${BUILD_SERVER}")
message(STATUS "========================")
message(STATUS "")