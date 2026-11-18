BeforeDiscovery {
    $root = Split-Path -Path $PSScriptRoot
    $scripts = Get-ChildItem -LiteralPath $root -Recurse -Include *.ps1, *.psd1 -File |
        ForEach-Object -Process { @{ Name = $_.FullName.Substring($root.Length + 1); Path = $_.FullName } }

    # What Windows PowerShell loads or runs: the entry point, these parts, and the bootstrap.
    $windowsPowerShellScripts = @(
        'profile.ps1', 'bootstrap.ps1', 'src\Core.ps1', 'src\Console.ps1', 'src\Prompt.ps1'
    ) | ForEach-Object -Process { @{ Name = $_; Path = Join-Path -Path $root -ChildPath $_ } }
}

BeforeAll {
    $settings = Join-Path -Path (Split-Path -Path $PSScriptRoot) -ChildPath 'PSScriptAnalyzerSettings.psd1'
}

Describe 'Style' {
    It '<Name> follows the analyzer settings' -ForEach $scripts {
        # Pester's BeforeAll and BeforeDiscovery hand variables to later blocks, which the analyzer can't see.
        $excluded = @(if ($Name -like 'tests\*') { 'PSUseDeclaredVarsMoreThanAssignments' })
        # Stop: an analyzer crash is otherwise only a printed error, and the file goes unchecked.
        Invoke-ScriptAnalyzer -Path $Path -Settings $settings -ExcludeRule $excluded -ErrorAction Stop |
            ForEach-Object -Process { "line $($_.Line): $($_.RuleName) $($_.Message)" } |
            Should -BeNullOrEmpty
    }

    It '<Name> is formatted' -ForEach $scripts {
        $text = [System.IO.File]::ReadAllText($Path)
        Invoke-Formatter -ScriptDefinition $text -Settings $settings | Should -BeExactly $text
    }

    It '<Name> runs on Windows PowerShell 5.1' -ForEach $windowsPowerShellScripts {
        Invoke-ScriptAnalyzer -Path $Path -IncludeRule PSUseCompatibleSyntax -Settings @{
            Rules = @{ PSUseCompatibleSyntax = @{ Enable = $true; TargetVersions = @('5.1') } }
        } | ForEach-Object -Process { "line $($_.Line): $($_.Message)" } | Should -BeNullOrEmpty
    }

    # Windows PowerShell reads a file without a BOM as ANSI, which only ASCII survives unchanged.
    It '<Name> is ASCII' -ForEach $windowsPowerShellScripts {
        [System.IO.File]::ReadAllBytes($Path) | Where-Object -FilterScript { $_ -gt 127 } | Should -BeNullOrEmpty
    }
}
