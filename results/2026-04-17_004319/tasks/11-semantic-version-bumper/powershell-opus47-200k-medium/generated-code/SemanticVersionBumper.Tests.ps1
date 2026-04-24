#Requires -Modules Pester

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1'
    Get-Module SemanticVersionBumper | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking
    $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Get-CurrentVersion' {
    BeforeEach {
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
    }
    AfterEach { Remove-Item -Recurse -Force -LiteralPath $script:tmp }

    It 'reads the version from package.json' {
        $p = Join-Path $script:tmp 'package.json'
        '{"name":"x","version":"1.2.3"}' | Set-Content -LiteralPath $p -NoNewline
        Get-CurrentVersion -PackageJsonPath $p | Should -Be '1.2.3'
    }
    It 'throws if file missing' {
        { Get-CurrentVersion -PackageJsonPath (Join-Path $script:tmp 'nope.json') } |
            Should -Throw '*not found*'
    }
    It 'throws on invalid JSON' {
        $p = Join-Path $script:tmp 'package.json'
        'not json{' | Set-Content -LiteralPath $p -NoNewline
        { Get-CurrentVersion -PackageJsonPath $p } | Should -Throw '*Invalid JSON*'
    }
    It 'throws on bad semver' {
        $p = Join-Path $script:tmp 'package.json'
        '{"version":"bad"}' | Set-Content -LiteralPath $p -NoNewline
        { Get-CurrentVersion -PackageJsonPath $p } | Should -Throw '*Invalid semantic*'
    }
}

Describe 'Get-BumpType' {
    It 'returns none for empty commits' {
        Get-BumpType -Commits @() | Should -Be 'none'
    }
    It 'returns patch for fix' {
        Get-BumpType -Commits @('fix: a bug') | Should -Be 'patch'
    }
    It 'returns minor for feat' {
        Get-BumpType -Commits @('feat: new thing', 'fix: x') | Should -Be 'minor'
    }
    It 'returns major for ! breaking marker' {
        Get-BumpType -Commits @('feat!: big', 'fix: x') | Should -Be 'major'
    }
    It 'returns major for BREAKING CHANGE footer' {
        $c = "feat: thing`n`nBREAKING CHANGE: removed Y"
        Get-BumpType -Commits @($c) | Should -Be 'major'
    }
    It 'handles scope in type' {
        Get-BumpType -Commits @('feat(core): hi') | Should -Be 'minor'
        Get-BumpType -Commits @('fix(api): hi') | Should -Be 'patch'
    }
}

Describe 'Get-NextVersion' {
    It 'bumps patch' { Get-NextVersion '1.2.3' 'patch' | Should -Be '1.2.4' }
    It 'bumps minor' { Get-NextVersion '1.2.3' 'minor' | Should -Be '1.3.0' }
    It 'bumps major' { Get-NextVersion '1.2.3' 'major' | Should -Be '2.0.0' }
    It 'no bump returns same' { Get-NextVersion '1.2.3' 'none' | Should -Be '1.2.3' }
    It 'throws on invalid input' { { Get-NextVersion 'bad' 'patch' } | Should -Throw }
}

Describe 'Update-VersionFile' {
    BeforeEach {
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
        $script:p = Join-Path $script:tmp 'package.json'
        '{"name":"x","version":"1.2.3","description":"y"}' | Set-Content -LiteralPath $script:p -NoNewline
    }
    AfterEach { Remove-Item -Recurse -Force -LiteralPath $script:tmp }

    It 'writes the new version preserving other fields' {
        Update-VersionFile -PackageJsonPath $script:p -NewVersion '2.0.0'
        $obj = Get-Content -LiteralPath $script:p -Raw | ConvertFrom-Json
        $obj.version | Should -Be '2.0.0'
        $obj.name | Should -Be 'x'
        $obj.description | Should -Be 'y'
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups features and fixes' {
        $entry = New-ChangelogEntry -Version '1.1.0' -Date '2025-01-01' -Commits @(
            'feat: add widgets',
            'fix: nil crash'
        )
        $entry | Should -Match '## \[1.1.0\] - 2025-01-01'
        $entry | Should -Match '### Features'
        $entry | Should -Match 'add widgets'
        $entry | Should -Match '### Fixes'
        $entry | Should -Match 'nil crash'
    }
    It 'emits BREAKING CHANGES section' {
        $entry = New-ChangelogEntry -Version '2.0.0' -Date '2025-01-01' -Commits @('feat!: drop X')
        $entry | Should -Match '### BREAKING CHANGES'
    }
}

Describe 'Invoke-VersionBump end-to-end' {
    BeforeEach {
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
        $script:p = Join-Path $script:tmp 'package.json'
        '{"name":"x","version":"1.1.0"}' | Set-Content -LiteralPath $script:p -NoNewline
        $script:cl = Join-Path $script:tmp 'CHANGELOG.md'
    }
    AfterEach { Remove-Item -Recurse -Force -LiteralPath $script:tmp }

    It 'bumps minor on feat and writes changelog' {
        $r = Invoke-VersionBump -PackageJsonPath $script:p -ChangelogPath $script:cl `
            -Commits @('feat: cool', 'fix: bug')
        $r.NewVersion | Should -Be '1.2.0'
        $r.BumpType | Should -Be 'minor'
        (Get-Content -LiteralPath $script:p -Raw) | Should -Match '"version":"1.2.0"'
        (Get-Content -LiteralPath $script:cl -Raw) | Should -Match '1.2.0'
    }
    It 'bumps major on BREAKING' {
        $r = Invoke-VersionBump -PackageJsonPath $script:p -ChangelogPath $script:cl `
            -Commits @('feat!: rewrite api')
        $r.NewVersion | Should -Be '2.0.0'
    }
    It 'no commits -> no bump' {
        $r = Invoke-VersionBump -PackageJsonPath $script:p -ChangelogPath $script:cl -Commits @()
        $r.NewVersion | Should -Be '1.1.0'
        $r.BumpType | Should -Be 'none'
        Test-Path $script:cl | Should -Be $false
    }
}

Describe 'Fixtures' {
    It 'fixture: feat-only-commits.txt -> minor' {
        $file = Join-Path $script:FixturesDir 'feat-only-commits.txt'
        Test-Path $file | Should -Be $true
        $commits = Get-Content -LiteralPath $file -Raw -Encoding UTF8 -ErrorAction Stop
        $arr = $commits -split "(?m)^---$" | Where-Object { $_.Trim() -ne '' }
        Get-BumpType -Commits $arr | Should -Be 'minor'
    }
    It 'fixture: breaking-commits.txt -> major' {
        $file = Join-Path $script:FixturesDir 'breaking-commits.txt'
        $commits = Get-Content -LiteralPath $file -Raw -Encoding UTF8
        $arr = $commits -split "(?m)^---$" | Where-Object { $_.Trim() -ne '' }
        Get-BumpType -Commits $arr | Should -Be 'major'
    }
    It 'fixture: fix-only-commits.txt -> patch' {
        $file = Join-Path $script:FixturesDir 'fix-only-commits.txt'
        $commits = Get-Content -LiteralPath $file -Raw -Encoding UTF8
        $arr = $commits -split "(?m)^---$" | Where-Object { $_.Trim() -ne '' }
        Get-BumpType -Commits $arr | Should -Be 'patch'
    }
}
