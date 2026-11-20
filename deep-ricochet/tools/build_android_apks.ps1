[CmdletBinding()]
param(
    [string]$GodotPath = "godot",
    [string]$DebugOutput = "",
    [string]$ReleaseOutput = ""
)

$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godotCommand = Get-Command $GodotPath -ErrorAction Stop
$godotExecutable = $godotCommand.Source
$androidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$buildTools = Join-Path $androidSdk "build-tools\35.0.1"
$apksigner = Join-Path $buildTools "apksigner.bat"
$zipalign = Join-Path $buildTools "zipalign.exe"

if ([string]::IsNullOrWhiteSpace($DebugOutput)) {
    $DebugOutput = Join-Path $projectPath "build\android\deep-ricochet-debug.apk"
}
if ([string]::IsNullOrWhiteSpace($ReleaseOutput)) {
    $ReleaseOutput = Join-Path $projectPath "build\android\deep-ricochet-release.apk"
}
$DebugOutput = [System.IO.Path]::GetFullPath($DebugOutput)
$ReleaseOutput = [System.IO.Path]::GetFullPath($ReleaseOutput)
New-Item -ItemType Directory -Path (Split-Path -Parent $DebugOutput) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $ReleaseOutput) -Force | Out-Null

function Invoke-Godot {
    param([string[]]$Arguments)

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    $escapedArguments = foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            '"{0}"' -f $argument.Replace('"', '\"')
        } else {
            $argument
        }
    }
    try {
        $process = Start-Process `
            -FilePath $godotExecutable `
            -ArgumentList $escapedArguments `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -WindowStyle Hidden `
            -PassThru
        $process.WaitForExit()
        $stdout = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($stdout)) {
            Write-Host $stdout.TrimEnd()
        }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            Write-Host $stderr.TrimEnd()
        }
        if ($process.ExitCode -ne 0) {
            throw "Godot exited with code $($process.ExitCode)."
        }
        $combined = "$stdout`n$stderr"
        if ($combined -match '(?im)(^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|Invalid call\.)') {
            throw "Godot export reported a script or resource error."
        }
    } finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Assert-Apk {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label APK was not created: $Path"
    }
    $apk = Get-Item -LiteralPath $Path
    if ($apk.Length -le 0) {
        throw "$Label APK is empty: $Path"
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $nativeLibraries = @(
            $archive.Entries |
                Where-Object { $_.FullName -match '^lib/[^/]+/[^/]+\.so$' } |
                ForEach-Object { $_.FullName }
        )
        foreach ($requiredLibrary in @(
            "lib/armeabi-v7a/libgodot_android.so",
            "lib/arm64-v8a/libgodot_android.so"
        )) {
            if ($nativeLibraries -notcontains $requiredLibrary) {
                throw "$Label APK is missing $requiredLibrary."
            }
        }
        $unexpectedLibraries = @(
            $nativeLibraries | Where-Object {
                ($_.Split('/'))[1] -notin @("armeabi-v7a", "arm64-v8a")
            }
        )
        if ($unexpectedLibraries.Count -gt 0) {
            throw "$Label APK contains unexpected ABIs: $($unexpectedLibraries -join ', ')"
        }
    } finally {
        $archive.Dispose()
    }

    if (-not (Test-Path -LiteralPath $apksigner)) {
        throw "apksigner was not found: $apksigner"
    }
    if (-not (Test-Path -LiteralPath $zipalign)) {
        throw "zipalign was not found: $zipalign"
    }
    & $zipalign -c -P 16 4 $Path
    if ($LASTEXITCODE -ne 0) {
        throw "$Label APK failed zipalign verification."
    }
    & $apksigner verify --verbose --min-sdk-version 29 $Path
    if ($LASTEXITCODE -ne 0) {
        throw "$Label APK signature verification failed."
    }
    Write-Host "$Label APK ready: $($apk.FullName) ($([math]::Round($apk.Length / 1MB, 1)) MB)"
}

Write-Host "Building and validating the Android 10+ debug APK..."
& (Join-Path $PSScriptRoot "build_android_debug.ps1") `
    -GodotPath $godotExecutable `
    -OutputPath $DebugOutput

$releaseKeystore = $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH
$releaseUser = $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER
$releasePassword = $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
if ([string]::IsNullOrWhiteSpace($releaseKeystore)) {
    $releaseKeystore = Join-Path $env:APPDATA "Godot\keystores\debug.keystore"
    $releaseUser = "androiddebugkey"
    $releasePassword = "android"
    Write-Warning "No production release keystore was supplied. The release APK will use the local debug key and is intended only for direct device testing."
}
if (-not (Test-Path -LiteralPath $releaseKeystore)) {
    throw "Release keystore was not found: $releaseKeystore"
}
if ([string]::IsNullOrWhiteSpace($releaseUser) -or [string]::IsNullOrWhiteSpace($releasePassword)) {
    throw "Release keystore user and password are required."
}

$previousReleasePath = $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH
$previousReleaseUser = $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER
$previousReleasePassword = $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
try {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $releaseKeystore
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $releaseUser
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $releasePassword
    Write-Host "Building the optimized Android 10+ release APK..."
    Invoke-Godot @(
        "--headless",
        "--path", $projectPath,
        "--export-release", "Android", $ReleaseOutput,
        "--quit"
    )
} finally {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $previousReleasePath
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $previousReleaseUser
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $previousReleasePassword
}

Assert-Apk -Path $DebugOutput -Label "Debug"
Assert-Apk -Path $ReleaseOutput -Label "Release"

$debugHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $DebugOutput).Hash
$releaseHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ReleaseOutput).Hash
Write-Host "Debug SHA-256:   $debugHash"
Write-Host "Release SHA-256: $releaseHash"
