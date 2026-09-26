param(
    [Parameter(Mandatory = $true)][string]$FlutterSdk,
    [Parameter(Mandatory = $true)][string]$AndroidSdk,
    [Parameter(Mandatory = $true)][string]$JavaHome,
    [Parameter(Mandatory = $true)][string]$SigningDirectory,
    [string]$BuildName = '0.1.0',
    [ValidateRange(1, 2100000000)][int]$BuildNumber = 2
)

$ErrorActionPreference = 'Stop'
$flutter = Join-Path $FlutterSdk 'bin/flutter.bat'
$keystore = Join-Path $SigningDirectory 'finni-release.jks'
$passwordFile = Join-Path $SigningDirectory 'password.dpapi'
foreach ($required in @($flutter, $keystore, $passwordFile, (Join-Path $JavaHome 'bin/java.exe'))) {
    if (!(Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing local dependency: $required"
    }
}
if (!(Test-Path -LiteralPath $AndroidSdk -PathType Container)) {
    throw 'Android SDK directory does not exist.'
}

$names = @('JAVA_HOME', 'ANDROID_HOME', 'FINNI_KEYSTORE', 'FINNI_STORE_PASSWORD', 'FINNI_KEY_ALIAS')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$secretPointer = [IntPtr]::Zero
Push-Location (Join-Path $PSScriptRoot '..')
try {
    $secure = Get-Content -LiteralPath $passwordFile -Raw | ConvertTo-SecureString
    $secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $env:FINNI_STORE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
    $env:FINNI_KEYSTORE = (Resolve-Path -LiteralPath $keystore).Path
    $env:FINNI_KEY_ALIAS = 'finni-release'
    $env:JAVA_HOME = (Resolve-Path -LiteralPath $JavaHome).Path
    $env:ANDROID_HOME = (Resolve-Path -LiteralPath $AndroidSdk).Path
    & $flutter build apk --release --no-pub --target lib/main.dart --build-name $BuildName --build-number $BuildNumber
    if ($LASTEXITCODE -ne 0) { throw "Release build failed (exit $LASTEXITCODE)." }
} finally {
    if ($secretPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    }
    foreach ($name in $names) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
    Pop-Location
}
