$buildTools = "C:\Android\Sdk\build-tools\35.0.0"
$unsigned = "build\android\android-build\build\outputs\apk\release\android-build-release-unsigned.apk"
$aligned = "build\android\PlutusBank-aligned.apk"
$signed = "build\android\PlutusBank-signed.apk"

Write-Host "Aligning APK..." -ForegroundColor Cyan
& "$buildTools\zipalign.exe" -v -p 4 $unsigned $aligned

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: zipalign failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Signing APK..." -ForegroundColor Cyan
& "$buildTools\apksigner.bat" sign `
    --ks "plutusbank.keystore" `
    --ks-key-alias "plutusbank" `
    --ks-pass "pass:plutus" `
    --key-pass "pass:plutus" `
    --out $signed $aligned

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: apksigner failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Verifying signature..." -ForegroundColor Cyan
& "$buildTools\apksigner.bat" verify $signed

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nSUCCESS! Signed APK: $signed" -ForegroundColor Green
} else {
    Write-Host "`nERROR: Signature verification failed!" -ForegroundColor Red
    exit 1
}
