# Pester tests for the semantic version bumper.
# Tests are organised so each Describe block exercises one concern. We follow
# red/green/refactor: each "It" block was written failing first, then the
# minimum implementation in Bumper.psm1 was added to make it pass.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'Bumper.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module Bumper -ErrorAction SilentlyContinue
}

Describe 'Get-BumpType' {
    Context 'classifies conventional commits' {
        It 'returns major when any commit body contains BREAKING CHANGE' {
            $commits = @(
                @{ Subject = 'feat: add login';  Body = 'BREAKING CHANGE: removes /v1' }
                @{ Subject = 'fix: typo';        Body = '' }
            )
            Get-BumpType -Commits $commits | Should -Be 'major'
        }

        It 'returns major when subject uses the ! marker' {
            $commits = @(
                @{ Subject = 'feat!: drop legacy api'; Body = '' }
            )
            Get-BumpType -Commits $commits | Should -Be 'major'
        }

        It 'returns minor for feat without breaking change' {
            $commits = @(
                @{ Subject = 'feat: add export option'; Body = '' }
                @{ Subject = 'fix: minor bug';          Body = '' }
            )
            Get-BumpType -Commits $commits | Should -Be 'minor'
        }

        It 'returns patch for fix-only commits' {
            $commits = @(
                @{ Subject = 'fix: clamp range';   Body = '' }
                @{ Subject = 'chore: bump deps';   Body = '' }
            )
            Get-BumpType -Commits $commits | Should -Be 'patch'
        }

        It 'returns patch for chore-only / no relevant commits' {
            $commits = @(
                @{ Subject = 'chore: housekeeping'; Body = '' }
                @{ Subject = 'docs: update readme'; Body = '' }
            )
            Get-BumpType -Commits $commits | Should -Be 'patch'
        }

        It 'recognises scoped feat commits like feat(api):' {
            $commits = @(
                @{ Subject = 'feat(api): add field'; Body = '' }
            )
            Get-BumpType -Commits $commits | Should -Be 'minor'
        }

        It 'recognises scoped breaking marker like feat(api)!:' {
            $commits = @(
                @{ Subject = 'feat(api)!: remove endpoint'; Body = '' }
            )
            Get-BumpType -Commits $commits | Should -Be 'major'
        }
    }

    Context 'edge cases' {
        It 'throws on empty commit list' {
            { Get-BumpType -Commits @() } | Should -Throw '*no commits*'
        }
    }
}

Describe 'Step-SemVer' {
    It 'bumps patch correctly' {
        Step-SemVer -Version '1.2.3' -BumpType 'patch' | Should -Be '1.2.4'
    }
    It 'bumps minor and resets patch' {
        Step-SemVer -Version '1.2.3' -BumpType 'minor' | Should -Be '1.3.0'
    }
    It 'bumps major and resets minor + patch' {
        Step-SemVer -Version '1.2.3' -BumpType 'major' | Should -Be '2.0.0'
    }
    It 'works from a 0.x version' {
        Step-SemVer -Version '0.0.1' -BumpType 'minor' | Should -Be '0.1.0'
    }
    It 'rejects a malformed semver' {
        { Step-SemVer -Version 'not-a-version' -BumpType 'patch' } |
            Should -Throw '*not a valid semantic version*'
    }
    It 'rejects an unknown bump type' {
        { Step-SemVer -Version '1.0.0' -BumpType 'huge' } | Should -Throw
    }
}

Describe 'Get-VersionFromFile / Set-VersionInFile' {
    BeforeEach {
        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:Tmp -ErrorAction SilentlyContinue
    }

    It 'reads version from a plain VERSION file' {
        $vf = Join-Path $script:Tmp 'VERSION'
        Set-Content -Path $vf -Value '1.4.2' -NoNewline
        Get-VersionFromFile -Path $vf | Should -Be '1.4.2'
    }

    It 'reads version from package.json' {
        $pj = Join-Path $script:Tmp 'package.json'
        Set-Content -Path $pj -Value '{ "name": "x", "version": "2.5.7" }'
        Get-VersionFromFile -Path $pj | Should -Be '2.5.7'
    }

    It 'writes version back to VERSION file preserving the bare-string format' {
        $vf = Join-Path $script:Tmp 'VERSION'
        Set-Content -Path $vf -Value '1.0.0' -NoNewline
        Set-VersionInFile -Path $vf -Version '1.1.0'
        (Get-Content $vf -Raw).Trim() | Should -Be '1.1.0'
    }

    It 'writes version back to package.json without clobbering other fields' {
        $pj = Join-Path $script:Tmp 'package.json'
        $original = '{ "name": "demo", "version": "1.0.0", "description": "x" }'
        Set-Content -Path $pj -Value $original
        Set-VersionInFile -Path $pj -Version '1.0.1'
        $obj = Get-Content $pj -Raw | ConvertFrom-Json
        $obj.version     | Should -Be '1.0.1'
        $obj.name        | Should -Be 'demo'
        $obj.description | Should -Be 'x'
    }

    It 'errors when the version file is missing' {
        { Get-VersionFromFile -Path (Join-Path $script:Tmp 'nope') } |
            Should -Throw '*not found*'
    }

    It 'errors when package.json has no version field' {
        $pj = Join-Path $script:Tmp 'package.json'
        Set-Content -Path $pj -Value '{ "name": "x" }'
        { Get-VersionFromFile -Path $pj } | Should -Throw '*version*'
    }
}

Describe 'Read-CommitFixture' {
    It 'parses a fixture file split by --SEP-- delimiters' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString() + '.txt')
        @(
            'feat: add thing'
            ''
            'BREAKING CHANGE: removes old thing'
            '--SEP--'
            'fix: tiny bug'
            '--SEP--'
            'chore: housekeeping'
        ) -join "`n" | Set-Content -Path $tmp -NoNewline
        try {
            $commits = Read-CommitFixture -Path $tmp
            $commits.Count          | Should -Be 3
            $commits[0].Subject     | Should -Be 'feat: add thing'
            $commits[0].Body        | Should -Match 'BREAKING CHANGE'
            $commits[1].Subject     | Should -Be 'fix: tiny bug'
            $commits[2].Subject     | Should -Be 'chore: housekeeping'
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits into Features / Fixes / Breaking Changes / Other' {
        $commits = @(
            @{ Subject = 'feat: add A';                 Body = '' }
            @{ Subject = 'feat(api)!: drop X';          Body = '' }
            @{ Subject = 'fix: bug B';                  Body = '' }
            @{ Subject = 'chore: C';                    Body = '' }
            @{ Subject = 'feat: with breaking note';    Body = 'BREAKING CHANGE: explained' }
        )
        $entry = New-ChangelogEntry -Version '2.0.0' -Date '2026-05-07' -Commits $commits
        $entry | Should -Match '## \[2\.0\.0\] - 2026-05-07'
        $entry | Should -Match '### Breaking Changes'
        $entry | Should -Match 'drop X'
        $entry | Should -Match 'explained'
        $entry | Should -Match '### Features'
        $entry | Should -Match 'add A'
        $entry | Should -Match '### Fixes'
        $entry | Should -Match 'bug B'
        $entry | Should -Match '### Other'
        $entry | Should -Match 'chore: C'
    }
}

Describe 'Invoke-VersionBump (end-to-end)' {
    BeforeEach {
        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:Tmp -ErrorAction SilentlyContinue
    }

    It 'bumps a feat fixture from 1.1.0 to 1.2.0 and writes a CHANGELOG' {
        $vf = Join-Path $script:Tmp 'VERSION'
        Set-Content -Path $vf -Value '1.1.0' -NoNewline
        $cf = Join-Path $script:Tmp 'commits.txt'
        Set-Content -Path $cf -Value 'feat: shiny new feature' -NoNewline
        $cl = Join-Path $script:Tmp 'CHANGELOG.md'

        $result = Invoke-VersionBump `
            -VersionFile   $vf `
            -CommitsFile   $cf `
            -ChangelogFile $cl `
            -Date          '2026-05-07'

        $result.PreviousVersion | Should -Be '1.1.0'
        $result.NextVersion     | Should -Be '1.2.0'
        $result.BumpType        | Should -Be 'minor'

        (Get-Content $vf -Raw).Trim() | Should -Be '1.2.0'
        (Get-Content $cl -Raw)        | Should -Match '## \[1\.2\.0\] - 2026-05-07'
        (Get-Content $cl -Raw)        | Should -Match 'shiny new feature'
    }

    It 'prepends new entry above an existing changelog' {
        $vf = Join-Path $script:Tmp 'VERSION'
        Set-Content -Path $vf -Value '1.0.0' -NoNewline
        $cf = Join-Path $script:Tmp 'commits.txt'
        Set-Content -Path $cf -Value 'fix: tiny' -NoNewline
        $cl = Join-Path $script:Tmp 'CHANGELOG.md'
        Set-Content -Path $cl -Value "# Changelog`n`n## [0.9.0] - 2025-01-01`n- old"

        Invoke-VersionBump -VersionFile $vf -CommitsFile $cf -ChangelogFile $cl -Date '2026-05-07' | Out-Null

        $content = Get-Content $cl -Raw
        $content | Should -Match '## \[1\.0\.1\]'
        $content | Should -Match '## \[0\.9\.0\]'
        # The new (1.0.1) entry must appear before the old one in the file.
        $idxNew = $content.IndexOf('[1.0.1]')
        $idxOld = $content.IndexOf('[0.9.0]')
        $idxNew | Should -BeLessThan $idxOld
    }

    It 'handles BREAKING CHANGE -> major bump' {
        $vf = Join-Path $script:Tmp 'VERSION'
        Set-Content -Path $vf -Value '1.4.2' -NoNewline
        $cf = Join-Path $script:Tmp 'commits.txt'
        @(
            'feat: refactor pipeline'
            ''
            'BREAKING CHANGE: removes old pipeline'
        ) -join "`n" | Set-Content -Path $cf -NoNewline
        $cl = Join-Path $script:Tmp 'CHANGELOG.md'

        $r = Invoke-VersionBump -VersionFile $vf -CommitsFile $cf -ChangelogFile $cl -Date '2026-05-07'
        $r.NextVersion | Should -Be '2.0.0'
        $r.BumpType    | Should -Be 'major'
    }

    It 'handles package.json projects' {
        $pj = Join-Path $script:Tmp 'package.json'
        Set-Content -Path $pj -Value '{ "name": "demo", "version": "0.5.0" }'
        $cf = Join-Path $script:Tmp 'commits.txt'
        Set-Content -Path $cf -Value 'feat: A' -NoNewline
        $cl = Join-Path $script:Tmp 'CHANGELOG.md'

        $r = Invoke-VersionBump -VersionFile $pj -CommitsFile $cf -ChangelogFile $cl -Date '2026-05-07'
        $r.NextVersion | Should -Be '0.6.0'
        $obj = Get-Content $pj -Raw | ConvertFrom-Json
        $obj.version | Should -Be '0.6.0'
        $obj.name    | Should -Be 'demo'
    }
}
