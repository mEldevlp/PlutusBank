Write-Host "Findig installed Qt..." -ForegroundColor Green

# Автопоиск Qt
$qtBasePath = "C:\Qt"
$qtVersions = Get-ChildItem $qtBasePath -Directory | Where-Object { $_.Name -match "^\d+\.\d+\.\d+$" } | Sort-Object -Descending

if ($qtVersions.Count -eq 0) {
    Write-Host "Qt have not found in $qtBasePath" -ForegroundColor Red
    exit 1
}

$qtVersion = $qtVersions[0].Name
Write-Host "Founded version Qt: $qtVersion" -ForegroundColor Cyan

# Поиск Android и MSVC сборок
$qtAndroid = Get-ChildItem "$qtBasePath\$qtVersion" -Directory | Where-Object { $_.Name -match "android.*arm64" } | Select-Object -First 1
$qtMsvc = Get-ChildItem "$qtBasePath\$qtVersion" -Directory | Where-Object { $_.Name -match "msvc" } | Select-Object -First 1

if (!$qtAndroid) {
    Write-Host "Android build Qt not found!" -ForegroundColor Red
    exit 1
}

if (!$qtMsvc) {
    Write-Host "MSVC build Qt not found!" -ForegroundColor Red
    exit 1
}

$qtAndroidPath = $qtAndroid.FullName
$qtMsvcPath = $qtMsvc.FullName

Write-Host "Qt Android: $qtAndroidPath" -ForegroundColor Green
Write-Host "Qt MSVC: $qtMsvcPath" -ForegroundColor Green

# Установка переменных
[System.Environment]::SetEnvironmentVariable('QT_ANDROID_DIR', $qtAndroidPath, 'User')
[System.Environment]::SetEnvironmentVariable('QT_HOST_DIR', $qtMsvcPath, 'User')
[System.Environment]::SetEnvironmentVariable('Qt6_DIR', $qtMsvcPath, 'User')

$env:QT_ANDROID_DIR = $qtAndroidPath
$env:QT_HOST_DIR = $qtMsvcPath
$env:Qt6_DIR = $qtMsvcPath

Write-Host "`nEnvironment variables are set!" -ForegroundColor Green