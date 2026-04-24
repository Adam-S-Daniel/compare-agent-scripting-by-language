# Pester 5 tests for the semantic version bumper functions.
# Each Describe block follows red-green-refactor: the function under test is
# introduced only after the failing test exists.

BeforeAll {
    . "$PSScriptRoot/SemanticVersionBumper.ps1"
}

Describe 'Get-BumpTypeFromCommits' {
    It 'returns "none" for empty commit list' {
        Get-BumpTypeFromCommits -Commits @() | Should -Be 'none'
    }

    It 'returns "patch" for a fix: commit' {
        Get-BumpTypeFromCommits -Commits @('fix: correct typo') | Should -Be 'patch'
    }

    It 'returns "minor" for a feat: commit' {
        Get-BumpTypeFromCommits -Commits @('feat: add login') | Should -Be 'minor'
    }

    It 'returns "minor" when both feat and fix are present' {
        Get-BumpTypeFromCommits -Commits @('fix: x', 'feat: y') | Should -Be 'minor'
    }

    It 'returns "major" for a BREAKING CHANGE footer' {
        $c = @("feat: new api`n`nBREAKING CHANGE: removed old endpoint")
        Get-BumpTypeFromCommits -Commits $c | Should -Be 'major'
    }

    It 'returns "major" for a feat! style commit' {
        Get-BumpTypeFromCommits -Commits @('feat!: drop support') | Should -Be 'major'
    }

    It 'returns "major" for a scoped fix(x)!: commit' {
        Get-BumpTypeFromCommits -Commits @('fix(api)!: rename route') | Should -Be 'major'
    }

    It 'ignores non-conventional commits' {
        Get-BumpTypeFromCommits -Commits @('random commit', 'chore: cleanup') | Should -Be 'none'
    }
}

Describe 'Get-NextVersion' {
    It 'bumps patch' {
        Get-NextVersion -Current '1.2.3' -BumpType 'patch' | Should -Be '1.2.4'
    }
    It 'bumps minor and resets patch' {
        Get-NextVersion -Current '1.2.3' -BumpType 'minor' | Should -Be '1.3.0'
    }
    It 'bumps major and resets minor+patch' {
        Get-NextVersion -Current '1.2.3' -BumpType 'major' | Should -Be '2.0.0'
    }
    It 'returns same version for none' {
        Get-NextVersion -Current '1.2.3' -BumpType 'none' | Should -Be '1.2.3'
    }
    It 'throws on malformed version' {
        { Get-NextVersion -Current 'not-a-version' -BumpType 'patch' } | Should -Throw
    }
}

Describe 'Get-CurrentVersion' {
    It 'reads version from package.json' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid()))
        try {
            $pkg = Join-Path $tmp 'package.json'
            Set-Content -Path $pkg -Value '{ "name": "x", "version": "0.4.2" }'
            Get-CurrentVersion -Path $pkg | Should -Be '0.4.2'
        } finally {
            Remove-Item -Recurse -Force $tmp
        }
    }

    It 'reads version from plain VERSION file' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid()))
        try {
            $vf = Join-Path $tmp 'VERSION'
            Set-Content -Path $vf -Value "1.0.0`n"
            Get-CurrentVersion -Path $vf | Should -Be '1.0.0'
        } finally {
            Remove-Item -Recurse -Force $tmp
        }
    }

    It 'throws a meaningful error when file missing' {
        { Get-CurrentVersion -Path '/nonexistent/xyz' } | Should -Throw '*not found*'
    }
}

Describe 'Set-NewVersion' {
    It 'writes version back to package.json preserving other fields' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid()))
        try {
            $pkg = Join-Path $tmp 'package.json'
            Set-Content -Path $pkg -Value '{ "name": "x", "version": "0.1.0", "description": "d" }'
            Set-NewVersion -Path $pkg -NewVersion '0.2.0'
            $json = Get-Content $pkg -Raw | ConvertFrom-Json
            $json.version | Should -Be '0.2.0'
            $json.name | Should -Be 'x'
            $json.description | Should -Be 'd'
        } finally {
            Remove-Item -Recurse -Force $tmp
        }
    }

    It 'writes version to plain VERSION file' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid()))
        try {
            $vf = Join-Path $tmp 'VERSION'
            Set-Content -Path $vf -Value '1.0.0'
            Set-NewVersion -Path $vf -NewVersion '1.1.0'
            (Get-Content $vf -Raw).Trim() | Should -Be '1.1.0'
        } finally {
            Remove-Item -Recurse -Force $tmp
        }
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits into Features / Fixes / Breaking sections' {
        $commits = @(
            'feat: add A',
            'fix: correct B',
            "feat!: remove C`n`nBREAKING CHANGE: old api gone"
        )
        $entry = New-ChangelogEntry -Version '2.0.0' -Commits $commits -Date '2026-04-19'
        $entry | Should -Match '## \[2\.0\.0\] - 2026-04-19'
        $entry | Should -Match '### Breaking Changes'
        $entry | Should -Match '### Features'
        $entry | Should -Match '### Fixes'
        $entry | Should -Match 'add A'
        $entry | Should -Match 'correct B'
        $entry | Should -Match 'remove C'
    }

    It 'omits sections with no commits' {
        $entry = New-ChangelogEntry -Version '1.0.1' -Commits @('fix: x') -Date '2026-04-19'
        $entry | Should -Not -Match 'Features'
        $entry | Should -Not -Match 'Breaking'
        $entry | Should -Match 'Fixes'
    }
}

Describe 'Invoke-VersionBump (integration)' {
    It 'bumps package.json version and writes changelog' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid()))
        try {
            $pkg = Join-Path $tmp 'package.json'
            Set-Content -Path $pkg -Value '{ "name": "x", "version": "1.1.0" }'
            $log = Join-Path $tmp 'commits.txt'
            Set-Content -Path $log -Value "feat: cool thing`n---`nfix: minor"
            $chg = Join-Path $tmp 'CHANGELOG.md'

            $result = Invoke-VersionBump -VersionFile $pkg -CommitLogFile $log -ChangelogFile $chg -Date '2026-04-19'
            $result.NewVersion | Should -Be '1.2.0'
            $result.OldVersion | Should -Be '1.1.0'
            $result.BumpType  | Should -Be 'minor'
            (Get-Content $pkg -Raw | ConvertFrom-Json).version | Should -Be '1.2.0'
            (Get-Content $chg -Raw) | Should -Match '1\.2\.0'
        } finally {
            Remove-Item -Recurse -Force $tmp
        }
    }

    It 'returns none when no bumpable commits' {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid()))
        try {
            $pkg = Join-Path $tmp 'package.json'
            Set-Content -Path $pkg -Value '{ "version": "1.0.0" }'
            $log = Join-Path $tmp 'commits.txt'
            Set-Content -Path $log -Value 'chore: cleanup'
            $chg = Join-Path $tmp 'CHANGELOG.md'
            $r = Invoke-VersionBump -VersionFile $pkg -CommitLogFile $log -ChangelogFile $chg
            $r.NewVersion | Should -Be '1.0.0'
            $r.BumpType | Should -Be 'none'
        } finally {
            Remove-Item -Recurse -Force $tmp
        }
    }
}
