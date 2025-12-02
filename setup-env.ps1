Write-Host "Настройка переменных окружения..." -ForegroundColor Green

# Проверка существования путей
$vcpkgPath = "C:\dev\vcpkg"
$qtPath = "C:\Qt\6.10.1\android_arm64_v8a"
$ndkPath = "C:\Android\ndk\27.3.13750724"

if (!(Test-Path $vcpkgPath)) {
    Write-Host "ВНИМАНИЕ: Путь $vcpkgPath не найден!" -ForegroundColor Yellow
}

if (!(Test-Path $qtPath)) {
    Write-Host "ВНИМАНИЕ: Путь $qtPath не найден!" -ForegroundColor Yellow
}

if (!(Test-Path $ndkPath)) {
    Write-Host "ВНИМАНИЕ: Путь $ndkPath не найден!" -ForegroundColor Yellow
}

# Установка переменных
[System.Environment]::SetEnvironmentVariable('VCPKG_ROOT', $vcpkgPath, 'User')
[System.Environment]::SetEnvironmentVariable('QT_ANDROID_DIR', $qtPath, 'User')
[System.Environment]::SetEnvironmentVariable('ANDROID_NDK_ROOT', $ndkPath, 'User')

# Для текущей сессии
$env:VCPKG_ROOT = $vcpkgPath
$env:QT_ANDROID_DIR = $qtPath
$env:ANDROID_NDK_ROOT = $ndkPath

Write-Host "`nПеременные окружения установлены:" -ForegroundColor Green
Write-Host "VCPKG_ROOT = $env:VCPKG_ROOT"
Write-Host "QT_ANDROID_DIR = $env:QT_ANDROID_DIR"
Write-Host "ANDROID_NDK_ROOT = $env:ANDROID_NDK_ROOT"