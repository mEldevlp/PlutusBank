<div align="center">

# PlutusBank

### Финансовая песочница для безопасного обучения банкингу

[![Qt](https://img.shields.io/badge/Qt-6.10-41CD52?logo=qt&logoColor=white)](https://www.qt.io/)
[![C++](https://img.shields.io/badge/C%2B%2B-17-00599C?logo=cplusplus&logoColor=white)](https://isocpp.org/)
[![QML](https://img.shields.io/badge/QML-Declarative_UI-3DDC84?logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qtqml-index.html)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20|%20Windows-blue)]()

---

**PlutusBank** — мобильное банковское приложение-тренажёр, в котором можно безопасно освоить управление финансами: от выпуска карт и переводов до кредитов и вложений — без риска потерять реальные деньги.

*Дипломный проект*

</div>

---

## О проекте

В школах не учат управлять деньгами. Люди впервые открывают банковское приложение — и сталкиваются с кредитами, переводами, депозитами, комиссиями, блокировками карт. Цена ошибки — реальные финансовые потери.

**PlutusBank** решает эту проблему. Это мост между незнанием и реальным банкингом: полноценный симулятор, где каждая операция выглядит и работает как в настоящем банке, но выполняется в безопасной «песочнице» с виртуальными средствами.

**Чему учит PlutusBank:**

- Открывать и управлять дебетовыми и кредитными картами
- Выполнять переводы между своими счетами и другим пользователям
- Пополнять баланс и отслеживать историю транзакций
- Понимать, что такое заморозка и блокировка карты
- Ориентироваться в интерфейсе современного банковского приложения
- В перспективе — работать с депозитами, кредитами, криптовалютами и инвестициями

---

## Технологический стек

| Слой | Технология | Назначение |
|------|-----------|------------|
| **Язык** | C++17 | Бизнес-логика, контроллеры, работа с данными |
| **UI-фреймворк** | Qt 6.10 + QML | Декларативный интерфейс с анимациями |
| **Сборка** | CMake 3.21+ | Кросс-платформенная сборка (Windows / Android) |
| **СУБД** | PostgreSQL 18 | Хранение пользователей, карт, транзакций |
| **Архитектура** | MVC | Контроллеры (C++) + Представления (QML) через Q_PROPERTY / Q_INVOKABLE |
| **Платформы** | Android 9+ (API 28), Windows | Мобильная и десктопная сборки |
| **Шрифты** | Manrope | Современная типографика |

---

## Скриншоты

<details>
	<summary>
		<b>Развернуть скриншоты приложения</b>
	</summary>
<br>

<div align="center">

| | |
|:---:|:---:|
| ![Screenshot 1](https://i.imgur.com/orwFBAS.jpeg) | ![Screenshot 2](https://i.imgur.com/kY1cc8H.jpeg) |
| ![Screenshot 3](https://i.imgur.com/gGVyjvX.jpeg) | ![Screenshot 4](https://i.imgur.com/IOOX8Im.jpeg) |
| ![Screenshot 5](https://i.imgur.com/sDPFt6k.jpeg) | ![Screenshot 6](https://i.imgur.com/noaTAFH.jpeg) |
| ![Screenshot 7](https://i.imgur.com/lC07suE.jpeg) | ![Screenshot 8](https://i.imgur.com/AjOdnHa.jpeg) |
| ![Screenshot 9](https://i.imgur.com/R19xifM.jpeg) | ![Screenshot 10](https://i.imgur.com/KI1omhD.jpeg) |
| ![Screenshot 11](https://i.imgur.com/rzwODus.jpeg) | ![Screenshot 12](https://i.imgur.com/dTxhoWn.jpeg) |

И многое другое...
</div>

</details>

---

## Roadmap

### Реализовано

- [x] Регистрация и авторизация пользователей (SHA-256 хэширование паролей)
- [x] Главная страница с отображением баланса и списка карт
- [x] Выпуск дебетовых и кредитных карт (Visa, Mastercard, МИР)
- [x] Детальная страница карты с реквизитами
- [x] Пополнение счёта
- [x] Переводы между своими счетами
- [x] Переводы другим пользователям по номеру телефона
- [x] История транзакций с группировкой по датам
- [x] Заморозка и блокировка карт
- [x] Тёмная тема с градиентным дизайном
- [x] Кросс-платформенная сборка (Android + Windows)
- [x] PostgreSQL-бэкенд с серверной частью

### В планах

- [ ] Оплата услуг и товаров (симуляция покупок)
- [ ] Кредитный модуль (оформление, графики платежей, процентные ставки)
- [ ] Депозиты и накопительные счета (начисление процентов)
- [ ] Криптовалютный модуль (покупка/продажа виртуальных активов)
- [ ] Инвестиционный портфель (акции, облигации, ETF)
- [ ] Обучающие сценарии и подсказки для новичков
- [ ] Push-уведомления о транзакциях
- [ ] Система достижений за освоение финансовых инструментов
- [ ] Аналитика расходов с графиками и категориями
- [ ] Мультивалютные счета и конвертация
- [ ] Экспорт истории операций (PDF / CSV)

---

## Архитектура

```
PlutusBank/
├── client/                         # Мобильное / десктопное приложение (Qt Quick)
│   ├── src/                        # C++ — контроллеры и сетевой слой
│   │   ├── main.cpp                # Точка входа, регистрация контроллеров в QML
│   │   ├── NetworkClient.*         # Singleton, TCP-клиент (синхронные запросы к серверу)
│   │   ├── AuthController.*        # Авторизация / регистрация
│   │   ├── UserSession.*           # Singleton, сессия текущего пользователя
│   │   ├── CardController.*        # Выпуск, заморозка, блокировка карт
│   │   ├── TransferController.*    # Переводы между счетами / другим пользователям
│   │   ├── HistoryController.*     # История транзакций
│   │   └── LoanController.*        # Кредиты: каталог, калькулятор, оформление, платежи
│   ├── qml/                        # QML — декларативный UI
│   │   ├── Main.qml                # Корневой StackView-навигатор
│   │   ├── Auth.qml                # Экран входа
│   │   ├── Register.qml            # Экран регистрации
│   │   ├── MainPage.qml            # Главная: баланс, карты, быстрые действия
│   │   ├── CreateCardDialog.qml    # Мастер выпуска карты (3 шага)
│   │   ├── CardDetailPage.qml      # Реквизиты и управление картой
│   │   ├── TransferPage.qml        # Переводы
│   │   ├── TopUpPage.qml           # Пополнение счёта
│   │   ├── HistoryPage.qml         # История операций с группировкой по датам
│   │   ├── SettingsPage.qml        # Настройки пользователя
│   │   ├── LoanCatalogPage.qml     # Каталог кредитных продуктов
│   │   ├── LoanCalculatorPage.qml  # Кредитный калькулятор (аннуитет)
│   │   ├── MyLoansPage.qml         # Список активных кредитов
│   │   ├── LoanSchedulePage.qml    # График платежей по кредиту
│   │   ├── LoanHistoryPage.qml     # Закрытые кредиты
│   │   ├── Theme.qml               # QML-singleton: цвета, градиенты
│   │   └── assets/                 # Шрифт Manrope, логотип, SVG-иконки
│   ├── android/                    # AndroidManifest, Gradle-конфигурация
│   ├── connection.ini              # Адрес и порт сервера
│   └── CMakeLists.txt              # Сборка клиента
│
├── server/                         # TCP-сервер (консольное Qt-приложение)
│   ├── main.cpp                    # Точка входа, запуск BankServer + консоль управления
│   ├── BankServer.*                # QTcpServer: приём подключений, kick/kickall
│   ├── ClientSession.*             # Сессия клиента: буферизация, маршрутизация запросов
│   ├── RequestHandler.*            # Роутер методов: auth, cards, transfers, loans …
│   ├── DatabaseManager.*           # Singleton, все SQL-запросы к PostgreSQL
│   ├── ConsoleHandler.*            # Чтение stdin в отдельном потоке (help, status, kick)
│   ├── Logger.*                    # Логирование в консоль и файл (debug/info/warning/error)
│   ├── ServerConfig.h              # Чтение settings.ini (порт, БД, логирование)
│   ├── settings.ini                # Конфигурация сервера
│   ├── database/
│   │   └── backup.sql              # Полный дамп схемы PostgreSQL
│   └── CMakeLists.txt              # Сборка сервера
│
└── shared/                         # Общий код клиента и сервера
    └── NetworkProtocol.h           # Формат фреймов, pack/tryExtract, makeSuccess/makeError
```
```

---

## Быстрый старт

**Зависимости:** Qt 6.10, CMake 3.21+, PostgreSQL 18

[Гайд по установке](guide/GUIDE.md)

---

## Лицензия

Проект распространяется под лицензией [MIT](LICENSE).

Вы можете свободно использовать, модифицировать и распространять код при сохранении текста лицензии.
