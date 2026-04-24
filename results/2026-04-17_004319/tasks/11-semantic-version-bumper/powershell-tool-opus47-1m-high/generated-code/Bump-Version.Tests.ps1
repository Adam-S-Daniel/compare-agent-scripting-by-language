#Requires -Modules Pester

# Pester tests for Bump-Version.ps1.
# Built TDD-style: each Describe block was added one at a time, the test was run
# and seen to fail, then the minimum production code was written until it passed.

BeforeAll {
    $script:scriptPath = Join-Path $PSScriptRoot 'Bump-Version.ps1'
    $script:fixturesDir = Join-Path $PSScriptRoot 'fixtures'

    # Dot-source the script so we can call its internal helper functions
    # directly. The script supports a -NoExecute switch for this purpose.
    . $script:scriptPath -NoExecute
}

Describe 'Get-CurrentVersion' {
    It 'reads a plain text version file' {
        $tmp = New-TemporaryFile
        '1.2.3' | Set-Content -Path $tmp.FullName
        try {
            (Get-CurrentVersion -Path $tmp.FullName) | Should -Be '1.2.3'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }

    It 'reads the version field from package.json' {
        $tmp = New-TemporaryFile
        $json = [pscustomobject]@{ name = 'demo'; version = '0.4.1' } | ConvertTo-Json
        Move-Item $tmp.FullName "$($tmp.FullName).json" -Force
        $jsonPath = "$($tmp.FullName).json"
        $json | Set-Content -Path $jsonPath
        try {
            (Get-CurrentVersion -Path $jsonPath) | Should -Be '0.4.1'
        } finally {
            Remove-Item $jsonPath -Force
        }
    }

    It 'throws a meaningful error for missing files' {
        { Get-CurrentVersion -Path '/no/such/file' } | Should -Throw '*not found*'
    }

    It 'throws when version field is malformed' {
        $tmp = New-TemporaryFile
        'not-a-version' | Set-Content -Path $tmp.FullName
        try {
            { Get-CurrentVersion -Path $tmp.FullName } | Should -Throw '*semantic version*'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }
}

Describe 'Get-BumpType' {
    It 'returns major for a commit with a ! marker' {
        Get-BumpType -Commits @('feat!: drop legacy api') | Should -Be 'major'
    }

    It 'returns major for a commit with BREAKING CHANGE in body' {
        Get-BumpType -Commits @("feat: thing`n`nBREAKING CHANGE: removed flag") | Should -Be 'major'
    }

    It 'returns minor for feat commits' {
        Get-BumpType -Commits @('feat: add new endpoint', 'fix: typo') | Should -Be 'minor'
    }

    It 'returns patch for fix commits only' {
        Get-BumpType -Commits @('fix: handle null', 'chore: tidy') | Should -Be 'patch'
    }

    It 'returns none when no relevant commits are present' {
        Get-BumpType -Commits @('chore: tidy', 'docs: tweak') | Should -Be 'none'
    }

    It 'breaking outranks feat which outranks fix' {
        Get-BumpType -Commits @('fix: a', 'feat: b', 'feat!: c') | Should -Be 'major'
        Get-BumpType -Commits @('fix: a', 'feat: b') | Should -Be 'minor'
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
    It 'rejects garbage versions' {
        { Step-Version -Version 'abc' -BumpType 'patch' } | Should -Throw '*semantic version*'
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits by type with the new version as a heading' {
        $entry = New-ChangelogEntry -Version '1.3.0' -Commits @(
            'feat: add login',
            'fix: null deref',
            'chore: bump deps'
        )
        $entry | Should -Match '## \[1\.3\.0\]'
        $entry | Should -Match '### Features'
        $entry | Should -Match '- add login'
        $entry | Should -Match '### Bug Fixes'
        $entry | Should -Match '- null deref'
    }

    It 'records breaking changes prominently' {
        $entry = New-ChangelogEntry -Version '2.0.0' -Commits @('feat!: rip out v1 api')
        $entry | Should -Match '### .*BREAKING'
        $entry | Should -Match '- rip out v1 api'
    }
}

Describe 'Set-VersionInFile' {
    It 'updates a plain text version file' {
        $tmp = New-TemporaryFile
        '1.0.0' | Set-Content -Path $tmp.FullName
        try {
            Set-VersionInFile -Path $tmp.FullName -Version '1.1.0'
            (Get-Content -Path $tmp.FullName -Raw).Trim() | Should -Be '1.1.0'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }

    It 'updates the version field in a package.json' {
        $tmp = New-TemporaryFile
        Move-Item $tmp.FullName "$($tmp.FullName).json" -Force
        $jsonPath = "$($tmp.FullName).json"
        '{"name":"demo","version":"0.1.0"}' | Set-Content -Path $jsonPath
        try {
            Set-VersionInFile -Path $jsonPath -Version '0.2.0'
            $obj = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $obj.version | Should -Be '0.2.0'
            $obj.name | Should -Be 'demo'
        } finally {
            Remove-Item $jsonPath -Force
        }
    }
}

Describe 'Invoke-VersionBump (integration)' {
    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:work | Out-Null
    }
    AfterEach {
        if (Test-Path $script:work) { Remove-Item $script:work -Recurse -Force }
    }

    It 'bumps minor for a feat commit and writes changelog' {
        $vf = Join-Path $script:work 'version.txt'
        $cf = Join-Path $script:work 'commits.txt'
        $cl = Join-Path $script:work 'CHANGELOG.md'
        '1.0.0' | Set-Content $vf
        'feat: add cool thing' | Set-Content $cf

        $result = Invoke-VersionBump -VersionFile $vf -CommitsFile $cf -ChangelogFile $cl

        $result | Should -Be '1.1.0'
        (Get-Content $vf -Raw).Trim() | Should -Be '1.1.0'
        (Get-Content $cl -Raw) | Should -Match 'add cool thing'
    }

    It 'bumps patch for a fix commit' {
        $vf = Join-Path $script:work 'version.txt'
        $cf = Join-Path $script:work 'commits.txt'
        '1.2.3' | Set-Content $vf
        "fix: off-by-one`nchore: cleanup" | Set-Content $cf
        Invoke-VersionBump -VersionFile $vf -CommitsFile $cf | Should -Be '1.2.4'
    }

    It 'bumps major for a breaking commit' {
        $vf = Join-Path $script:work 'version.txt'
        $cf = Join-Path $script:work 'commits.txt'
        '1.2.3' | Set-Content $vf
        'feat!: redesign' | Set-Content $cf
        Invoke-VersionBump -VersionFile $vf -CommitsFile $cf | Should -Be '2.0.0'
    }

    It 'leaves version unchanged when no relevant commits are present' {
        $vf = Join-Path $script:work 'version.txt'
        $cf = Join-Path $script:work 'commits.txt'
        '1.2.3' | Set-Content $vf
        "chore: tidy`ndocs: typo" | Set-Content $cf
        Invoke-VersionBump -VersionFile $vf -CommitsFile $cf | Should -Be '1.2.3'
    }
}

Describe 'Fixture round-trip' {
    It 'each fixture yields its expected version' {
        $cases = @(
            @{ Dir = 'feat-minor';      Expected = '1.3.0' },
            @{ Dir = 'fix-patch';       Expected = '1.2.4' },
            @{ Dir = 'breaking-major';  Expected = '2.0.0' }
        )
        foreach ($c in $cases) {
            $work = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
            New-Item -ItemType Directory -Path $work | Out-Null
            try {
                Copy-Item (Join-Path $script:fixturesDir $c.Dir 'version.txt') -Destination (Join-Path $work 'version.txt')
                Copy-Item (Join-Path $script:fixturesDir $c.Dir 'commits.txt') -Destination (Join-Path $work 'commits.txt')
                $r = Invoke-VersionBump `
                    -VersionFile (Join-Path $work 'version.txt') `
                    -CommitsFile (Join-Path $work 'commits.txt') `
                    -ChangelogFile (Join-Path $work 'CHANGELOG.md')
                $r | Should -Be $c.Expected
            } finally {
                Remove-Item $work -Recurse -Force
            }
        }
    }
}
