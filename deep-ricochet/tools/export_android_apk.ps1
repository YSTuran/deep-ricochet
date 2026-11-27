[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [Parameter(Mandatory = $true)][ValidateSet('debug', 'release')][string]$Mode,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [int]$TimeoutSeconds = 420
)

$ErrorActionPreference = 'Stop'
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$pendingPath = "$OutputPath.pending.apk"
$stdoutPath = [System.IO.Path]::GetTempFileName()
$stderrPath = [System.IO.Path]::GetTempFileName()
$buildTools = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\35.0.1'
$apksigner = Join-Path $buildTools 'apksigner.bat'
$zipalign = Join-Path $buildTools 'zipalign.exe'
$process = $null
$completed = $false

if (-not (Test-Path -LiteralPath $apksigner) -or -not (Test-Path -LiteralPath $zipalign)) {
    throw 'Android build tools 35.0.1 were not found.'
}
Remove-Item -LiteralPath $pendingPath -Force -ErrorAction SilentlyContinue

try {
    $arguments = @(
        '--headless',
        '--path', ('"' + $ProjectPath + '"'),
        "--export-$Mode", 'Android',
        ('"' + $pendingPath + '"'),
        '--quit'
    )
    $process = Start-Process `
        -FilePath $GodotPath `
        -ArgumentList $arguments `
        -WorkingDirectory $ProjectPath `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -PassThru

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 750
        $stdout = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
        $combined = "$stdout`n$stderr"
        if ($combined -match '(?im)(^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|Invalid call\.)') {
            throw "Godot $Mode export failed: $($combined.TrimEnd())"
        }
        $plainStdout = $stdout -replace '\x1b\[[0-9;]*m', ''
        if ($plainStdout -match '\[ DONE \] export' -and (Test-Path -LiteralPath $pendingPath)) {
            & $apksigner verify --min-sdk-version 29 $pendingPath 2>$null | Out-Null
            $signatureValid = $LASTEXITCODE -eq 0
            if ($signatureValid) {
                & $zipalign -c -P 16 4 $pendingPath 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $completed = $true
                    break
                }
            }
        }
        $process.Refresh()
        if ($process.HasExited) {
            throw "Godot $Mode export exited before producing a valid APK (exit $($process.ExitCode)): $($combined.TrimEnd())"
        }
    }
    if (-not $completed) {
        throw "Godot $Mode export timed out after $TimeoutSeconds seconds."
    }
    Move-Item -LiteralPath $pendingPath -Destination $OutputPath -Force
    Write-Host "$Mode APK verified and updated: $OutputPath"
} finally {
    if ($process -ne $null) {
        $children = @(
            Get-CimInstance Win32_Process -Filter "ParentProcessId=$($process.Id)" `
                -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessId
        )
        $process.Refresh()
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
        if ($children.Count -gt 0) {
            Stop-Process -Id $children -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -LiteralPath $pendingPath, $stdoutPath, $stderrPath `
        -Force -ErrorAction SilentlyContinue
}
