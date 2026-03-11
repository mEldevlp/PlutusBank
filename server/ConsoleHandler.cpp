#include "ConsoleHandler.h"
#include <iostream>
#include <string>

ConsoleHandler::ConsoleHandler(QObject* parent)
    : QThread(parent)
{}

void ConsoleHandler::stop()
{
    m_running = false;
}

void ConsoleHandler::run()
{
    std::string line;
    while (m_running && std::getline(std::cin, line))
    {
        QString cmd = QString::fromStdString(line).trimmed();
        if (!cmd.isEmpty())
            emit commandReceived(cmd);
    }
}
