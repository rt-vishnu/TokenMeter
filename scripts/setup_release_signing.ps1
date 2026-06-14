# One-time setup for Play Store release signing.
# Creates android/upload-keystore.jks and android/key.properties (both gitignored).
#
# Usage: .\scripts\setup_release_signing.ps1
#
# BACK UP upload-keystore.jks and key.properties somewhere safe (password manager,
# encrypted drive). You cannot update the app on Play Store without them.

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Android = Join-Path $Root "android"
$Ks = Join-Path $Android "upload-keystore.jks"
$Props = Join-Path $Android "key.properties"

if ((Test-Path $Ks) -and (Test-Path $Props)) {
    Write-Host "Release signing already configured ($Ks exists)."
    exit 0
}

function Find-Keytool {
    $candidates = @(
        "$env:JAVA_HOME\bin\keytool.exe",
        "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    throw "keytool not found. Install Android Studio or set JAVA_HOME."
}

$keytool = Find-Keytool
$storePass = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
$keyPass = $storePass

[System.IO.File]::WriteAllLines($Props, @(
    "storePassword=$storePass",
    "keyPassword=$keyPass",
    "keyAlias=upload",
    "storeFile=../upload-keystore.jks"
), (New-Object System.Text.UTF8Encoding $false))

& $keytool -genkeypair -v `
    -keystore $Ks `
    -storetype JKS `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias upload `
    -storepass $storePass `
    -keypass $keyPass `
    -dname "CN=PromptPenny, OU=Mobile, O=PromptPenny, L=Unknown, ST=Unknown, C=US"

Write-Host "Created:"
Write-Host "  $Ks"
Write-Host "  $Props"
Write-Host ""
Write-Host "Save both files securely. Passwords are in key.properties only."
Write-Host "Then run: flutter build appbundle --release"
