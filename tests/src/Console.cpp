#include "Console.h"

#include <iostream>

#ifdef _WIN32
#  include <windows.h>
#endif

namespace Console
{

    void init()
    {
    #ifdef _WIN32
        // UTF-8 для входа и выхода консоли (нужно для кириллицы)
        SetConsoleOutputCP(CP_UTF8);
        SetConsoleCP(CP_UTF8);

        // Включаем виртуальный терминал (ANSI escape-последовательности)
        const HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        if (hOut != INVALID_HANDLE_VALUE && hOut != nullptr)
        {
            DWORD mode = 0;
            if (GetConsoleMode(hOut, &mode))
            {
                SetConsoleMode(hOut, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
            }
        }
    #endif

        // На случай редиректа stdout — отключаем буферизацию построчно
        std::cout.setf(std::ios::unitbuf);
    }

    void println(const QString& line)
    {
        const QByteArray utf8 = line.toUtf8();
        std::cout.write(utf8.constData(), utf8.size());
        std::cout.put('\n');
    }

    void print(const QString& text)
    {
        const QByteArray utf8 = text.toUtf8();
        std::cout.write(utf8.constData(), utf8.size());
    }

} // namespace Console
