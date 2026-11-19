[CmdletBinding()]
param(
    [string]$GodotPath = "godot",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$expectedGodotVersion = "4.7.2"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godotCommand = Get-Command $GodotPath -ErrorAction Stop
$godotExecutable = $godotCommand.Source

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $projectPath "build\android\deep-ricochet-debug.apk"
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

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
        # Start-Process -Wait also waits for the persistent Gradle daemon that
        # Godot spawns. WaitForExit() tracks only the Godot process itself.
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
        return "$stdout`n$stderr"
    } finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Assert-NoGodotScriptErrors {
    param(
        [string]$Output,
        [string]$Stage
    )

    $failurePattern = '(?im)(^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|Invalid call\.)'
    if ($Output -match $failurePattern) {
        throw "$Stage reported a GDScript error."
    }
}

$versionOutput = Invoke-Godot @("--headless", "--version")
$versionLine = $versionOutput -split "`r?`n" |
    Where-Object { $_ -match '^\d+\.\d+\.\d+' } |
    Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($versionLine) -or -not $versionLine.StartsWith("$expectedGodotVersion.")) {
    throw "Godot $expectedGodotVersion is required; detected '$versionLine'."
}

$androidTemplate = Join-Path $projectPath "android\build\build.gradle"
$installBuildTemplate = -not (Test-Path -LiteralPath $androidTemplate)

Write-Host "Importing project resources..."
$importOutput = Invoke-Godot @("--headless", "--path", $projectPath, "--import")
Assert-NoGodotScriptErrors -Output $importOutput -Stage "Project import"

Write-Host "Running mandatory smoke-test gate..."
$smokeTestScript = Join-Path $PSScriptRoot "run_smoke_tests.ps1"
& $smokeTestScript -GodotPath $godotExecutable

Write-Host "Building ARM Android 10+ debug APK..."
$exportArguments = @(
    "--headless",
    "--path", $projectPath
)
if ($installBuildTemplate) {
    Write-Host "The Android Gradle build template will be installed during export..."
    $exportArguments += "--install-android-build-template"
}
$exportArguments += @("--export-debug", "Android", $OutputPath, "--quit")
$exportOutput = Invoke-Godot $exportArguments
Assert-NoGodotScriptErrors -Output $exportOutput -Stage "Android export"

if (-not (Test-Path -LiteralPath $OutputPath)) {
    throw "Godot reported success, but the APK was not created: $OutputPath"
}

$apk = Get-Item -LiteralPath $OutputPath
if ($apk.Length -le 0) {
    throw "The generated APK is empty: $OutputPath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($OutputPath)
try {
    $nativeLibraries = @(
        $archive.Entries |
            Where-Object { $_.FullName -match '^lib/[^/]+/[^/]+\.so$' } |
            ForEach-Object { $_.FullName }
    )
    $requiredLibraries = @(
        "lib/armeabi-v7a/libgodot_android.so",
        "lib/arm64-v8a/libgodot_android.so"
    )
    foreach ($requiredLibrary in $requiredLibraries) {
        if ($nativeLibraries -notcontains $requiredLibrary) {
            throw "The ARM APK is missing a required Godot library: $requiredLibrary"
        }
    }
    $supportedAbis = @("armeabi-v7a", "arm64-v8a")
    $unexpectedLibraries = @(
        $nativeLibraries | Where-Object {
            $abi = ($_.Split('/'))[1]
            $supportedAbis -notcontains $abi
        }
    )
    if ($unexpectedLibraries.Count -gt 0) {
        throw "The ARM APK contains unexpected ABIs: $($unexpectedLibraries -join ', ')"
    }
} finally {
    $archive.Dispose()
}

Write-Host "APK ready: $($apk.FullName) ($([math]::Round($apk.Length / 1MB, 1)) MB)"
