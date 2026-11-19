# The enforceable part of the PowerShell style rules (coordination/rules/powershell-style.md).
# VS Code's PowerShell extension reads this through .vscode/settings.json; tests/Style.Tests.ps1 runs it,
# and also checks the files Windows PowerShell loads against 5.1.
@{
    Severity     = @('Error', 'Warning', 'Information')

    ExcludeRules = @(
        # The profile talks to the person at the console; that is what Write-Host is for.
        'PSAvoidUsingWriteHost'
        # Profile helpers are global by design, and Update-Profile is the one verb that changes state.
        'PSAvoidGlobalVars'
        'PSUseShouldProcessForStateChangingFunctions'
        # Blind to closures and to completers, whose parameters are positional and fixed.
        'PSReviewUnusedParameter'
    )

    Rules        = @{
        PSPlaceOpenBrace                   = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace                  = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSUseConsistentIndentation         = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
        PSUseConsistentWhitespace          = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            CheckSeparator                          = $true
            CheckParameter                          = $true
            # Hashtable values are aligned (PSAlignAssignmentStatement); the padding isn't a typo.
            IgnoreAssignmentOperatorInsideHashTable = $true
        }
        PSAlignAssignmentStatement         = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSUseCorrectCasing                 = @{
            Enable        = $true
            # PSScriptAnalyzer 1.25 throws checking some native command lines (NullReferenceException
            # in CommandInfo.Parameters), which silently skips the whole file. Keywords and operators only.
            CheckCommands = $false
            CheckKeyword  = $true
            CheckOperator = $true
        }
        PSAvoidLongLines                   = @{
            Enable            = $true
            MaximumLineLength = 115
        }
        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
        }
        PSUseCompatibleSyntax              = @{
            Enable         = $true
            TargetVersions = @('7.6')
        }
    }
}
