# Руководство по установке компонентов проекта

---

## 1. Android SDK и NDK

### Что понадобится

- **Android SDK** (Command Line Tools)
- **Android NDK** версии `27.3.13750724` (r27d)

### Скачивание

**NDK:** скачайте архив по ссылке — [android-ndk-r27d-windows.zip](https://dl.google.com/android/repository/android-ndk-r27d-windows.zip). Далее по тексту — *архив (1)*.

**SDK:** перейдите на [developer.android.com/studio](https://developer.android.com/studio), пролистайте страницу вниз до раздела **Command line tools only** и скачайте версию для вашей платформы (в проекте используется Windows). Скачается файл вида `commandlinetools-win-XXXXXXX_latest.zip` — далее *архив (2)*.

### Подготовка структуры каталогов

Создайте на диске `C:\` следующие папки:

```
C:\Android\Sdk
C:\Android\ndk
```

### Установка SDK

1. Из *архива (2)* извлеките папку `cmdline-tools` в `C:\Android\Sdk\`.
2. Внутри `cmdline-tools` создайте подпапку `latest`.
3. Переместите всё содержимое `cmdline-tools` (папки `lib`, `bin`, файлы `NOTICE.txt`, `source.properties`) в `latest`.
4. Откройте терминал в каталоге `C:\Android\Sdk\cmdline-tools\latest\bin` и выполните:

```powershell
.\sdkmanager.bat "platforms;android-34" "build-tools;34.0.0"
```

### Установка NDK

1. В каталоге `C:\Android\ndk` создайте папку `27.3.13750724`.
2. Откройте *архив (1)*, зайдите во вложенную папку и скопируйте **всё её содержимое** в `C:\Android\ndk\27.3.13750724`.

---

## 2. vcpkg

1. Создайте каталог `C:\dev` и откройте в нём терминал.
2. Выполните команды:

```powershell
git clone https://github.com/microsoft/vcpkg.git
cd .\vcpkg\
.\bootstrap-vcpkg.bat
```

---

## 3. Qt 6.10

> Для скачивания может потребоваться VPN.

1. Перейдите на страницу [загрузки Qt](https://www.qt.io/development/download-qt-installer-oss).
2. Выберите вашу ОС и нажмите **Qt Online Installer for Windows (x64)**.
3. Запустите скачанный установщик (файл вида `qt-online-installer-windows-x64-4.10.0.exe`).
4. Зарегистрируйтесь или войдите в учётную запись Qt.
5. Укажите путь установки — `C:\Qt`.
6. Выберите **Desktop**, **мобильную разработку** и **выборочную установку**.
7. Отметьте пакеты согласно скриншотам ниже.

<details>
	<summary>
	Нажмите, чтобы посмотреть скриншоты выбора пакетов
	</summary>

<div align="center">

| | |
|:---:|:---:|
| ![Screenshot 1](https://i.imgur.com/HiDTQrp.jpeg) | ![Screenshot 2](https://i.imgur.com/KvP0bZX.jpeg) |
| ![Screenshot 3](https://i.imgur.com/gXNMjzf.jpeg) | |

</div>
	
</details>

---

## 4. Переменные окружения

Откройте окно переменных среды: `Win + R` → введите `sysdm.cpl` → вкладка **Дополнительно** → кнопка **Переменные среды**.

В разделе **Переменные пользователя** создайте следующие записи:

| Переменная         | Значение                                |
| ------------------- | --------------------------------------- |
| `ANDROID_NDK_ROOT` | `C:\Android\ndk\27.3.13750724`          |
| `ANDROID_SDK_ROOT` | `C:\Android\Sdk`                        |
| `VCPKG_ROOT`       | `C:\dev\vcpkg`                          |
| `QT_ANDROID_DIR`   | `C:\Qt\6.10.2\android_arm64_v8a`        |
| `QT_HOST_DIR`      | `C:\Qt\6.10.2\msvc2022_64`             |
| `Qt6_DIR`          | `C:\Qt\6.10.2\msvc2022_64`             |

---

## 5. PostgreSQL

### Установка

1. Перейдите на [страницу загрузки PostgreSQL](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads).
2. Скачайте версию **18.3** для Windows (файл `postgresql-18.3-1-windows-x64.exe`).
3. Запустите установщик и следуйте шагам, используя следующие параметры:

| Параметр       | Значение   |
| -------------- | ---------- |
| Имя пользователя | `postgres` |
| Пароль         | `root`     |
| Порт           | `5432`     |

### Настройка базы данных

1. После установки откройте **pgAdmin 4** и подключитесь к серверу **PostgreSQL 18**.
2. Создайте новую базу данных с именем `plutusbank` (остальные настройки оставьте по умолчанию).
3. Правой кнопкой мыши по базе `plutusbank` → **Restore** → выберите формат **Plain**.
4. В диалоге выбора файла смените фильтр расширения с `.backup` на `.sql` и укажите файл `backup.sql` из каталога проекта.
