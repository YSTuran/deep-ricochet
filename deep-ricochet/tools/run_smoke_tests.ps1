[CmdletBinding()]
param(
    [string]$GodotPath = "godot",
    [int]$QuitAfterIterations = 1800
)

$ErrorActionPreference = "Stop"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godotCommand = Get-Command $GodotPath -ErrorAction Stop
$godotExecutable = $godotCommand.Source

if ($QuitAfterIterations -le 0) {
    throw "QuitAfterIterations must be greater than zero."
}

$stdoutPath = [System.IO.Path]::GetTempFileName()
$stderrPath = [System.IO.Path]::GetTempFileName()
$arguments = @(
    "--headless",
    "--path", $projectPath,
    "--scene", "res://tests/smoke_test.tscn",
    "--quit-after", "$QuitAfterIterations"
)
$escapedArguments = foreach ($argument in $arguments) {
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
    $combinedOutput = "$stdout`n$stderr"

    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        Write-Host $stdout.TrimEnd()
    }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        Write-Host $stderr.TrimEnd()
    }
    if ($process.ExitCode -ne 0) {
        throw "Godot smoke tests exited with code $($process.ExitCode)."
    }

    $failurePattern = '(?im)(SCRIPT ERROR:|Parse Error:|Compile Error:|Assertion failed|Failed to load script|Invalid call\.)'
    if ($combinedOutput -match $failurePattern) {
        throw "Godot smoke tests reported a script or assertion error."
    }
    if ($combinedOutput -notmatch '(?m)^\[PASS\] Deep Ricochet ') {
        throw "Godot exited without the Deep Ricochet smoke-test PASS marker."
    }
    Write-Host "Smoke-test gate passed."
} finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
}
