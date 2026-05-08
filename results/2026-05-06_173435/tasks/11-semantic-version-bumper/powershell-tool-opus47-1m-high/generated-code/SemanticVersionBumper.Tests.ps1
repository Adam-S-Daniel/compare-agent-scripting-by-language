# Pester tests for SemanticVersionBumper.ps1
# Red/green TDD: tests are defined first; implementation follows in
# SemanticVersionBumper.ps1. Each Describe block exercises one
# pure function, then the end-to-end Invoke-VersionBumper wraps it all.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'SemanticVersionBumper.ps1'
    . $script:ScriptPath
}

Describe 'Get-CurrentVersion' {
    It 'extracts the version from a package.json file' {
        $tmp = New-TemporaryFile
        @'
{
  "name": "demo",
  "version": "1.2.3"
}
'@ | Set-Content -Path $tmp.FullName
        try {
            (Get-CurrentVersion -Path $tmp.FullName) | Should -Be '1.2.3'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }

    It 'extracts the version from a plain VERSION file' {
        $tmp = New-TemporaryFile
        '0.4.0' | Set-Content -Path $tmp.FullName
        try {
            (Get-CurrentVersion -Path $tmp.FullName) | Should -Be '0.4.0'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }

    It 'throws a meaningful error when the file is missing' {
        { Get-CurrentVersion -Path '/no/such/path.json' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws when the file does not contain a valid semver' {
        $tmp = New-TemporaryFile
        'not-a-version' | Set-Content -Path $tmp.FullName
        try {
            { Get-CurrentVersion -Path $tmp.FullName } |
                Should -Throw -ExpectedMessage '*semver*'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }
}

Describe 'Get-BumpType' {
    It 'returns ''major'' when any commit contains BREAKING CHANGE' {
        $commits = @(
            'feat: add feature x',
            'fix: tidy logging',
            'refactor!: drop legacy api'
        )
        (Get-BumpType -Commits $commits) | Should -Be 'major'
    }

    It 'returns ''major'' when any commit body contains BREAKING CHANGE footer' {
        $commits = @("feat: thing`n`nBREAKING CHANGE: removes the old api")
        (Get-BumpType -Commits $commits) | Should -Be 'major'
    }

    It 'returns ''minor'' when the largest bump is feat:' {
        $commits = @('fix: x', 'feat(parser): new format', 'chore: deps')
        (Get-BumpType -Commits $commits) | Should -Be 'minor'
    }

    It 'returns ''patch'' when only fix: commits exist' {
        $commits = @('fix: fix A', 'fix(scope): fix B', 'docs: update readme')
        (Get-BumpType -Commits $commits) | Should -Be 'patch'
    }

    It 'returns ''none'' when only chore/docs/refactor commits exist' {
        $commits = @('chore: deps', 'docs: readme', 'refactor: tidy')
        (Get-BumpType -Commits $commits) | Should -Be 'none'
    }

    It 'returns ''none'' for an empty commit list' {
        (Get-BumpType -Commits @()) | Should -Be 'none'
    }
}

Describe 'Step-Version' {
    It 'bumps the major component and resets minor/patch' {
        (Step-Version -Version '1.2.3' -BumpType 'major') | Should -Be '2.0.0'
    }
    It 'bumps the minor component and resets patch' {
        (Step-Version -Version '1.2.3' -BumpType 'minor') | Should -Be '1.3.0'
    }
    It 'bumps the patch component' {
        (Step-Version -Version '1.2.3' -BumpType 'patch') | Should -Be '1.2.4'
    }
    It 'returns the same version when bump type is none' {
        (Step-Version -Version '1.2.3' -BumpType 'none') | Should -Be '1.2.3'
    }
    It 'rejects malformed versions' {
        { Step-Version -Version '1.2' -BumpType 'patch' } |
            Should -Throw -ExpectedMessage '*semver*'
    }
}

Describe 'Set-CurrentVersion' {
    It 'updates a package.json file in place, preserving other fields' {
        $tmp = New-TemporaryFile
        @'
{
  "name": "demo",
  "version": "1.2.3",
  "scripts": { "test": "echo" }
}
'@ | Set-Content -Path $tmp.FullName
        try {
            Set-CurrentVersion -Path $tmp.FullName -Version '2.0.0'
            $obj = Get-Content -Raw -Path $tmp.FullName | ConvertFrom-Json
            $obj.version | Should -Be '2.0.0'
            $obj.name | Should -Be 'demo'
            $obj.scripts.test | Should -Be 'echo'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }

    It 'updates a plain VERSION file' {
        $tmp = New-TemporaryFile
        '0.4.0' | Set-Content -Path $tmp.FullName
        try {
            Set-CurrentVersion -Path $tmp.FullName -Version '0.5.0'
            (Get-Content -Path $tmp.FullName).Trim() | Should -Be '0.5.0'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits by Features / Fixes / Breaking Changes' {
        $commits = @(
            'feat: add A',
            'fix: bug B',
            'refactor!: drop legacy',
            'chore: deps'
        )
        $entry = New-ChangelogEntry -Version '2.0.0' -Commits $commits -Date '2026-05-07'
        $entry | Should -Match '## \[2\.0\.0\] - 2026-05-07'
        $entry | Should -Match '### Breaking Changes'
        $entry | Should -Match 'drop legacy'
        $entry | Should -Match '### Features'
        $entry | Should -Match 'add A'
        $entry | Should -Match '### Fixes'
        $entry | Should -Match 'bug B'
    }

    It 'omits sections that have no commits' {
        $entry = New-ChangelogEntry -Version '1.0.1' -Commits @('fix: a') -Date '2026-05-07'
        $entry | Should -Not -Match '### Features'
        $entry | Should -Not -Match '### Breaking Changes'
        $entry | Should -Match '### Fixes'
    }
}

Describe 'Get-CommitsFromFile' {
    It 'reads commits separated by the NUL delimiter' {
        # git log -z uses NUL between entries. Mock file simulates that.
        $tmp = New-TemporaryFile
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("feat: a`nbody`0fix: b`0chore: c")
        [System.IO.File]::WriteAllBytes($tmp.FullName, $bytes)
        try {
            $commits = Get-CommitsFromFile -Path $tmp.FullName
            $commits.Count | Should -Be 3
            $commits[0] | Should -Match '^feat: a'
            $commits[1] | Should -Be 'fix: b'
            $commits[2] | Should -Be 'chore: c'
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }

    It 'returns an empty array for an empty file' {
        $tmp = New-TemporaryFile
        # New-TemporaryFile already creates an empty file; don't write to it
        # because Set-Content adds a trailing newline which makes the file
        # non-empty.
        try {
            @(Get-CommitsFromFile -Path $tmp.FullName).Count | Should -Be 0
        } finally {
            Remove-Item $tmp.FullName -Force
        }
    }
}

Describe 'Invoke-VersionBumper (end to end)' {
    BeforeEach {
        $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-" + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:work | Out-Null
    }
    AfterEach {
        if (Test-Path $script:work) {
            Remove-Item $script:work -Recurse -Force
        }
    }

    It 'feat commit bumps 1.1.0 to 1.2.0, writes file, writes changelog' {
        $pkg = Join-Path $script:work 'package.json'
        @'
{ "name": "demo", "version": "1.1.0" }
'@ | Set-Content -Path $pkg

        $log = Join-Path $script:work 'commits.txt'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("feat: add cool thing`0chore: tidy")
        [System.IO.File]::WriteAllBytes($log, $bytes)

        $changelog = Join-Path $script:work 'CHANGELOG.md'

        $newVersion = Invoke-VersionBumper -VersionFile $pkg -CommitsFile $log -ChangelogFile $changelog -Date '2026-05-07'

        $newVersion | Should -Be '1.2.0'
        ((Get-Content -Raw -Path $pkg) | ConvertFrom-Json).version | Should -Be '1.2.0'
        Get-Content -Raw -Path $changelog | Should -Match '## \[1\.2\.0\]'
        Get-Content -Raw -Path $changelog | Should -Match 'add cool thing'
    }

    It 'fix-only commits bump 0.1.0 to 0.1.1' {
        $pkg = Join-Path $script:work 'package.json'
        '{ "name": "demo", "version": "0.1.0" }' | Set-Content -Path $pkg
        $log = Join-Path $script:work 'commits.txt'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("fix: bug`0fix(scope): bug2")
        [System.IO.File]::WriteAllBytes($log, $bytes)
        $changelog = Join-Path $script:work 'CHANGELOG.md'

        $newVersion = Invoke-VersionBumper -VersionFile $pkg -CommitsFile $log -ChangelogFile $changelog -Date '2026-05-07'

        $newVersion | Should -Be '0.1.1'
    }

    It 'BREAKING CHANGE commits bump 1.4.2 to 2.0.0' {
        $pkg = Join-Path $script:work 'package.json'
        '{ "name": "demo", "version": "1.4.2" }' | Set-Content -Path $pkg
        $log = Join-Path $script:work 'commits.txt'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("feat!: new api`0fix: bug")
        [System.IO.File]::WriteAllBytes($log, $bytes)
        $changelog = Join-Path $script:work 'CHANGELOG.md'

        $newVersion = Invoke-VersionBumper -VersionFile $pkg -CommitsFile $log -ChangelogFile $changelog -Date '2026-05-07'

        $newVersion | Should -Be '2.0.0'
    }

    It 'no conventional commits keeps the same version and writes nothing to the changelog' {
        $pkg = Join-Path $script:work 'package.json'
        '{ "name": "demo", "version": "1.0.0" }' | Set-Content -Path $pkg
        $log = Join-Path $script:work 'commits.txt'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("chore: tidy`0docs: readme")
        [System.IO.File]::WriteAllBytes($log, $bytes)
        $changelog = Join-Path $script:work 'CHANGELOG.md'

        $newVersion = Invoke-VersionBumper -VersionFile $pkg -CommitsFile $log -ChangelogFile $changelog -Date '2026-05-07'

        $newVersion | Should -Be '1.0.0'
        # Changelog should not exist, or be empty
        (Test-Path $changelog) -and ((Get-Content -Raw -Path $changelog).Trim() -ne '') |
            Should -BeFalse
    }

    It 'prepends a new changelog entry on top of an existing one' {
        $pkg = Join-Path $script:work 'package.json'
        '{ "name": "demo", "version": "1.0.0" }' | Set-Content -Path $pkg
        $log = Join-Path $script:work 'commits.txt'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("feat: x")
        [System.IO.File]::WriteAllBytes($log, $bytes)
        $changelog = Join-Path $script:work 'CHANGELOG.md'
        "## [0.9.0] - 2026-04-01`n- old stuff" | Set-Content -Path $changelog

        Invoke-VersionBumper -VersionFile $pkg -CommitsFile $log -ChangelogFile $changelog -Date '2026-05-07' | Out-Null

        $content = Get-Content -Raw -Path $changelog
        $idxNew = $content.IndexOf('[1.1.0]')
        $idxOld = $content.IndexOf('[0.9.0]')
        $idxNew | Should -BeGreaterOrEqual 0
        $idxOld | Should -BeGreaterThan $idxNew
    }
}
