# Helpers the rest of the profile is built on. Loaded even by scripts, so keep it to definitions.

function Test-InteractiveSession {
    <#
    .SYNOPSIS
        Tells from the host's command line whether this session will show a prompt.
    .DESCRIPTION
        pwsh and powershell.exe accept any unambiguous prefix of a parameter name, so -c, -com and
        -Command are the same. -NoExit before a -Command keeps the session interactive, which is how
        VS Code starts its terminal.
    .EXAMPLE
        Test-InteractiveSession -Arguments ([Environment]::GetCommandLineArgs())
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The full command line, executable first, as [Environment]::GetCommandLineArgs() returns it.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Arguments
    )

    $valueParameters = @(
        'executionpolicy', 'ep', 'workingdirectory', 'wd', 'windowstyle', 'inputformat', 'outputformat'
        'configurationname', 'configurationfile', 'settingsfile', 'custompipename', 'psconsolefile', 'version'
    )
    $noExit = $false
    $skipValue = $false

    foreach ($argument in $Arguments | Select-Object -Skip 1) {
        if ($skipValue) {
            $skipValue = $false
            continue
        }

        # A bare argument is a script file to run, and so is '-' (read commands from standard input).
        if ($argument -notmatch '^[-/](?<Name>[a-z]+)$') {
            return $noExit
        }

        $name = $Matches.Name.ToLowerInvariant()
        if ($name.Length -ge 3 -and 'noexit'.StartsWith($name)) {
            $noExit = $true
        } elseif ($name.Length -ge 4 -and 'noninteractive'.StartsWith($name)) {
            return $false
        } elseif ('command'.StartsWith($name) -or 'file'.StartsWith($name) -or
            'encodedcommand'.StartsWith($name) -or $name -eq 'ec') {
            return $noExit
        } elseif ($valueParameters | Where-Object -FilterScript { $_.StartsWith($name) }) {
            $skipValue = $true
        }
    }

    $true
}


function Add-ProfileTiming {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [System.Diagnostics.Stopwatch]$Stopwatch
    )

    $ProfileInfo.Timings.Add([pscustomobject]@{
            Part = $Name
            Milliseconds = [math]::Round($Stopwatch.Elapsed.TotalMilliseconds, 1)
        })
}


function Get-FileStamp {
    <#
    .SYNOPSIS
        A short key that changes whenever a file is replaced, for naming cached output generated from it.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    $file = Get-Item -LiteralPath $LiteralPath
    '{0:x}-{1:x}' -f $file.LastWriteTimeUtc.Ticks, $file.Length
}


function Get-CachedScript {
    <#
    .SYNOPSIS
        Returns the path of a cached script, running Generator to create it when Key has changed.
    .DESCRIPTION
        For tools that print their own init or completion script (starship, dotnet, gh, uv). Running
        the tool costs a process start every time; reading its output from disk does not. Key should
        change when the tool does, so the cache regenerates exactly when it is stale.
    .EXAMPLE
        . (Get-CachedScript -Name gh -Key (Get-FileStamp $gh) -Generator { gh completion -s powershell })
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Key,

        # Writes the script's lines to the pipeline. A non-zero exit code or no output means failure.
        [Parameter(Mandatory)]
        [scriptblock]$Generator
    )

    $directory = Join-Path -Path $ProfileInfo.StateDirectory -ChildPath 'cache'
    $path = Join-Path -Path $directory -ChildPath "$Name-$Key.ps1"
    if (Test-Path -LiteralPath $path) {
        return $path
    }

    $Global:LASTEXITCODE = 0
    $lines = [string[]](& $Generator)
    if ($LASTEXITCODE -or -not $lines) {
        Write-Warning -Message "Profile: generating the $Name script failed (exit code $LASTEXITCODE)."

        return
    }

    $null = New-Item -ItemType Directory -Path $directory -Force
    Get-ChildItem -LiteralPath $directory -Filter "$Name-*.ps1" | Remove-Item
    # With a BOM, so Windows PowerShell reads it as UTF-8 too.
    [System.IO.File]::WriteAllLines($path, $lines, [System.Text.UTF8Encoding]::new($true))
    $path
}


function Register-LazyCompleter {
    <#
    .SYNOPSIS
        Registers a stand-in completer that runs Loader on the first Tab, then hands over to whatever
        completer Loader registered.
    .DESCRIPTION
        Completion scripts can run to hundreds of kilobytes; loading them all at startup costs time
        on every launch for commands you may not complete in that session.
    .EXAMPLE
        Register-LazyCompleter -CommandName git -Loader { Import-Module -Name posh-git -Global }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$CommandName,

        # Must register the real completer for every name in CommandName.
        [Parameter(Mandatory)]
        [scriptblock]$Loader
    )

    $state = @{ Loaded = $false }
    $stub = {
        param($wordToComplete, $commandAst, $cursorPosition)

        # Asked again after loading means Loader registered nothing; stop rather than recurse.
        if ($state.Loaded) {
            return
        }

        $state.Loaded = $true
        & $Loader
        $line = $commandAst.Extent.StartScriptPosition.GetFullScript()
        (TabExpansion2 -inputScript $line -cursorColumn $cursorPosition).CompletionMatches
    }.GetNewClosure()

    foreach ($name in $CommandName) {
        Register-ArgumentCompleter -Native -CommandName $name -ScriptBlock $stub
    }
}


function Invoke-WhenIdle {
    <#
    .SYNOPSIS
        Queues work to run once the first prompt is up and the keyboard has been idle for a moment.
    #>
    [CmdletBinding()]
    param(
        # Runs in its own scope: import modules with -Global.
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $ProfileInfo.Deferred.Add($ScriptBlock)
}


function Start-DeferredProfileWork {
    [CmdletBinding()]
    param()

    if ($ProfileInfo.Deferred.Count -eq 0) {
        return
    }

    # PSReadLine raises OnIdle while it waits for a key, so this runs after the prompt has drawn.
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ($work in $ProfileInfo.Deferred) {
            try {
                & $work
            } catch {
                Write-Warning -Message "Profile: deferred work failed: $_"
            }
        }

        $ProfileInfo.Deferred.Clear()
        Add-ProfileTiming -Name 'Deferred (after prompt)' -Stopwatch $timer
    }
}
