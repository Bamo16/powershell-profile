# Starship prompt. Its init script is cached, so startup runs no starship process at all.

$env:STARSHIP_CONFIG = Join-Path -Path $ProfileInfo.Root -ChildPath 'starship.toml'

# starship.toml shows the elevated segment when this is set. Checked once here, because a starship
# module that checks would start a process at every prompt.
$identity = [System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()
$env:PROMPT_ELEVATED = $null
if ($identity.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $env:PROMPT_ELEVATED = '1'
}

Remove-Variable -Name identity

# Searching PATH costs tens of milliseconds, so where starship was found last time is remembered.
$starshipLocation = Join-Path -Path $ProfileInfo.StateDirectory -ChildPath 'starship-path.txt'
$starship = Get-Content -LiteralPath $starshipLocation -TotalCount 1 -ErrorAction Ignore
if (-not $starship -or -not (Test-Path -LiteralPath $starship)) {
    $starship = Get-Command -Name starship -CommandType Application -ErrorAction Ignore |
        Select-Object -First 1 -ExpandProperty Source
    if ($starship) {
        $null = New-Item -ItemType Directory -Path $ProfileInfo.StateDirectory -Force
        Set-Content -LiteralPath $starshipLocation -Value $starship
    }
}

if ($starship) {
    # The continuation prompt comes from the config too, so either changing regenerates the script.
    $executableStamp = Get-FileStamp -LiteralPath $starship
    $configStamp = Get-FileStamp -LiteralPath $env:STARSHIP_CONFIG
    $starshipInit = Get-CachedScript -Name starship -Key "$executableStamp-$configStamp" -Generator {
        $init = (& $starship init powershell --print-full-init) -join "`n"
        $continuation = (& $starship prompt --continuation) -join ''

        # Starship renders the continuation prompt once per session by running itself; bake it in instead.
        # If a new starship changes this block, the pattern misses and the script works as before.
        $pattern = '(?s)Set-PSReadLineOption -ContinuationPrompt \(\s*Invoke-Native .*?"--continuation"\s*\)\s*\)'
        $literal = "Set-PSReadLineOption -ContinuationPrompt '$($continuation.Replace("'", "''"))'"
        [regex]::Replace($init, $pattern, { param($match) $literal })
    }

    if ($starshipInit) {
        . $starshipInit
    }

    Remove-Variable -Name executableStamp, configStamp, starshipInit
}

Remove-Variable -Name starship, starshipLocation
