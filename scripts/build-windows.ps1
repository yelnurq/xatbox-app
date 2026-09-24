<#
.SYNOPSIS
  Сборка XatBox для Windows одной командой.

.DESCRIPTION
  Результат кладётся в папку dist\ в корне проекта, папка открывается в Проводнике:
    XatBox-windows-<версия>-b<сборка>.zip        — портативная версия (распаковать и запустить XatBox.exe);
    XatBox-Setup-<версия>-b<сборка>.exe          — установщик, если на компьютере есть Inno Setup 6.
  Адреса серверов берутся из env\<имя>.json (см. env\README.md) — те же файлы, что для APK.

  Нужно на этом компьютере:
    * Flutter (тот же, что для APK);
    * Visual Studio 2022 (или Build Tools) с набором «Разработка классических приложений на C++»;
    * по желанию Inno Setup 6 (https://jrsoftware.org/isinfo.php) — для установщика.
  Подробности: docs\BUILD-DESKTOP.md.

  Подпись кода (все .exe и .dll программы, установщик и деинсталлятор; signtool из Windows SDK):
    * Azure Trusted Signing — XATBOX_SIGN_DLIB (путь к Azure.CodeSigning.Dlib.dll) и
      XATBOX_SIGN_METADATA (metadata.json: Endpoint, CodeSigningAccountName,
      CertificateProfileName); вход в Azure — AZURE_TENANT_ID / AZURE_CLIENT_ID /
      AZURE_CLIENT_SECRET;
    * или сертификат .pfx — XATBOX_SIGN_PFX и XATBOX_SIGN_PASSWORD.
  Без них сборка не подписывается. Неподписанные файлы Windows 11 со «Интеллектуальным
  управлением приложениями» может не запустить (ошибка 0xc0e90002).

.EXAMPLE
  .\build-windows.cmd
  .\build-windows.cmd -Env server
  .\build-windows.cmd -Env server -Run
#>
[CmdletBinding()]
param(
  # Имя файла из env\ без .json (server, stage…) или путь к нему.
  [Alias('Env')][string]$EnvName = '',
  [ValidateSet('release', 'debug')][string]$BuildType = 'release',
  # После сборки запустить XatBox.exe.
  [switch]$Run,
  # Номер сборки вместо того, что в pubspec.yaml (GitHub Actions ставит 100 + номер запуска,
  # чтобы каждая сборка была новее предыдущей и автообновление её предлагало).
  [int]$BuildNumber = 0,
  # Не собирать установщик, даже если Inno Setup найден.
  [switch]$NoInstaller,
  # Не открывать папку dist\ в конце.
  [switch]$NoOpen
)

# Ошибки нативных команд проверяются через $LASTEXITCODE (Stop ломает их вывод в PowerShell 5.1).
$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Say([string]$Text, [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }
function Step([string]$Text) { Write-Host ''; Write-Host "==> $Text" -ForegroundColor Cyan }
function Fail([string]$Text) {
  Write-Host ''
  Write-Host "ОШИБКА: $Text" -ForegroundColor Red
  exit 1
}

function Select-EnvFile {
  $dir = Join-Path $Root 'env'
  $files = @()
  if (Test-Path $dir) { $files = @(Get-ChildItem $dir -Filter '*.json' -File | Sort-Object Name) }
  if ($EnvName) {
    if ([IO.Path]::IsPathRooted($EnvName) -and (Test-Path $EnvName -PathType Leaf)) { return Get-Item $EnvName }
    foreach ($c in @($EnvName, "env\$EnvName", "env\$EnvName.json")) {
      $p = Join-Path $Root $c
      if (Test-Path $p -PathType Leaf) { return Get-Item $p }
    }
    $known = ($files | ForEach-Object { $_.BaseName }) -join ', '
    Fail "Не найден файл настроек '$EnvName'. В папке env есть: $known"
  }
  if ($files.Count -eq 0) {
    Fail ("В папке env нет ни одного *.json. Скопируйте пример и впишите адреса серверов:`n" +
      "  copy env\prod.json.example env\my.json`nи запустите снова.")
  }
  if ($files.Count -eq 1) { return $files[0] }
  Say 'Какие настройки сервера использовать?' 'White'
  for ($i = 0; $i -lt $files.Count; $i++) { Say ('  {0}) {1}' -f ($i + 1), $files[$i].BaseName) }
  $n = 0
  do {
    $answer = Read-Host "Номер (1-$($files.Count))"
  } until ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $files.Count)
  return $files[$n - 1]
}

function Show-EnvSummary($File) {
  try {
    $cfg = Get-Content $File.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
  } catch {
    Fail "$($File.Name) — это не корректный JSON: $($_.Exception.Message)"
  }
  foreach ($k in 'XATBOX_FLAVOR', 'XATBOX_API_BASE_URL', 'XATBOX_CHAT_BASE_URL', 'XATBOX_CALLS_BASE_URL') {
    $v = "$($cfg.$k)"
    if ($v -eq '') { $v = '(не задано)' }
    Say ('  {0,-23} {1}' -f $k, $v)
  }
  Say '  уведомления             через открытое соединение (Firebase на компьютере не нужен)'
}

function Find-Flutter {
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @()
  if ($env:FLUTTER_ROOT) { $candidates += (Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat') }
  $candidates += (Join-Path $env:USERPROFILE 'dev\flutter\bin\flutter.bat')
  $candidates += (Join-Path $env:USERPROFILE 'flutter\bin\flutter.bat')
  $candidates += 'C:\src\flutter\bin\flutter.bat', 'C:\flutter\bin\flutter.bat'
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  return $null
}

# Visual Studio с компонентом C++ (VC.Tools) — без него Flutter не соберёт Windows-версию.
function Test-VisualStudio {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (-not (Test-Path $vswhere)) { return $false }
  $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  return [bool]$path
}

function Find-SignTool {
  $kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
  if (-not (Test-Path $kits)) { return $null }
  $tool = Get-ChildItem $kits -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\x64\\' } | Sort-Object FullName -Descending | Select-Object -First 1
  if ($tool) { return $tool.FullName }
  return $null
}

# Аргументы signtool для настроенной подписи (Azure Trusted Signing или .pfx), либо $null.
function Get-SignArgs {
  if ($env:XATBOX_SIGN_DLIB) {
    if (-not (Test-Path $env:XATBOX_SIGN_DLIB)) { Fail "Не найден $env:XATBOX_SIGN_DLIB." }
    if (-not (Test-Path $env:XATBOX_SIGN_METADATA)) { Fail "Не найден $env:XATBOX_SIGN_METADATA." }
    return @('sign', '/fd', 'SHA256', '/tr', 'http://timestamp.acs.microsoft.com', '/td', 'SHA256',
      '/dlib', $env:XATBOX_SIGN_DLIB, '/dmdf', $env:XATBOX_SIGN_METADATA)
  }
  if ($env:XATBOX_SIGN_PFX) {
    if (-not (Test-Path $env:XATBOX_SIGN_PFX)) { Fail "Не найден сертификат $env:XATBOX_SIGN_PFX." }
    return @('sign', '/fd', 'SHA256', '/td', 'SHA256', '/tr', 'http://timestamp.digicert.com',
      '/f', $env:XATBOX_SIGN_PFX, '/p', $env:XATBOX_SIGN_PASSWORD)
  }
  return $null
}

# Подписывает файлы, если настроена подпись.
function Sign-Files([string[]]$Files) {
  $signArgs = Get-SignArgs
  if (-not $signArgs -or -not $Files) { return }
  $signtool = Find-SignTool
  if (-not $signtool) { Fail 'Не найден signtool.exe (Windows SDK) для подписи.' }
  # Пачками: командная строка Windows не бесконечна.
  for ($i = 0; $i -lt $Files.Count; $i += 20) {
    $batch = $Files[$i..([Math]::Min($i + 19, $Files.Count - 1))]
    & $signtool @signArgs @batch
    if ($LASTEXITCODE -ne 0) { Fail "Не удалось подписать: $($batch -join ', ')." }
  }
  Say "  подписано файлов: $($Files.Count)" 'Green'
}

function Find-InnoSetup {
  $cmd = Get-Command iscc -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($c in @(
      (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
      (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'))) {
    if ($c -and (Test-Path $c)) { return $c }
  }
  return $null
}

# --- проверки ---------------------------------------------------------------------------------

$envFile = Select-EnvFile
Step "Настройки: env\$($envFile.Name)"
Show-EnvSummary $envFile

$flutter = Find-Flutter
if (-not $flutter) { Fail 'Flutter не найден. Установите его (docs\BUILD-APK.md, раздел «Локальная сборка») или добавьте в PATH.' }
if (-not (Test-VisualStudio)) {
  Fail ("Не найдена Visual Studio с C++. Установите Visual Studio 2022 Community (или Build Tools)`n" +
    "и отметьте набор «Разработка классических приложений на C++» (Desktop development with C++).")
}

$pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw -Encoding UTF8
if ($pubspec -notmatch '(?m)^version:\s*([0-9.]+)\+([0-9]+)') { Fail 'В pubspec.yaml нет строки version: X.Y.Z+N' }
$version = $Matches[1]
$build = $Matches[2]
if ($BuildNumber -gt 0) { $build = "$BuildNumber" }
Say "  версия                  $version (сборка $build)"

# --- сборка -----------------------------------------------------------------------------------

Step 'Подготовка Flutter'
& $flutter config --enable-windows-desktop | Out-Null
& $flutter pub get
if ($LASTEXITCODE -ne 0) { Fail 'flutter pub get завершился с ошибкой.' }

Step "Сборка Windows ($BuildType)"
& $flutter build windows "--$BuildType" "--dart-define-from-file=$($envFile.FullName)" "--build-name=$version" "--build-number=$build"
if ($LASTEXITCODE -ne 0) { Fail 'Сборка не удалась (сообщение Flutter выше).' }

$typeDir = if ($BuildType -eq 'release') { 'Release' } else { 'Debug' }
$out = Join-Path $Root "build\windows\x64\runner\$typeDir"
if (-not (Test-Path (Join-Path $out 'XatBox.exe'))) { Fail "Не найден $out\XatBox.exe." }
# Подписываются все исполняемые файлы: Windows проверяет и каждую DLL (плагины Flutter,
# WebRTC), а не только XatBox.exe.
Sign-Files @(Get-ChildItem $out -Recurse -Include *.exe, *.dll | ForEach-Object { $_.FullName })

$dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$suffix = if ($BuildType -eq 'release') { '' } else { '-debug' }
$base = "XatBox-windows-$version-b$build$suffix"

Step 'Архив (портативная версия)'
$zip = Join-Path $dist "$base.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip
Say "  $zip" 'Green'

if (-not $NoInstaller -and $BuildType -eq 'release') {
  $iscc = Find-InnoSetup
  if ($iscc) {
    Step 'Установщик (Inno Setup)'
    $isccArgs = @('/Q', "/DAppVersion=$version", "/DAppBuild=$build", "/DSourceDir=$out", "/DOutputDir=$dist")
    # Inno Setup сам подписывает установщик и деинсталлятор (SignTool=xatbox в xatbox.iss).
    $signArgs = Get-SignArgs
    if ($signArgs) {
      $signtool = Find-SignTool
      if (-not $signtool) { Fail 'Не найден signtool.exe (Windows SDK) для подписи.' }
      $quoted = ($signArgs | ForEach-Object { if ($_ -match '\s') { '$q' + $_ + '$q' } else { $_ } }) -join ' '
      $isccArgs += "/Sxatbox=`$q$signtool`$q $quoted `$f"
      $isccArgs += '/DSignInstaller'
    }
    & $iscc @isccArgs (Join-Path $Root 'windows\installer\xatbox.iss')
    if ($LASTEXITCODE -ne 0) { Fail 'Inno Setup завершился с ошибкой.' }
    Say "  $(Join-Path $dist "XatBox-Setup-$version-b$build.exe")" 'Green'
  } else {
    Say ''
    Say 'Inno Setup 6 не найден — собран только архив. Для установщика поставьте Inno Setup 6 и запустите снова.' 'Yellow'
  }
}

Step 'Готово'
if ($Run) { Start-Process (Join-Path $out 'XatBox.exe') }
if (-not $NoOpen) { Start-Process explorer.exe $dist }
exit 0
