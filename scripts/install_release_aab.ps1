# Builds (optional) and installs the release AAB on a connected Android device
# using bundletool (same delivery path as Google Play).
#
# Usage:
#   .\scripts\install_release_aab.ps1              # install existing AAB
#   .\scripts\install_release_aab.ps1 -Build       # flutter build appbundle first
#   .\scripts\install_release_aab.ps1 -SmokeTest   # launch app and scan logcat
#   .\scripts\install_release_aab.ps1 -DeviceId XOQSS8SW55X8B6CA
#
# Requires: Flutter SDK, Android SDK (adb), Java (Android Studio JBR is auto-detected)
#
# Signing:
#   If android/key.properties exists, universal APKs are signed with your release keystore.
#   Otherwise, device-specific APKs are built for the connected device (debug-signed AAB).

param(
    [switch]$Build,
    [switch]$SmokeTest,
    [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Aab = Join-Path $Root "build\app\outputs\bundle\release\app-release.aab"
$Apks = Join-Path $Root "build\app\outputs\bundle\release\app-release.apks"
$Package = "com.promptpenny.app"
$BundletoolJar = Join-Path $env:USERPROFILE ".local\bundletool.jar"
$BundletoolVersion = "1.17.2"

function Find-Java {
    $candidates = @(
        "$env:JAVA_HOME\bin\java.exe",
        "C:\Program Files\Android\Android Studio\jbr\bin\java.exe",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\java.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    throw "Java not found. Install Android Studio or set JAVA_HOME."
}

function Find-Adb {
    if ($env:ANDROID_HOME) {
        $adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
        if (Test-Path $adb) { return $adb }
    }
    $adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $adb) { return $adb }
    throw "adb not found. Install Android SDK platform-tools."
}

function Invoke-Adb {
    param(
        [Parameter(Mandatory)]
        [string[]]$Cmd
    )
    # adb writes informational messages (e.g. daemon startup) to stderr.
    # With $ErrorActionPreference = "Stop", PowerShell treats those as fatal.
    $prevPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $script:adb @script:adbArgs @Cmd 2>&1 |
            Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
    } finally {
        $ErrorActionPreference = $prevPreference
    }
}

function Ensure-Bundletool {
    if (Test-Path $BundletoolJar) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path $BundletoolJar) | Out-Null
    $url = "https://github.com/google/bundletool/releases/download/$BundletoolVersion/bundletool-all-$BundletoolVersion.jar"
    Write-Host "Downloading bundletool $BundletoolVersion..."
    Invoke-WebRequest -Uri $url -OutFile $BundletoolJar
}

function Read-KeyProperties {
    $path = Join-Path $Root "android\key.properties"
    if (-not (Test-Path $path)) {
        return $null
    }
    $props = @{}
    Get-Content $path | ForEach-Object {
        if ($_ -match '^([^=#]+)=(.*)$') {
            $props[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
    $storeRel = $props['storeFile'] -replace '^\.\./', ''
    $props['storePath'] = (Resolve-Path (Join-Path $Root "android\$storeRel")).Path
    return $props
}

function Build-ApksFromAab {
    param(
        [string]$Java,
        [hashtable]$Keys
    )

    if ($Keys) {
        Write-Host "Building universal APK set from AAB (release signing)..."
        $ksPath = $Keys['storePath']
        $ksAlias = $Keys['keyAlias']
        $ksStorePass = $Keys['storePassword']
        $ksKeyPass = $Keys['keyPassword']
        & $Java -jar $BundletoolJar build-apks `
            --bundle=$Aab `
            --output=$Apks `
            --mode=universal `
            --overwrite `
            --ks=$ksPath `
            "--ks-pass=pass:$ksStorePass" `
            "--ks-key-alias=$ksAlias" `
            "--key-pass=pass:$ksKeyPass"
        return
    }

    Write-Host "android/key.properties not found - building device-specific APK set (connected device)..."
    Write-Host "Tip: add a release keystore + key.properties before Play Store upload."
    & $Java -jar $BundletoolJar build-apks `
        --bundle=$Aab `
        --output=$Apks `
        --connected-device `
        --adb=$script:adb `
        --overwrite
}

if ($Build) {
    Write-Host "Building release app bundle..."
    flutter build appbundle --release
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build appbundle --release failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path $Aab)) {
    throw "AAB not found at $Aab. Run with -Build or run: flutter build appbundle --release"
}

$java = Find-Java
$script:adb = Find-Adb
$script:adbArgs = @()
if ($DeviceId) { $script:adbArgs += "-s", $DeviceId }

Ensure-Bundletool
$keys = Read-KeyProperties
Build-ApksFromAab -Java $java -Keys $keys

Write-Host "Uninstalling any existing $Package install..."
Invoke-Adb @('uninstall', $Package) | Out-Null

Write-Host "Installing release bundle (Play-equivalent delivery)..."
& $java -jar $BundletoolJar install-apks --apks=$Apks --adb=$script:adb

if ($SmokeTest) {
    Write-Host "Running smoke test (launch + logcat scan)..."
    Invoke-Adb @('logcat', '-c') | Out-Null
    Invoke-Adb @('shell', 'am', 'start', '-n', "$Package/.MainActivity") | Out-Null
    Start-Sleep -Seconds 10
    $fatals = Invoke-Adb @('logcat', '-d') | Select-String -Pattern "FATAL EXCEPTION|AndroidRuntime.*FATAL"
    if ($fatals) {
        $fatals | ForEach-Object { Write-Host $_ }
        throw "Smoke test failed: fatal errors in logcat."
    }
    $appPid = (Invoke-Adb @('shell', 'pidof', $Package) | Out-String).Trim()
    if (-not $appPid) {
        throw "Smoke test failed: $Package is not running."
    }
    Write-Host "Smoke test passed (app running, no FATAL in logcat)."
}

Write-Host "Done. Release AAB installed from: $Aab"
