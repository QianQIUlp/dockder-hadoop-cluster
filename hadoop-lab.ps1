[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $LabArgs
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashCandidates = @(@(
        (Get-Command bash.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    ) | Where-Object { $_ -and (Test-Path $_) })

if (-not $bashCandidates) {
    Write-Error @"
Hadoop Lab's cross-platform launcher needs Bash. Install Git for Windows, which
provides both Git and Bash, then reopen PowerShell. Docker Desktop is still the
only runtime dependency.
"@
}

$bash = $bashCandidates[0]
$script = (Join-Path $root 'hadoop-lab').Replace('\', '/')
& $bash $script @LabArgs
exit $LASTEXITCODE
