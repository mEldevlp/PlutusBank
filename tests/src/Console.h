#pragma once

#include <QString>

/*
    Console — единственное место, где мы лезем в stdout.
    Делаем две вещи:
      1) Включаем поддержку ANSI escape-последовательностей на Windows
         (Windows 10 1607+ и новее) и переключаем кодировку вывода на UTF-8,
         чтобы кириллица отображалась корректно.
      2) Предоставляем короткие константы для цветов и две функции
         (print / println), которые принимают QString и пишут его в UTF-8.
*/

namespace Console
{

    // ANSI escape-последовательности (SGR)
    inline constexpr const char* RESET   = "\x1b[0m";
    inline constexpr const char* BOLD    = "\x1b[1m";
    inline constexpr const char* DIM     = "\x1b[2m";
    inline constexpr const char* RED     = "\x1b[31m";
    inline constexpr const char* GREEN   = "\x1b[32m";
    inline constexpr const char* YELLOW  = "\x1b[33m";
    inline constexpr const char* BLUE    = "\x1b[34m";
    inline constexpr const char* MAGENTA = "\x1b[35m";
    inline constexpr const char* CYAN    = "\x1b[36m";
    inline constexpr const char* GREY    = "\x1b[90m";

    // Инициализация консоли. Вызывать один раз в начале main().
    void init();

    // Печать UTF-8 строки. println() добавляет '\n'.
    void println(const QString& line = QString());
    void print(const QString& text);

} // namespace Console
