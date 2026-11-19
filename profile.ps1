<#
    Entry point, dot-sourced by the stub install.ps1 writes to $PROFILE.CurrentUserAllHosts for both
    pwsh and Windows PowerShell. This file, Core, Console and Prompt load in Windows PowerShell too, so
    they stay 5.1 compatible; the other parts load only in pwsh 7.6 and up.
#>

$Global:ProfileInfo = [pscustomobject]@{
    Root           = $PSScriptRoot
    StateDirectory = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'powershell-profile'
    Timings        = [System.Collections.Generic.List[pscustomobject]]::new()
    Deferred       = [System.Collections.Generic.List[scriptblock]]::new()
}

. (Join-Path -Path $PSScriptRoot -ChildPath 'src\Core.ps1')

# A script (pwsh -Command, -File, a redirected pipe) gets none of this: it would only slow it down.
# The VS Code PowerShell extension starts its host with -NonInteractive and loads profiles itself.
$isInteractive = $Host.Name -eq 'Visual Studio Code Host' -or (
    -not [Console]::IsOutputRedirected -and
    (Test-InteractiveSession -Arguments ([Environment]::GetCommandLineArgs())))
if (-not $isInteractive) {
    Remove-Variable -Name isInteractive

    return
}

# Windows PowerShell gets the prompt and line editing; the rest is written for pwsh 7.6 and up.
$parts = @('Console', 'Prompt')
if ($PSVersionTable.PSVersion -ge [version]'7.6') {
    $parts += 'Completion', 'Commands', 'Update'
}

# Dot-sourced here, not inside a helper, so what each part defines lands in the global scope.
foreach ($part in $parts) {
    $partTimer = [System.Diagnostics.Stopwatch]::StartNew()
    . (Join-Path -Path $ProfileInfo.Root -ChildPath "src\$part.ps1")
    Add-ProfileTiming -Name $part -Stopwatch $partTimer
}

Start-DeferredProfileWork
Remove-Variable -Name isInteractive, parts, part, partTimer
