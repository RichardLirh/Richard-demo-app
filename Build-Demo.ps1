param(
    [string]$TokenFile = (Join-Path $PSScriptRoot '..\.local\task-tokens.json'),
    [string]$Device = '264540ab',
    [switch]$Install,
    [switch]$IntegrationTest
)
$ErrorActionPreference = 'Stop'
$flutter = Join-Path $env:LOCALAPPDATA 'Flutter\flutter\bin\flutter.bat'
$env:JAVA_HOME = Join-Path $env:LOCALAPPDATA 'Java\jdk-17.0.20.1+1'
$env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
$proxy = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy([Uri]'https://pub.dev')
if ($proxy.Host -ne 'pub.dev') {
    $env:HTTP_PROXY = $proxy.AbsoluteUri
    $env:HTTPS_PROXY = $proxy.AbsoluteUri
    $env:NO_PROXY = 'localhost,127.0.0.1'
    $env:GRADLE_OPTS = "-Dhttp.proxyHost=$($proxy.Host) -Dhttp.proxyPort=$($proxy.Port) -Dhttps.proxyHost=$($proxy.Host) -Dhttps.proxyPort=$($proxy.Port)"
}
$local = Join-Path $PSScriptRoot '.local'
New-Item -ItemType Directory -Path $local -Force | Out-Null
$owner = (Get-Content -LiteralPath $TokenFile -Raw | ConvertFrom-Json).owner
if (-not $owner) { throw 'Owner token not found in local token file.' }
$defines = Join-Path $local 'defines.secrets.json'
@{DEMO_API_URL='http://127.0.0.1:8010';DEMO_API_TOKEN=$owner} | ConvertTo-Json | Set-Content -LiteralPath $defines -Encoding utf8
Push-Location $PSScriptRoot
try {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
    if ($IntegrationTest) {
        & $adb -s $Device reverse tcp:8010 tcp:8010
        & $adb -s $Device reverse tcp:18765 tcp:18765
        & $flutter test integration_test/task_flow_test.dart -d $Device "--dart-define-from-file=$defines"
        if ($LASTEXITCODE -ne 0) { throw 'Device integration test failed.' }
    } else {
        & $flutter build apk --debug --target-platform android-arm64 "--dart-define-from-file=$defines"
        if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }
        if ($Install) {
            & $adb -s $Device reverse tcp:8010 tcp:8010
            & $adb -s $Device reverse tcp:18765 tcp:18765
            & $adb -s $Device install -r (Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-debug.apk')
            if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }
            & $adb -s $Device shell am start -n 'com.raiot.richard_demo_app/.MainActivity'
        }
    }
} finally { Pop-Location }
