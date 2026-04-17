#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Pester tests for the semantic-version-bumper tool.
# Drives development of VersionBumper.psm1 via red/green TDD.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'VersionBumper.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module VersionBumper -Force -ErrorAction SilentlyContinue
}

Describe 'Get-NextVersion' {
    Context 'when given no commits' {
        It 'returns the current version unchanged' {
            Get-NextVersion -Current '1.2.3' -Commits @() | Should -Be '1.2.3'
        }
    }

    Context 'when commits contain only fix entries' {
        It 'bumps the patch component' {
            $commits = @('fix: correct off-by-one error')
            Get-NextVersion -Current '1.2.3' -Commits $commits | Should -Be '1.2.4'
        }

        It 'collapses multiple patches to a single patch bump' {
            $commits = @('fix: a', 'fix: b', 'fix(parser): c')
            Get-NextVersion -Current '0.4.9' -Commits $commits | Should -Be '0.4.10'
        }
    }

    Context 'when commits contain a feat entry' {
        It 'bumps the minor component and resets patch' {
            $commits = @('fix: a', 'feat: add new thing')
            Get-NextVersion -Current '1.2.3' -Commits $commits | Should -Be '1.3.0'
        }
    }

    Context 'when commits contain a breaking change' {
        It 'bumps the major component on BREAKING CHANGE marker' {
            $commits = @('feat: x', 'fix: y', 'refactor!: drop legacy api')
            Get-NextVersion -Current '2.5.7' -Commits $commits | Should -Be '3.0.0'
        }

        It 'bumps major when footer contains BREAKING CHANGE:' {
            $commits = @("feat: x`n`nBREAKING CHANGE: removed --old flag")
            Get-NextVersion -Current '0.9.1' -Commits $commits | Should -Be '1.0.0'
        }
    }

    Context 'when given an invalid current version' {
        It 'throws a meaningful error' {
            { Get-NextVersion -Current 'not-a-version' -Commits @('feat: x') } |
                Should -Throw -ExpectedMessage '*semantic version*'
        }
    }
}

Describe 'Read-VersionFile' {
    BeforeEach {
        $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:tmp -ErrorAction SilentlyContinue
    }

    It 'reads a plain VERSION file' {
        $path = Join-Path $script:tmp 'VERSION'
        Set-Content -Path $path -Value '1.4.2' -NoNewline
        Read-VersionFile -Path $path | Should -Be '1.4.2'
    }

    It 'reads version from package.json' {
        $path = Join-Path $script:tmp 'package.json'
        @{ name = 'demo'; version = '0.5.0' } | ConvertTo-Json | Set-Content -Path $path
        Read-VersionFile -Path $path | Should -Be '0.5.0'
    }

    It 'throws when the file does not exist' {
        { Read-VersionFile -Path (Join-Path $script:tmp 'missing') } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Write-VersionFile' {
    BeforeEach {
        $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:tmp -ErrorAction SilentlyContinue
    }

    It 'updates a plain VERSION file' {
        $path = Join-Path $script:tmp 'VERSION'
        Set-Content -Path $path -Value '1.0.0' -NoNewline
        Write-VersionFile -Path $path -Version '1.1.0'
        (Get-Content -Path $path -Raw).Trim() | Should -Be '1.1.0'
    }

    It 'updates the version field in package.json preserving other fields' {
        $path = Join-Path $script:tmp 'package.json'
        @{ name = 'demo'; version = '0.5.0'; dependencies = @{ left = '1.0.0' } } |
            ConvertTo-Json | Set-Content -Path $path
        Write-VersionFile -Path $path -Version '0.6.0'
        $reread = Get-Content $path -Raw | ConvertFrom-Json
        $reread.version | Should -Be '0.6.0'
        $reread.name | Should -Be 'demo'
        $reread.dependencies.left | Should -Be '1.0.0'
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits by type and renders a markdown section' {
        $commits = @(
            'feat: add login page',
            'fix: crash on startup',
            'feat(parser): support comments',
            'refactor!: drop deprecated api',
            'chore: bump deps'
        )
        $entry = New-ChangelogEntry -Version '2.0.0' -Date '2026-04-17' -Commits $commits
        $entry | Should -Match '## \[2\.0\.0\] - 2026-04-17'
        $entry | Should -Match '### Features'
        $entry | Should -Match 'add login page'
        $entry | Should -Match 'support comments'
        $entry | Should -Match '### Bug Fixes'
        $entry | Should -Match 'crash on startup'
        $entry | Should -Match '### BREAKING CHANGES'
        $entry | Should -Match 'drop deprecated api'
    }

    It 'omits empty sections' {
        $entry = New-ChangelogEntry -Version '1.0.1' -Date '2026-04-17' -Commits @('fix: x')
        $entry | Should -Match '### Bug Fixes'
        $entry | Should -Not -Match '### Features'
        $entry | Should -Not -Match '### BREAKING CHANGES'
    }
}

Describe 'Invoke-VersionBump' {
    BeforeEach {
        $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tmp | Out-Null
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:tmp -ErrorAction SilentlyContinue
    }

    It 'bumps the file, writes a changelog and returns the new version' {
        $vfile = Join-Path $script:tmp 'VERSION'
        Set-Content -Path $vfile -Value '1.2.3' -NoNewline
        $commitsFile = Join-Path $script:tmp 'commits.txt'
        Set-Content -Path $commitsFile -Value @(
            'feat: add alpha',
            'fix: bravo'
        )
        $changelog = Join-Path $script:tmp 'CHANGELOG.md'
        $newVersion = Invoke-VersionBump -VersionFile $vfile -CommitsFile $commitsFile -ChangelogFile $changelog -Date '2026-04-17'
        $newVersion | Should -Be '1.3.0'
        (Get-Content $vfile -Raw).Trim() | Should -Be '1.3.0'
        (Get-Content $changelog -Raw) | Should -Match '## \[1\.3\.0\]'
        (Get-Content $changelog -Raw) | Should -Match 'add alpha'
    }

    It 'prepends the new entry when the changelog already exists' {
        $vfile = Join-Path $script:tmp 'VERSION'
        Set-Content -Path $vfile -Value '1.2.3' -NoNewline
        $commitsFile = Join-Path $script:tmp 'commits.txt'
        Set-Content -Path $commitsFile -Value 'fix: small thing'
        $changelog = Join-Path $script:tmp 'CHANGELOG.md'
        Set-Content -Path $changelog -Value "# Changelog`n`n## [1.2.3] - 2026-01-01`n- something`n"
        Invoke-VersionBump -VersionFile $vfile -CommitsFile $commitsFile -ChangelogFile $changelog -Date '2026-04-17' | Out-Null
        $body = Get-Content $changelog -Raw
        $body | Should -Match '1\.2\.4'
        $body | Should -Match '1\.2\.3'
        # Newer entry must appear before the older one
        $body.IndexOf('1.2.4') | Should -BeLessThan $body.IndexOf('1.2.3')
    }
}
