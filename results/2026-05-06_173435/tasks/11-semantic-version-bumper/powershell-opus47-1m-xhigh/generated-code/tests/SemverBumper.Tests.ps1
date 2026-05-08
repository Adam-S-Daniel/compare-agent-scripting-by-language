# Pester 5 tests for the semantic version bumper.
# TDD red/green cycle: each Describe was written failing first.

BeforeAll {
    # Resolve module path relative to this test file so tests run from any CWD.
    $ModulePath = Join-Path $PSScriptRoot '..' 'src' 'SemverBumper.psm1'
    Import-Module $ModulePath -Force
}

Describe 'ConvertTo-SemVer' {
    It 'parses a normal three-part version' {
        $v = ConvertTo-SemVer '1.2.3'
        $v.Major | Should -Be 1
        $v.Minor | Should -Be 2
        $v.Patch | Should -Be 3
    }

    It 'accepts a leading v prefix' {
        $v = ConvertTo-SemVer 'v0.0.1'
        $v.Major | Should -Be 0
        $v.Minor | Should -Be 0
        $v.Patch | Should -Be 1
    }

    It 'throws on garbage input' {
        { ConvertTo-SemVer 'not-a-version' } | Should -Throw
    }
}

Describe 'ConvertFrom-SemVer' {
    It 'round-trips a parsed version back to a string' {
        $v = ConvertTo-SemVer '4.5.6'
        ConvertFrom-SemVer $v | Should -Be '4.5.6'
    }
}

Describe 'Get-BumpKind' {
    It 'returns major for a breaking-change commit (! after type)' {
        Get-BumpKind @('feat!: drop legacy auth') | Should -Be 'major'
    }

    It 'returns major for BREAKING CHANGE in body' {
        $msg = "feat: rework api`n`nBREAKING CHANGE: removed v1 endpoints"
        Get-BumpKind @($msg) | Should -Be 'major'
    }

    It 'returns minor for a feat commit' {
        Get-BumpKind @('feat: add login button') | Should -Be 'minor'
    }

    It 'returns patch for a fix commit' {
        Get-BumpKind @('fix: stop crash on empty input') | Should -Be 'patch'
    }

    It 'major beats minor beats patch when commits are mixed' {
        $commits = @(
            'fix: minor thing',
            'feat: new feature',
            'feat!: breaking redesign'
        )
        Get-BumpKind $commits | Should -Be 'major'
    }

    It 'returns none when no commit triggers a bump' {
        Get-BumpKind @('chore: update build', 'docs: tweak readme') | Should -Be 'none'
    }

    It 'is case insensitive on the type token' {
        Get-BumpKind @('FEAT: shouty feature') | Should -Be 'minor'
    }

    It 'recognises a scope on the commit type (feat(api): ...)' {
        Get-BumpKind @('feat(api): new endpoint') | Should -Be 'minor'
        Get-BumpKind @('fix(api): bad header') | Should -Be 'patch'
        Get-BumpKind @('feat(api)!: drop endpoint') | Should -Be 'major'
    }
}

Describe 'Step-SemVer' {
    It 'bumps patch correctly' {
        $v = ConvertTo-SemVer '1.2.3'
        ConvertFrom-SemVer (Step-SemVer $v 'patch') | Should -Be '1.2.4'
    }

    It 'bumps minor and resets patch' {
        $v = ConvertTo-SemVer '1.2.3'
        ConvertFrom-SemVer (Step-SemVer $v 'minor') | Should -Be '1.3.0'
    }

    It 'bumps major and resets minor + patch' {
        $v = ConvertTo-SemVer '1.2.3'
        ConvertFrom-SemVer (Step-SemVer $v 'major') | Should -Be '2.0.0'
    }

    It 'returns the same version for a none bump' {
        $v = ConvertTo-SemVer '1.2.3'
        ConvertFrom-SemVer (Step-SemVer $v 'none') | Should -Be '1.2.3'
    }
}

Describe 'Read-VersionFile / Write-VersionFile' {
    It 'reads a plain VERSION file' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            $vf = Join-Path $tmp 'VERSION'
            Set-Content -Path $vf -Value '0.1.2' -NoNewline
            $r = Read-VersionFile -Path $vf
            $r.Version | Should -Be '0.1.2'
            $r.Format  | Should -Be 'plain'
        }
        finally { Remove-Item -Recurse -Force $tmp }
    }

    It 'reads a package.json file' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            $vf = Join-Path $tmp 'package.json'
            Set-Content -Path $vf -Value '{ "name": "demo", "version": "3.4.5" }'
            $r = Read-VersionFile -Path $vf
            $r.Version | Should -Be '3.4.5'
            $r.Format  | Should -Be 'package.json'
        }
        finally { Remove-Item -Recurse -Force $tmp }
    }

    It 'writes back a plain VERSION file' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            $vf = Join-Path $tmp 'VERSION'
            Set-Content -Path $vf -Value '0.1.2' -NoNewline
            Write-VersionFile -Path $vf -Format 'plain' -Version '0.1.3'
            (Get-Content -Raw $vf).Trim() | Should -Be '0.1.3'
        }
        finally { Remove-Item -Recurse -Force $tmp }
    }

    It 'writes back a package.json preserving other fields' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            $vf = Join-Path $tmp 'package.json'
            $original = '{ "name": "demo", "version": "3.4.5", "description": "x" }'
            Set-Content -Path $vf -Value $original
            Write-VersionFile -Path $vf -Format 'package.json' -Version '3.5.0'
            $obj = Get-Content -Raw $vf | ConvertFrom-Json
            $obj.version     | Should -Be '3.5.0'
            $obj.name        | Should -Be 'demo'
            $obj.description | Should -Be 'x'
        }
        finally { Remove-Item -Recurse -Force $tmp }
    }

    It 'auto-detects VERSION when no path given' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            Set-Content -Path (Join-Path $tmp 'VERSION') -Value '7.8.9' -NoNewline
            $r = Find-VersionFile -RepoRoot $tmp
            $r.Path   | Should -BeLike '*VERSION'
            $r.Format | Should -Be 'plain'
        }
        finally { Remove-Item -Recurse -Force $tmp }
    }

    It 'auto-detects package.json over plain VERSION when both present' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            Set-Content -Path (Join-Path $tmp 'VERSION') -Value '0.0.1' -NoNewline
            Set-Content -Path (Join-Path $tmp 'package.json') -Value '{"version":"1.0.0"}'
            $r = Find-VersionFile -RepoRoot $tmp
            $r.Format | Should -Be 'package.json'
        }
        finally { Remove-Item -Recurse -Force $tmp }
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits under Features / Fixes / BREAKING' {
        $entry = New-ChangelogEntry -NewVersion '1.2.0' -Commits @(
            'feat: add login',
            'fix: trim whitespace',
            'feat!: drop ie11',
            'chore: bump deps'
        ) -Date '2026-01-02'

        $entry | Should -Match '## \[1\.2\.0\] - 2026-01-02'
        $entry | Should -Match '### Features'
        $entry | Should -Match 'add login'
        $entry | Should -Match '### Bug Fixes'
        $entry | Should -Match 'trim whitespace'
        $entry | Should -Match '### BREAKING CHANGES'
        $entry | Should -Match 'drop ie11'
        # 'chore' commits are not surfaced in the changelog
        $entry | Should -Not -Match 'bump deps'
    }
}

Describe 'Invoke-VersionBump (end-to-end)' {
    It 'bumps a VERSION file, writes a changelog, and reports the new version' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            Set-Content -Path (Join-Path $tmp 'VERSION') -Value '1.0.0' -NoNewline

            $commits = @('feat: add cli flag', 'fix: handle empty input')
            $result  = Invoke-VersionBump -RepoRoot $tmp -CommitMessages $commits -Date '2026-05-07'

            $result.NewVersion | Should -Be '1.1.0'
            $result.OldVersion | Should -Be '1.0.0'
            $result.BumpKind   | Should -Be 'minor'

            (Get-Content -Raw (Join-Path $tmp 'VERSION')).Trim() | Should -Be '1.1.0'

            $changelog = Get-Content -Raw (Join-Path $tmp 'CHANGELOG.md')
            $changelog | Should -Match '## \[1\.1\.0\] - 2026-05-07'
            $changelog | Should -Match 'add cli flag'
            $changelog | Should -Match 'handle empty input'
        }
        finally { Remove-Item -Recurse -Force $tmp }
    }

    It 'returns BumpKind=none and leaves files untouched when no semantic commits found' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            Set-Content -Path (Join-Path $tmp 'VERSION') -Value '1.0.0' -NoNewline

            $commits = @('chore: tweak ci', 'docs: edit readme')
            $result  = Invoke-VersionBump -RepoRoot $tmp -CommitMessages $commits -Date '2026-05-07'

            $result.NewVersion | Should -Be '1.0.0'
            $result.BumpKind   | Should -Be 'none'
            (Test-Path (Join-Path $tmp 'CHANGELOG.md')) | Should -BeFalse
        }
        finally { Remove-Item -Recurse -Force $tmp }
    }
}
