BeforeAll {
    $Global:ProfileInfo = [pscustomobject]@{
        Root           = Split-Path -Path $PSScriptRoot
        StateDirectory = Join-Path -Path $TestDrive -ChildPath 'state'
        Timings        = [System.Collections.Generic.List[pscustomobject]]::new()
        Deferred       = [System.Collections.Generic.List[scriptblock]]::new()
    }
    . (Join-Path -Path $ProfileInfo.Root -ChildPath 'src\Core.ps1')
}

Describe 'Test-InteractiveSession' {
    It 'Is interactive for <Case>' -ForEach @(
        @{ Case = 'a bare launch'; Arguments = @('pwsh.exe') }
        @{ Case = 'switches only'; Arguments = @('pwsh.exe', '-NoLogo', '-NoProfileLoadTime') }
        @{ Case = "VS Code's terminal"; Arguments = @('pwsh.exe', '-noexit', '-command', 'try { . x } catch {}') }
        @{ Case = 'an abbreviated -NoExit'; Arguments = @('pwsh.exe', '-noe', '-c', 'exit') }
        @{ Case = 'a value-taking parameter'; Arguments = @('pwsh.exe', '-ExecutionPolicy', 'Bypass') }
        @{ Case = 'a Windows Terminal profile'; Arguments = @('pwsh.exe', '-WorkingDirectory', '~') }
    ) {
        Test-InteractiveSession -Arguments $Arguments | Should -BeTrue
    }

    It 'Is not interactive for <Case>' -ForEach @(
        @{ Case = '-Command'; Arguments = @('pwsh.exe', '-Command', 'Get-Date') }
        @{ Case = '-c'; Arguments = @('pwsh.exe', '-NoProfile', '-c', 'exit') }
        @{ Case = '-File'; Arguments = @('pwsh.exe', '-File', 'script.ps1') }
        @{ Case = 'a bare script path'; Arguments = @('pwsh.exe', 'script.ps1') }
        @{ Case = 'reading standard input'; Arguments = @('pwsh.exe', '-') }
        @{ Case = '-EncodedCommand'; Arguments = @('pwsh.exe', '-ec', 'ZQB4AGkAdAA=') }
        @{ Case = '-NonInteractive'; Arguments = @('pwsh.exe', '-NonInteractive') }
        @{ Case = 'a script after a parameter value'; Arguments = @('pwsh.exe', '-ep', 'Bypass', '-f', 'a.ps1') }
    ) {
        Test-InteractiveSession -Arguments $Arguments | Should -BeFalse
    }
}

Describe 'Get-CachedScript' {
    BeforeEach {
        Remove-Item -LiteralPath $ProfileInfo.StateDirectory -Recurse -Force -ErrorAction Ignore
        $script:generated = 0
    }

    It 'Generates once and then reads the cache' {
        $generator = { $script:generated++; 'Set-Variable -Name cachedValue -Value 42' }

        $first = Get-CachedScript -Name tool -Key one -Generator $generator
        $second = Get-CachedScript -Name tool -Key one -Generator $generator

        $second | Should -Be $first
        $script:generated | Should -Be 1
        . $first
        $cachedValue | Should -Be 42
    }

    It 'Replaces the stale script when the key changes' {
        $old = Get-CachedScript -Name tool -Key one -Generator { 'old' }
        $new = Get-CachedScript -Name tool -Key two -Generator { 'new' }

        $old | Should -Not -Exist
        Get-Content -LiteralPath $new | Should -Be 'new'
    }

    It 'Caches nothing when the generator fails' {
        $path = Get-CachedScript -Name tool -Key one -Generator { cmd.exe /c 'echo partial & exit 3' } 3>$null

        $path | Should -BeNullOrEmpty
        Join-Path -Path $ProfileInfo.StateDirectory -ChildPath 'cache\tool-one.ps1' | Should -Not -Exist
    }
}

Describe 'Register-LazyCompleter' {
    It 'Loads on the first Tab and returns the real completions' {
        $script:loads = 0
        Register-LazyCompleter -CommandName lazy-tool -Loader {
            $script:loads++
            Register-ArgumentCompleter -Native -CommandName lazy-tool -ScriptBlock {
                param($wordToComplete)

                'alpha', 'beta' | Where-Object -FilterScript { $_ -like "$wordToComplete*" } |
                    ForEach-Object -Process { [System.Management.Automation.CompletionResult]::new($_) }
            }
        }

        $first = (TabExpansion2 -inputScript 'lazy-tool b' -cursorColumn 11).CompletionMatches.CompletionText
        $second = (TabExpansion2 -inputScript 'lazy-tool a' -cursorColumn 11).CompletionMatches.CompletionText

        $first | Should -Be 'beta'
        $second | Should -Be 'alpha'
        $script:loads | Should -Be 1
    }

    It 'Returns nothing, without recursing, when the loader registers no completer' {
        Register-LazyCompleter -CommandName broken-tool -Loader { }

        (TabExpansion2 -inputScript 'broken-tool x' -cursorColumn 13).CompletionMatches.CompletionText |
            Where-Object -FilterScript { $_ -like 'broken*' } | Should -BeNullOrEmpty
    }
}
