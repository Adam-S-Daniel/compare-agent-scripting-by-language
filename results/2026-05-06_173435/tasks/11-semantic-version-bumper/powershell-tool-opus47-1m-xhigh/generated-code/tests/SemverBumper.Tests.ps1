# Pester tests for the SemverBumper module.
#
# Tests are organized one Describe block per public function, following the
# red/green TDD cycle: each section was written before the corresponding
# implementation in src/SemverBumper.psm1.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'SemverBumper.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Get-CurrentVersion' {

    BeforeEach {
        # Each test gets a fresh temp directory so reads/writes don't collide.
        $script:TestDir = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
    }

    It 'reads a plain VERSION file' {
        $vf = Join-Path $script:TestDir 'VERSION'
        Set-Content -Path $vf -Value '1.2.3' -NoNewline

        $version = Get-CurrentVersion -Path $vf

        $version | Should -Be '1.2.3'
    }

    It 'trims whitespace and trailing newlines from VERSION' {
        $vf = Join-Path $script:TestDir 'VERSION'
        Set-Content -Path $vf -Value "  4.5.6`r`n"

        Get-CurrentVersion -Path $vf | Should -Be '4.5.6'
    }

    It 'reads the version field from a package.json' {
        $pj = Join-Path $script:TestDir 'package.json'
        @{ name = 'demo'; version = '0.7.1' } | ConvertTo-Json | Set-Content -Path $pj

        Get-CurrentVersion -Path $pj | Should -Be '0.7.1'
    }

    It 'throws a meaningful error when the file does not exist' {
        { Get-CurrentVersion -Path (Join-Path $script:TestDir 'missing.txt') } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws when the version string is not valid semver' {
        $vf = Join-Path $script:TestDir 'VERSION'
        Set-Content -Path $vf -Value 'banana' -NoNewline

        { Get-CurrentVersion -Path $vf } | Should -Throw -ExpectedMessage '*not a valid semantic version*'
    }

    It 'throws when package.json has no version field' {
        $pj = Join-Path $script:TestDir 'package.json'
        @{ name = 'demo' } | ConvertTo-Json | Set-Content -Path $pj

        { Get-CurrentVersion -Path $pj } | Should -Throw -ExpectedMessage '*version*'
    }
}

Describe 'Get-ConventionalCommits' {

    It 'parses a single feat commit' {
        $log = "feat: add login page"
        $commits = Get-ConventionalCommits -Text $log

        $commits | Should -HaveCount 1
        $commits[0].Type | Should -Be 'feat'
        $commits[0].Scope | Should -BeNullOrEmpty
        $commits[0].IsBreaking | Should -BeFalse
        $commits[0].Description | Should -Be 'add login page'
    }

    It 'parses scope and breaking marker' {
        $log = "feat(auth)!: rotate session token format"
        $commits = Get-ConventionalCommits -Text $log

        $commits[0].Type | Should -Be 'feat'
        $commits[0].Scope | Should -Be 'auth'
        $commits[0].IsBreaking | Should -BeTrue
    }

    It 'parses multiple commits separated by newlines' {
        $log = @(
            'feat: alpha',
            'fix: bravo',
            'chore: charlie'
        ) -join "`n"

        $commits = Get-ConventionalCommits -Text $log

        $commits | Should -HaveCount 3
        ($commits | ForEach-Object Type) -join ',' | Should -Be 'feat,fix,chore'
    }

    It 'detects BREAKING CHANGE in the body as breaking' {
        # Multi-line commits arrive joined by literal "\n\n" between commits.
        # A BREAKING CHANGE: footer should mark the commit as breaking even
        # when the subject line lacks the ! marker.
        $log = "feat: add api`nBREAKING CHANGE: drops v1 endpoints"
        $commits = Get-ConventionalCommits -Text $log

        $commits[0].IsBreaking | Should -BeTrue
    }

    It 'ignores blank lines and non-conventional lines' {
        $log = @(
            '',
            'merge branch foo',
            'feat: add thing',
            '',
            'fix: bug'
        ) -join "`n"

        $commits = Get-ConventionalCommits -Text $log
        $commits | Should -HaveCount 2
    }

    It 'reads commits from a file via -Path' {
        $f = Join-Path $TestDrive 'commits.txt'
        Set-Content -Path $f -Value "feat: file based"

        $commits = Get-ConventionalCommits -Path $f
        $commits[0].Description | Should -Be 'file based'
    }
}

Describe 'Get-NextBumpType' {

    It 'returns major when any commit is breaking' {
        $commits = @(
            [pscustomobject]@{ Type = 'fix'; IsBreaking = $false },
            [pscustomobject]@{ Type = 'feat'; IsBreaking = $true }
        )
        Get-NextBumpType -Commits $commits | Should -Be 'major'
    }

    It 'returns minor when there is a feat but no breaking' {
        $commits = @(
            [pscustomobject]@{ Type = 'feat'; IsBreaking = $false },
            [pscustomobject]@{ Type = 'fix'; IsBreaking = $false }
        )
        Get-NextBumpType -Commits $commits | Should -Be 'minor'
    }

    It 'returns patch when there are only fixes' {
        $commits = @(
            [pscustomobject]@{ Type = 'fix'; IsBreaking = $false }
        )
        Get-NextBumpType -Commits $commits | Should -Be 'patch'
    }

    It 'returns none when nothing relevant is present' {
        $commits = @(
            [pscustomobject]@{ Type = 'chore'; IsBreaking = $false },
            [pscustomobject]@{ Type = 'docs'; IsBreaking = $false }
        )
        Get-NextBumpType -Commits $commits | Should -Be 'none'
    }

    It 'returns none for an empty list' {
        Get-NextBumpType -Commits @() | Should -Be 'none'
    }
}

Describe 'Step-Version' {

    It 'bumps major and resets minor/patch' {
        Step-Version -Version '1.2.3' -BumpType 'major' | Should -Be '2.0.0'
    }

    It 'bumps minor and resets patch' {
        Step-Version -Version '1.2.3' -BumpType 'minor' | Should -Be '1.3.0'
    }

    It 'bumps patch only' {
        Step-Version -Version '1.2.3' -BumpType 'patch' | Should -Be '1.2.4'
    }

    It 'returns the same version when bump type is none' {
        Step-Version -Version '1.2.3' -BumpType 'none' | Should -Be '1.2.3'
    }

    It 'rejects invalid input version' {
        { Step-Version -Version 'banana' -BumpType 'patch' } |
            Should -Throw -ExpectedMessage '*not a valid semantic version*'
    }

    It 'rejects invalid bump type' {
        { Step-Version -Version '1.0.0' -BumpType 'mega' } | Should -Throw
    }
}

Describe 'Set-VersionFile' {

    BeforeEach {
        $script:TestDir = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
    }

    It 'writes a plain VERSION file' {
        $vf = Join-Path $script:TestDir 'VERSION'
        Set-Content -Path $vf -Value '1.0.0' -NoNewline

        Set-VersionFile -Path $vf -Version '2.0.0'

        (Get-Content $vf -Raw).Trim() | Should -Be '2.0.0'
    }

    It 'updates the version field in package.json without disturbing other fields' {
        $pj = Join-Path $script:TestDir 'package.json'
        @{ name = 'demo'; version = '1.0.0'; description = 'd' } |
            ConvertTo-Json | Set-Content -Path $pj

        Set-VersionFile -Path $pj -Version '1.1.0'

        $obj = Get-Content $pj -Raw | ConvertFrom-Json
        $obj.version     | Should -Be '1.1.0'
        $obj.name        | Should -Be 'demo'
        $obj.description | Should -Be 'd'
    }
}

Describe 'New-ChangelogEntry' {

    It 'groups commits under Features / Fixes / Breaking sections' {
        $commits = @(
            [pscustomobject]@{ Type = 'feat'; Scope = $null; Description = 'add login'; IsBreaking = $false },
            [pscustomobject]@{ Type = 'fix'; Scope = 'api'; Description = 'null pointer'; IsBreaking = $false },
            [pscustomobject]@{ Type = 'feat'; Scope = $null; Description = 'remove v1'; IsBreaking = $true }
        )

        $entry = New-ChangelogEntry -Version '2.0.0' -Date '2026-05-07' -Commits $commits

        $entry | Should -Match '## \[2\.0\.0\] - 2026-05-07'
        $entry | Should -Match '### Breaking Changes'
        $entry | Should -Match '### Features'
        $entry | Should -Match '### Fixes'
        $entry | Should -Match '- \*\*api\*\*: null pointer'
        $entry | Should -Match '- add login'
    }

    It 'omits empty sections' {
        $commits = @(
            [pscustomobject]@{ Type = 'fix'; Scope = $null; Description = 'typo'; IsBreaking = $false }
        )
        $entry = New-ChangelogEntry -Version '1.0.1' -Date '2026-05-07' -Commits $commits

        $entry | Should -Match '### Fixes'
        $entry | Should -Not -Match '### Features'
        $entry | Should -Not -Match '### Breaking Changes'
    }
}

Describe 'Invoke-Bumper (end-to-end)' {

    BeforeEach {
        $script:WorkDir = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
    }

    It 'bumps minor for a feat commit and updates VERSION + CHANGELOG' {
        $vf = Join-Path $script:WorkDir 'VERSION'
        Set-Content -Path $vf -Value '1.1.0' -NoNewline

        $cf = Join-Path $script:WorkDir 'commits.txt'
        Set-Content -Path $cf -Value 'feat: add panel' -NoNewline

        $changelog = Join-Path $script:WorkDir 'CHANGELOG.md'

        $result = Invoke-Bumper -VersionFile $vf -CommitsFile $cf `
            -ChangelogFile $changelog -Date '2026-05-07'

        $result.OldVersion | Should -Be '1.1.0'
        $result.NewVersion | Should -Be '1.2.0'
        $result.BumpType   | Should -Be 'minor'
        (Get-Content $vf -Raw).Trim() | Should -Be '1.2.0'
        (Get-Content $changelog -Raw) | Should -Match '## \[1\.2\.0\] - 2026-05-07'
        (Get-Content $changelog -Raw) | Should -Match 'add panel'
    }

    It 'bumps major for breaking marker !' {
        $vf = Join-Path $script:WorkDir 'VERSION'
        Set-Content -Path $vf -Value '0.9.4' -NoNewline
        $cf = Join-Path $script:WorkDir 'commits.txt'
        Set-Content -Path $cf -Value 'feat(api)!: drop legacy endpoints' -NoNewline

        $r = Invoke-Bumper -VersionFile $vf -CommitsFile $cf `
            -ChangelogFile (Join-Path $script:WorkDir 'CHANGELOG.md') -Date '2026-05-07'

        $r.NewVersion | Should -Be '1.0.0'
        $r.BumpType   | Should -Be 'major'
    }

    It 'bumps patch for fix commits' {
        $vf = Join-Path $script:WorkDir 'VERSION'
        Set-Content -Path $vf -Value '2.4.1' -NoNewline
        $cf = Join-Path $script:WorkDir 'commits.txt'
        Set-Content -Path $cf -Value 'fix: race condition' -NoNewline

        $r = Invoke-Bumper -VersionFile $vf -CommitsFile $cf `
            -ChangelogFile (Join-Path $script:WorkDir 'CHANGELOG.md') -Date '2026-05-07'

        $r.NewVersion | Should -Be '2.4.2'
        $r.BumpType   | Should -Be 'patch'
    }

    It 'returns BumpType=none and does not modify the version when commits are non-bumping' {
        $vf = Join-Path $script:WorkDir 'VERSION'
        Set-Content -Path $vf -Value '3.0.0' -NoNewline
        $cf = Join-Path $script:WorkDir 'commits.txt'
        Set-Content -Path $cf -Value @"
chore: tidy up
docs: README typo
"@ -NoNewline

        $r = Invoke-Bumper -VersionFile $vf -CommitsFile $cf `
            -ChangelogFile (Join-Path $script:WorkDir 'CHANGELOG.md') -Date '2026-05-07'

        $r.BumpType   | Should -Be 'none'
        $r.NewVersion | Should -Be '3.0.0'
        (Get-Content $vf -Raw).Trim() | Should -Be '3.0.0'
    }

    It 'prepends new entries above older entries in CHANGELOG.md' {
        $vf = Join-Path $script:WorkDir 'VERSION'
        Set-Content -Path $vf -Value '1.0.0' -NoNewline
        $cf = Join-Path $script:WorkDir 'commits.txt'
        Set-Content -Path $cf -Value 'feat: thing' -NoNewline
        $changelog = Join-Path $script:WorkDir 'CHANGELOG.md'
        Set-Content -Path $changelog -Value "# Changelog`n`n## [0.9.0] - 2026-01-01`n- old`n"

        Invoke-Bumper -VersionFile $vf -CommitsFile $cf `
            -ChangelogFile $changelog -Date '2026-05-07' | Out-Null

        $text = Get-Content $changelog -Raw
        $text | Should -Match '# Changelog'
        # New entry must precede the older one.
        $newIdx = $text.IndexOf('[1.1.0]')
        $oldIdx = $text.IndexOf('[0.9.0]')
        $newIdx | Should -BeLessThan $oldIdx
    }
}
