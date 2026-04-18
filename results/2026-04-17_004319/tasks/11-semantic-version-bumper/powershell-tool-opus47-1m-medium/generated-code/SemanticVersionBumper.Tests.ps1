# Pester 5 tests for SemanticVersionBumper.
# Follow red/green TDD: each Describe block documents a slice that drove the code.

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    Import-Module (Join-Path $here 'SemanticVersionBumper.psm1') -Force
    $script:FixturesDir = Join-Path $here 'fixtures'
}

Describe 'Get-CurrentVersion' {
    It 'reads version from a plain VERSION file' {
        $tmp = New-TemporaryFile
        '1.2.3' | Set-Content -Path $tmp -NoNewline
        Get-CurrentVersion -Path $tmp | Should -Be '1.2.3'
        Remove-Item $tmp
    }
    It 'reads version from package.json' {
        $tmp = [System.IO.Path]::ChangeExtension((New-TemporaryFile), '.json')
        '{"name":"x","version":"0.4.2"}' | Set-Content -Path $tmp -NoNewline
        Get-CurrentVersion -Path $tmp | Should -Be '0.4.2'
        Remove-Item $tmp
    }
    It 'throws on missing file' {
        { Get-CurrentVersion -Path '/no/such/file' } | Should -Throw
    }
    It 'throws on invalid semver' {
        $tmp = New-TemporaryFile
        'not-a-version' | Set-Content -Path $tmp -NoNewline
        { Get-CurrentVersion -Path $tmp } | Should -Throw
        Remove-Item $tmp
    }
}

Describe 'Get-BumpType' {
    It 'returns patch for a fix commit' {
        Get-BumpType -Commits @('fix: handle null input') | Should -Be 'patch'
    }
    It 'returns minor for a feat commit' {
        Get-BumpType -Commits @('feat: add login page') | Should -Be 'minor'
    }
    It 'returns major for breaking change via bang' {
        Get-BumpType -Commits @('feat!: drop v1 API') | Should -Be 'major'
    }
    It 'returns major for BREAKING CHANGE footer' {
        $c = "feat: rework auth`n`nBREAKING CHANGE: auth flow changed"
        Get-BumpType -Commits @($c) | Should -Be 'major'
    }
    It 'returns none when no conventional commits' {
        Get-BumpType -Commits @('chore: tidy', 'docs: readme') | Should -Be 'none'
    }
    It 'chooses highest bump across mixed commits' {
        Get-BumpType -Commits @('fix: a', 'feat: b', 'chore: c') | Should -Be 'minor'
        Get-BumpType -Commits @('fix: a', 'feat!: breaking') | Should -Be 'major'
    }
    It 'accepts scoped types like feat(api)' {
        Get-BumpType -Commits @('feat(api): new endpoint') | Should -Be 'minor'
        Get-BumpType -Commits @('fix(ui): bug') | Should -Be 'patch'
    }
}

Describe 'Step-Version' {
    It 'bumps patch' { Step-Version -Version '1.2.3' -BumpType patch | Should -Be '1.2.4' }
    It 'bumps minor and resets patch' { Step-Version -Version '1.2.3' -BumpType minor | Should -Be '1.3.0' }
    It 'bumps major and resets minor/patch' { Step-Version -Version '1.2.3' -BumpType major | Should -Be '2.0.0' }
    It 'returns same version for none' { Step-Version -Version '1.2.3' -BumpType none | Should -Be '1.2.3' }
    It 'throws on invalid input' { { Step-Version -Version 'abc' -BumpType patch } | Should -Throw }
}

Describe 'Set-CurrentVersion' {
    It 'updates plain VERSION file' {
        $tmp = New-TemporaryFile
        '1.0.0' | Set-Content -Path $tmp -NoNewline
        Set-CurrentVersion -Path $tmp -NewVersion '1.1.0'
        (Get-Content -Path $tmp -Raw).Trim() | Should -Be '1.1.0'
        Remove-Item $tmp
    }
    It 'updates package.json preserving other fields' {
        $tmp = [System.IO.Path]::ChangeExtension((New-TemporaryFile), '.json')
        '{"name":"pkg","version":"1.0.0","other":"v"}' | Set-Content -Path $tmp -NoNewline
        Set-CurrentVersion -Path $tmp -NewVersion '2.0.0'
        $obj = Get-Content -Path $tmp -Raw | ConvertFrom-Json
        $obj.version | Should -Be '2.0.0'
        $obj.name | Should -Be 'pkg'
        $obj.other | Should -Be 'v'
        Remove-Item $tmp
    }
}

Describe 'New-ChangelogEntry' {
    It 'produces a markdown header with the version and date' {
        $out = New-ChangelogEntry -Version '1.2.0' -Commits @('feat: add thing') -Date '2026-04-17'
        $out | Should -Match '## 1\.2\.0 - 2026-04-17'
    }
    It 'groups features and fixes into sections' {
        $out = New-ChangelogEntry -Version '1.2.0' -Commits @('feat: a', 'fix: b') -Date '2026-04-17'
        $out | Should -Match '### Features'
        $out | Should -Match '- feat: a'
        $out | Should -Match '### Fixes'
        $out | Should -Match '- fix: b'
    }
    It 'emits a BREAKING CHANGES section when present' {
        $out = New-ChangelogEntry -Version '2.0.0' -Commits @('feat!: remove legacy') -Date '2026-04-17'
        $out | Should -Match '### BREAKING CHANGES'
    }
}

Describe 'Invoke-VersionBump (end-to-end)' -Tag 'Integration' {
    BeforeEach {
        $script:tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("svb-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tmpDir | Out-Null
        $script:vf = Join-Path $script:tmpDir 'VERSION'
        $script:cf = Join-Path $script:tmpDir 'CHANGELOG.md'
        '1.1.0' | Set-Content -Path $script:vf -NoNewline
    }
    AfterEach {
        Remove-Item -Recurse -Force $script:tmpDir -ErrorAction SilentlyContinue
    }
    It 'bumps 1.1.0 + feat to 1.2.0' {
        $r = Invoke-VersionBump -VersionFile $script:vf -Commits @('feat: new thing') -ChangelogFile $script:cf
        $r.NewVersion | Should -Be '1.2.0'
        (Get-Content -Path $script:vf -Raw).Trim() | Should -Be '1.2.0'
        Test-Path $script:cf | Should -BeTrue
        (Get-Content -Path $script:cf -Raw) | Should -Match '## 1\.2\.0'
    }
    It 'bumps 1.1.0 + fix to 1.1.1' {
        $r = Invoke-VersionBump -VersionFile $script:vf -Commits @('fix: patch it') -ChangelogFile $script:cf
        $r.NewVersion | Should -Be '1.1.1'
    }
    It 'bumps 1.1.0 + breaking to 2.0.0' {
        $r = Invoke-VersionBump -VersionFile $script:vf -Commits @('feat!: breaking API') -ChangelogFile $script:cf
        $r.NewVersion | Should -Be '2.0.0'
    }
    It 'keeps version when no bumping commits' {
        $r = Invoke-VersionBump -VersionFile $script:vf -Commits @('chore: nothing') -ChangelogFile $script:cf
        $r.NewVersion | Should -Be '1.1.0'
        $r.BumpType | Should -Be 'none'
    }
    It 'works against fixture commit log files' {
        $fix = Join-Path $script:FixturesDir 'commits-feat.txt'
        $commits = Get-Content -Path $fix -Raw -Encoding utf8 -ErrorAction Stop
        # Split on double-null? We use a separator --COMMIT-- in fixtures.
        $list = $commits -split "(?m)^--COMMIT--\s*$" | Where-Object { $_.Trim() }
        $r = Invoke-VersionBump -VersionFile $script:vf -Commits $list -ChangelogFile $script:cf
        $r.NewVersion | Should -Be '1.2.0'
    }
}
