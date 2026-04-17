#requires -Module Pester

# Pester unit tests for the semantic version bumper.
# Exercised with `Invoke-Pester` from this directory.
# Each Describe/It pair was added red-then-green: we first asserted on
# behaviour that did not yet exist, then implemented the minimum code to
# make the assertion pass.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module SemanticVersionBumper -Force -ErrorAction SilentlyContinue
}

Describe 'Get-SemanticVersion' {
    It 'parses a plain semver string from a version.txt file' {
        $tmp = New-Item -ItemType File -Path (Join-Path ([IO.Path]::GetTempPath()) "v_$([guid]::NewGuid()).txt") -Force
        '1.2.3' | Set-Content -Path $tmp -NoNewline
        try {
            $v = Get-SemanticVersion -Path $tmp
            $v.Major | Should -Be 1
            $v.Minor | Should -Be 2
            $v.Patch | Should -Be 3
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'parses a version field out of package.json' {
        $tmp = New-Item -ItemType File -Path (Join-Path ([IO.Path]::GetTempPath()) "pkg_$([guid]::NewGuid()).json") -Force
        '{ "name": "demo", "version": "0.9.4" }' | Set-Content -Path $tmp
        try {
            $v = Get-SemanticVersion -Path $tmp
            $v.Major | Should -Be 0
            $v.Minor | Should -Be 9
            $v.Patch | Should -Be 4
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'strips a leading v prefix' {
        $tmp = New-Item -ItemType File -Path (Join-Path ([IO.Path]::GetTempPath()) "v_$([guid]::NewGuid()).txt") -Force
        'v2.5.7' | Set-Content -Path $tmp -NoNewline
        try {
            (Get-SemanticVersion -Path $tmp).Minor | Should -Be 5
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws a meaningful error when the file is missing' {
        { Get-SemanticVersion -Path '/definitely/not/a/real/path.txt' } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws when the content is not a valid semver' {
        $tmp = New-Item -ItemType File -Path (Join-Path ([IO.Path]::GetTempPath()) "bad_$([guid]::NewGuid()).txt") -Force
        'potato' | Set-Content -Path $tmp -NoNewline
        try {
            { Get-SemanticVersion -Path $tmp } | Should -Throw -ExpectedMessage '*valid semantic version*'
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-CommitBumpType' {
    It 'returns None for an empty list' {
        (Get-CommitBumpType -Commits @()) | Should -Be 'None'
    }

    It 'returns Patch for a fix commit' {
        (Get-CommitBumpType -Commits @('fix: handle null input')) | Should -Be 'Patch'
    }

    It 'returns Minor for a feat commit, even alongside fixes' {
        (Get-CommitBumpType -Commits @('fix: x', 'feat: add widget')) | Should -Be 'Minor'
    }

    It 'returns Major for a commit with a ! marker' {
        (Get-CommitBumpType -Commits @('feat!: drop v1 api', 'feat: ok')) | Should -Be 'Major'
    }

    It 'returns Major when a commit body contains BREAKING CHANGE:' {
        $commit = "feat: rewrite storage`n`nBREAKING CHANGE: payloads changed"
        (Get-CommitBumpType -Commits @($commit)) | Should -Be 'Major'
    }

    It 'returns None for chore/docs/style commits alone' {
        (Get-CommitBumpType -Commits @('docs: fix typo', 'chore: bump deps', 'style: whitespace')) |
            Should -Be 'None'
    }
}

Describe 'Step-SemanticVersion' {
    It 'bumps patch correctly' {
        $next = Step-SemanticVersion -Major 1 -Minor 2 -Patch 3 -Bump 'Patch'
        "$($next.Major).$($next.Minor).$($next.Patch)" | Should -Be '1.2.4'
    }
    It 'bumps minor and resets patch' {
        $next = Step-SemanticVersion -Major 1 -Minor 2 -Patch 3 -Bump 'Minor'
        "$($next.Major).$($next.Minor).$($next.Patch)" | Should -Be '1.3.0'
    }
    It 'bumps major and resets minor and patch' {
        $next = Step-SemanticVersion -Major 1 -Minor 2 -Patch 3 -Bump 'Major'
        "$($next.Major).$($next.Minor).$($next.Patch)" | Should -Be '2.0.0'
    }
    It 'is a no-op for None' {
        $next = Step-SemanticVersion -Major 1 -Minor 2 -Patch 3 -Bump 'None'
        "$($next.Major).$($next.Minor).$($next.Patch)" | Should -Be '1.2.3'
    }
}

Describe 'New-ChangelogEntry' {
    It 'groups commits under Features, Fixes, and Breaking Changes' {
        $commits = @(
            'feat: add a thing',
            'fix: correct a bug',
            "feat!: remove old api`n`nBREAKING CHANGE: gone"
        )
        $entry = New-ChangelogEntry -Version '1.2.0' -Date '2026-04-17' -Commits $commits
        $entry | Should -Match '## \[1\.2\.0\] - 2026-04-17'
        $entry | Should -Match '### Breaking Changes'
        $entry | Should -Match '### Features'
        $entry | Should -Match '### Fixes'
        $entry | Should -Match 'add a thing'
        $entry | Should -Match 'correct a bug'
    }

    It 'omits empty sections' {
        $entry = New-ChangelogEntry -Version '1.0.1' -Date '2026-04-17' -Commits @('fix: y')
        $entry | Should -Not -Match '### Features'
        $entry | Should -Match '### Fixes'
    }
}

Describe 'Set-SemanticVersion' {
    It 'writes an updated plain version file' {
        $tmp = New-Item -ItemType File -Path (Join-Path ([IO.Path]::GetTempPath()) "v_$([guid]::NewGuid()).txt") -Force
        '1.0.0' | Set-Content -Path $tmp -NoNewline
        try {
            Set-SemanticVersion -Path $tmp -Major 1 -Minor 1 -Patch 0
            (Get-Content -Raw $tmp).Trim() | Should -Be '1.1.0'
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'updates the version field inside package.json without clobbering other keys' {
        $tmp = New-Item -ItemType File -Path (Join-Path ([IO.Path]::GetTempPath()) "pkg_$([guid]::NewGuid()).json") -Force
        '{ "name": "demo", "version": "0.1.0", "scripts": { "test": "echo" } }' | Set-Content -Path $tmp
        try {
            Set-SemanticVersion -Path $tmp -Major 0 -Minor 2 -Patch 0
            $json = Get-Content -Raw $tmp | ConvertFrom-Json
            $json.version | Should -Be '0.2.0'
            $json.name | Should -Be 'demo'
            $json.scripts.test | Should -Be 'echo'
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Invoke-VersionBumper (integration)' {
    BeforeEach {
        $script:workDir = Join-Path ([IO.Path]::GetTempPath()) "bump_$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $script:workDir | Out-Null
    }
    AfterEach {
        Remove-Item $script:workDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'bumps 1.1.0 -> 1.2.0 given a feat commit and writes the changelog' {
        $versionFile = Join-Path $script:workDir 'version.txt'
        $commitFile = Join-Path $script:workDir 'commits.txt'
        $changelog = Join-Path $script:workDir 'CHANGELOG.md'

        '1.1.0' | Set-Content $versionFile -NoNewline
        "feat: add search`n---`nfix: handle empty input" | Set-Content $commitFile -NoNewline

        $result = Invoke-VersionBumper -VersionFile $versionFile -CommitLog $commitFile -ChangelogFile $changelog -Date '2026-04-17'
        $result.NewVersion | Should -Be '1.2.0'
        (Get-Content -Raw $versionFile).Trim() | Should -Be '1.2.0'
        (Get-Content -Raw $changelog) | Should -Match '## \[1\.2\.0\]'
        (Get-Content -Raw $changelog) | Should -Match 'add search'
    }

    It 'bumps 1.2.3 -> 2.0.0 when a commit has a breaking marker' {
        $versionFile = Join-Path $script:workDir 'version.txt'
        $commitFile = Join-Path $script:workDir 'commits.txt'

        '1.2.3' | Set-Content $versionFile -NoNewline
        'feat!: drop legacy endpoint' | Set-Content $commitFile -NoNewline

        $result = Invoke-VersionBumper -VersionFile $versionFile -CommitLog $commitFile -ChangelogFile (Join-Path $script:workDir 'CHANGELOG.md') -Date '2026-04-17'
        $result.NewVersion | Should -Be '2.0.0'
    }

    It 'bumps patch for fix-only commits' {
        $versionFile = Join-Path $script:workDir 'version.txt'
        $commitFile = Join-Path $script:workDir 'commits.txt'

        '0.5.0' | Set-Content $versionFile -NoNewline
        "fix: bug one`n---`nfix: bug two" | Set-Content $commitFile -NoNewline

        $result = Invoke-VersionBumper -VersionFile $versionFile -CommitLog $commitFile -ChangelogFile (Join-Path $script:workDir 'CHANGELOG.md') -Date '2026-04-17'
        $result.NewVersion | Should -Be '0.5.1'
    }

    It 'keeps the version unchanged when no release-worthy commits are present' {
        $versionFile = Join-Path $script:workDir 'version.txt'
        $commitFile = Join-Path $script:workDir 'commits.txt'

        '3.1.4' | Set-Content $versionFile -NoNewline
        "chore: deps`n---`ndocs: spelling" | Set-Content $commitFile -NoNewline

        $result = Invoke-VersionBumper -VersionFile $versionFile -CommitLog $commitFile -ChangelogFile (Join-Path $script:workDir 'CHANGELOG.md') -Date '2026-04-17'
        $result.NewVersion | Should -Be '3.1.4'
        $result.Bump | Should -Be 'None'
    }
}

Describe 'Workflow structure' {
    BeforeAll {
        $script:workflowPath = Join-Path $PSScriptRoot '.github/workflows/semantic-version-bumper.yml'
    }

    It 'the workflow file exists' {
        Test-Path $script:workflowPath | Should -BeTrue
    }

    It 'references Invoke-VersionBumper.ps1 from the workflow' {
        $scriptPath = Join-Path $PSScriptRoot 'Invoke-VersionBumper.ps1'
        Test-Path $scriptPath | Should -BeTrue
        (Get-Content -Raw $script:workflowPath) | Should -Match 'Invoke-VersionBumper\.ps1'
    }

    It 'contains push, workflow_dispatch, and pull_request triggers' {
        $yaml = Get-Content -Raw $script:workflowPath
        $yaml | Should -Match '(?m)^\s*push\s*:'
        $yaml | Should -Match 'workflow_dispatch'
        $yaml | Should -Match 'pull_request'
    }

    It 'actionlint passes' {
        $actionlint = (Get-Command actionlint -ErrorAction SilentlyContinue)?.Source
        if (-not $actionlint) { Set-ItResult -Skipped -Because 'actionlint not on PATH' ; return }
        & $actionlint $script:workflowPath
        $LASTEXITCODE | Should -Be 0
    }
}
