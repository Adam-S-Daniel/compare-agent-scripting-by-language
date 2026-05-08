# Pester tests for SemanticVersionBumper module.
# Red/green TDD: each Describe/It started failing before the implementation existed
# and now passes.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'SemanticVersionBumper.psm1'
    Import-Module $script:ModulePath -Force
    $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Get-CurrentVersion' {
    It 'reads version from package.json' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'pkg') -Force
        $pkg = Join-Path $tmp 'package.json'
        '{"name":"x","version":"1.2.3"}' | Set-Content $pkg
        (Get-CurrentVersion -Path $pkg) | Should -Be '1.2.3'
    }

    It 'reads version from a plain VERSION file' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'ver') -Force
        $vf = Join-Path $tmp 'VERSION'
        "0.4.7`n" | Set-Content $vf
        (Get-CurrentVersion -Path $vf) | Should -Be '0.4.7'
    }

    It 'throws a meaningful error when file is missing' {
        { Get-CurrentVersion -Path (Join-Path $TestDrive 'nope.json') } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws when version string is invalid' {
        $bad = Join-Path $TestDrive 'bad.json'
        '{"version":"banana"}' | Set-Content $bad
        { Get-CurrentVersion -Path $bad } | Should -Throw -ExpectedMessage '*not a valid semantic version*'
    }
}

Describe 'Get-BumpType' {
    It 'returns major for breaking change marker (!)' {
        Get-BumpType -Commits @('feat!: drop legacy API') | Should -Be 'major'
    }

    It 'returns major for BREAKING CHANGE in body' {
        Get-BumpType -Commits @("feat: x`n`nBREAKING CHANGE: removed thing") | Should -Be 'major'
    }

    It 'returns minor for feat' {
        Get-BumpType -Commits @('feat: add cool thing','chore: tidy') | Should -Be 'minor'
    }

    It 'returns patch for fix only' {
        Get-BumpType -Commits @('fix: off-by-one','docs: typo') | Should -Be 'patch'
    }

    It 'returns none when no relevant commits exist' {
        Get-BumpType -Commits @('docs: typo','chore: bump deps') | Should -Be 'none'
    }

    It 'precedence: a single breaking trumps many feats/fixes' {
        Get-BumpType -Commits @('feat: a','fix: b','feat!: c') | Should -Be 'major'
    }
}

Describe 'Step-Version' {
    It 'bumps patch' { Step-Version -Version '1.2.3' -BumpType 'patch' | Should -Be '1.2.4' }
    It 'bumps minor and resets patch' { Step-Version -Version '1.2.3' -BumpType 'minor' | Should -Be '1.3.0' }
    It 'bumps major and resets minor+patch' { Step-Version -Version '1.2.3' -BumpType 'major' | Should -Be '2.0.0' }
    It 'returns same version for none' { Step-Version -Version '1.2.3' -BumpType 'none' | Should -Be '1.2.3' }
    It 'rejects invalid version' { { Step-Version -Version 'x' -BumpType 'patch' } | Should -Throw }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits into Features/Fixes/Breaking sections' {
        $entry = New-ChangelogEntry -Version '1.3.0' -Date '2026-05-08' -Commits @(
            'feat: add A',
            'fix: repair B',
            'feat!: drop C',
            'chore: ignore'
        )
        $entry | Should -Match '## \[1\.3\.0\] - 2026-05-08'
        $entry | Should -Match '### Breaking Changes'
        $entry | Should -Match '### Features'
        $entry | Should -Match '### Bug Fixes'
        $entry | Should -Match '- add A'
        $entry | Should -Match '- repair B'
        $entry | Should -Match '- drop C'
        $entry | Should -Not -Match 'ignore'
    }
}

Describe 'Invoke-VersionBump (end-to-end)' {
    It 'bumps package.json minor when feat is in commits.txt' {
        $work = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'e2e1') -Force
        '{"name":"demo","version":"1.1.0"}' | Set-Content (Join-Path $work 'package.json')
        @('feat: add stuff','fix: small fix') -join "`n---COMMIT---`n" |
            Set-Content (Join-Path $work 'commits.txt')

        $result = Invoke-VersionBump -VersionFile (Join-Path $work 'package.json') `
                                    -CommitsFile (Join-Path $work 'commits.txt') `
                                    -ChangelogFile (Join-Path $work 'CHANGELOG.md')

        $result.OldVersion | Should -Be '1.1.0'
        $result.NewVersion | Should -Be '1.2.0'
        $result.BumpType   | Should -Be 'minor'

        # File was updated
        $pkg = Get-Content (Join-Path $work 'package.json') -Raw | ConvertFrom-Json
        $pkg.version | Should -Be '1.2.0'

        # Changelog written
        Test-Path (Join-Path $work 'CHANGELOG.md') | Should -BeTrue
        Get-Content (Join-Path $work 'CHANGELOG.md') -Raw | Should -Match '1\.2\.0'
    }

    It 'bumps a VERSION file to major when breaking commit present' {
        $work = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'e2e2') -Force
        '0.9.4' | Set-Content (Join-Path $work 'VERSION')
        @('feat!: rewrite engine','fix: x') -join "`n---COMMIT---`n" |
            Set-Content (Join-Path $work 'commits.txt')

        $result = Invoke-VersionBump -VersionFile (Join-Path $work 'VERSION') `
                                    -CommitsFile (Join-Path $work 'commits.txt') `
                                    -ChangelogFile (Join-Path $work 'CHANGELOG.md')
        $result.NewVersion | Should -Be '1.0.0'
        (Get-Content (Join-Path $work 'VERSION') -Raw).Trim() | Should -Be '1.0.0'
    }

    It 'no-ops when no relevant commits' {
        $work = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'e2e3') -Force
        '{"version":"2.0.0"}' | Set-Content (Join-Path $work 'package.json')
        'docs: tweak readme' | Set-Content (Join-Path $work 'commits.txt')

        $result = Invoke-VersionBump -VersionFile (Join-Path $work 'package.json') `
                                    -CommitsFile (Join-Path $work 'commits.txt') `
                                    -ChangelogFile (Join-Path $work 'CHANGELOG.md')
        $result.NewVersion | Should -Be '2.0.0'
        $result.BumpType   | Should -Be 'none'
    }
}

Describe 'Fixtures exist' {
    It 'has minor, major, patch, none fixture commit logs' {
        foreach ($f in 'commits-minor.txt','commits-major.txt','commits-patch.txt','commits-none.txt') {
            Test-Path (Join-Path $script:FixturesDir $f) | Should -BeTrue
        }
    }
}
