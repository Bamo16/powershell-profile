# Tab completion for command-line tools. Registering a stand-in costs nothing; each real completer
# loads on that command's first Tab. A tool that isn't installed just never completes.

function Register-GeneratedCompleter {
    <#
    .SYNOPSIS
        Completes a tool that prints its own PowerShell completion script, cached until the tool's
        executable changes.
    .EXAMPLE
        Register-GeneratedCompleter -CommandName gh -GenerateArguments completion, -s, powershell
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [string[]]$GenerateArguments
    )

    Register-LazyCompleter -CommandName $CommandName -Loader {
        $executable = Get-Command -Name $CommandName -CommandType Application -ErrorAction Ignore |
            Select-Object -First 1
        if (-not $executable) {
            return
        }

        $path = $executable.Source
        # Cobra's scripts (gh) put 2>&1 on Invoke-Expression, which doesn't reach the tool it runs, so
        # 'Completion ended with directive' lands on the console at every Tab. Redirect inside instead.
        $script = Get-CachedScript -Name $CommandName -Key (Get-FileStamp -LiteralPath $path) -Generator {
            & $path @GenerateArguments | ForEach-Object -Process {
                $_.Replace('-OutVariable out "$RequestComp" 2>&1', '-OutVariable out "$RequestComp 2>`$null"')
            }
        }
        if ($script) {
            Import-CompletionScript -LiteralPath $script
        }
    }.GetNewClosure()
}


function Import-CompletionScript {
    <#
    .SYNOPSIS
        Runs a completion script as an in-memory module, so the state its completer reads lives as long
        as the completer does.
    .DESCRIPTION
        Cobra's scripts (gh) keep helper functions and $ShellCompDirective* variables at script level.
        Dot-sourced from a loader, those die with the loader's scope and every completion comes back empty.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    $body = [scriptblock]::Create([System.IO.File]::ReadAllText($LiteralPath))
    $null = New-Module -Name ([System.IO.Path]::GetFileNameWithoutExtension($LiteralPath)) -ScriptBlock $body
}


Register-GeneratedCompleter -CommandName gh -GenerateArguments completion, -s, powershell
Register-GeneratedCompleter -CommandName uv -GenerateArguments generate-shell-completion, powershell

# dotnet's script comes from the SDK, not dotnet.exe, so it is keyed on the newest SDK installed.
Register-LazyCompleter -CommandName dotnet -Loader {
    $dotnet = Get-Command -Name dotnet -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if (-not $dotnet) {
        return
    }

    $sdkDirectory = Join-Path -Path (Split-Path -Path $dotnet.Source) -ChildPath 'sdk'
    $newestSdk = Get-ChildItem -LiteralPath $sdkDirectory -Directory -ErrorAction Ignore |
        Sort-Object -Property LastWriteTimeUtc |
        Select-Object -Last 1
    if ($newestSdk) {
        $key = '{0}-{1:x}' -f $newestSdk.Name, $newestSdk.LastWriteTimeUtc.Ticks
        $script = Get-CachedScript -Name dotnet -Key $key -Generator { & $dotnet.Source completions script pwsh }
        if ($script) {
            Import-CompletionScript -LiteralPath $script

            return
        }
    }

    # SDKs before 10 have no completion script, so ask dotnet itself on every Tab.
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object -Process {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

Register-LazyCompleter -CommandName git, tgit, gitk -Loader {
    Import-Module -Name posh-git -Global -ErrorAction Ignore
}

# winget answers completions itself on each Tab, so there is nothing to load or cache.
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $word = $wordToComplete.Replace('"', '""')
    $line = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$word" --commandline "$line" --position $cursorPosition | ForEach-Object -Process {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

if ($env:ChocolateyInstall) {
    Register-LazyCompleter -CommandName choco -Loader {
        Import-Module -Name "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1" -Global -ErrorAction Ignore
    }

    function Update-SessionEnvironment {
        <#
        .SYNOPSIS
            Reloads PATH and other environment variables from the registry (Chocolatey's refreshenv).
        .DESCRIPTION
            Stands in for Chocolatey's own command until the first call, which imports Chocolatey's
            module; its version then replaces this one.
        #>
        [CmdletBinding()]
        param()

        Import-Module -Name "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1" -Global
        Microsoft.PowerShell.Core\Get-Command -Name Update-SessionEnvironment -Module chocolateyProfile |
            ForEach-Object -Process { & $_ }
    }

    Set-Alias -Name refreshenv -Value Update-SessionEnvironment
}
