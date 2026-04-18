#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

# Workflow/pipeline tests — everything is driven through `act push`.
# These are intentionally slow integration tests: one `act push` per fixture.

BeforeDiscovery {
    $script:Here = $PSScriptRoot
    $script:WorkflowPath = Join-Path $Here '.github/workflows/semantic-version-bumper.yml'
    $script:ActResult = Join-Path $Here 'act-result.txt'
}

BeforeAll {
    $script:Here = $PSScriptRoot
    $script:WorkflowPath = Join-Path $Here '.github/workflows/semantic-version-bumper.yml'
    $script:ActResult = Join-Path $Here 'act-result.txt'
    # act-result.txt accumulates output from every test case run through act.
    # Reset each run so the artifact reflects only the current test invocation.
    if (Test-Path $script:ActResult) { Remove-Item $script:ActResult -Force }
    "" | Set-Content -LiteralPath $script:ActResult

    # Helper: sets up a disposable git repo with the workflow + module + fixture
    # data, runs `act push`, appends delimited output to act-result.txt, and
    # returns a hashtable of the captured info.
    function global:Invoke-ActForFixture {
        param(
            [Parameter(Mandatory)][string]$Label,
            [Parameter(Mandatory)][string]$VersionFileSource,
            [Parameter(Mandatory)][string]$VersionFileName,
            [Parameter(Mandatory)][string]$CommitsFileSource,
            [Parameter(Mandatory)][string]$ActResultPath,
            [Parameter(Mandatory)][string]$SourceRoot
        )

        $workdir = Join-Path ([IO.Path]::GetTempPath()) ("svb-$Label-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $workdir | Out-Null

        Copy-Item -Recurse -Force (Join-Path $SourceRoot '.github') (Join-Path $workdir '.github')
        Copy-Item -Force (Join-Path $SourceRoot 'VersionBumper.psm1')    $workdir
        Copy-Item -Force (Join-Path $SourceRoot 'VersionBumper.Tests.ps1') $workdir
        Copy-Item -Force (Join-Path $SourceRoot 'bump-version.ps1')       $workdir
        if (Test-Path (Join-Path $SourceRoot '.actrc')) {
            Copy-Item -Force (Join-Path $SourceRoot '.actrc') $workdir
        }

        Copy-Item -Force $VersionFileSource  (Join-Path $workdir $VersionFileName)
        Copy-Item -Force $CommitsFileSource  (Join-Path $workdir 'commits.txt')

        Push-Location $workdir
        try {
            git init -q . | Out-Null
            git -c user.email=ci@local -c user.name=ci add -A | Out-Null
            git -c user.email=ci@local -c user.name=ci commit -q -m 'init' | Out-Null

            $envFile = Join-Path $workdir 'act.env'
            @(
                "VERSION_FILE=$VersionFileName",
                "COMMITS_FILE=commits.txt",
                "CHANGELOG_FILE=CHANGELOG.md"
            ) | Set-Content -LiteralPath $envFile

            $raw = & act push --env-file act.env --rm 2>&1
            $code = $LASTEXITCODE

            $banner = "`n===== act push [$Label] exit=$code ====="
            Add-Content -LiteralPath $ActResultPath -Value $banner
            Add-Content -LiteralPath $ActResultPath -Value ($raw -join "`n")
            Add-Content -LiteralPath $ActResultPath -Value "===== end [$Label] =====`n"

            return @{
                ExitCode  = $code
                Output    = ($raw -join "`n")
                Workdir   = $workdir
            }
        }
        finally {
            Pop-Location
        }
    }
}

Describe 'Workflow structure' {
    It 'has the workflow file on disk' {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It 'passes actionlint' {
        $out = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($out -join "`n")
    }

    Context 'YAML structure' {
        BeforeAll {
            # Parse YAML with PyYAML. In YAML 1.1 `on` and `off` resolve to booleans,
            # which would turn the workflow's `on:` key into True. We remove the bool
            # resolver for those tokens before loading so we get string keys back.
            $pyScript = @'
import sys, json, yaml
Loader = yaml.SafeLoader
yaml.resolver.Resolver.yaml_implicit_resolvers = {
    k: [r for r in v if r[0] != 'tag:yaml.org,2002:bool']
    for k, v in yaml.resolver.Resolver.yaml_implicit_resolvers.items()
}
print(json.dumps(yaml.load(open(sys.argv[1]), Loader=Loader)))
'@
            $script:Yaml = python3 -c $pyScript $script:WorkflowPath | ConvertFrom-Json
        }

        It 'defines the expected triggers' {
            $on = $script:Yaml.'on'
            $on.PSObject.Properties.Name | Should -Contain 'push'
            $on.PSObject.Properties.Name | Should -Contain 'pull_request'
            $on.PSObject.Properties.Name | Should -Contain 'workflow_dispatch'
        }

        It 'defines a job named bump' {
            $script:Yaml.jobs.PSObject.Properties.Name | Should -Contain 'bump'
        }

        It 'checks out the code via actions/checkout@v4' {
            $steps = $script:Yaml.jobs.bump.steps
            ($steps | Where-Object { $_.uses -eq 'actions/checkout@v4' }) | Should -Not -BeNullOrEmpty
        }

        It 'references the bumper script in a step' {
            $steps = $script:Yaml.jobs.bump.steps
            ($steps | Where-Object { $_.run -match 'bump-version\.ps1' }) | Should -Not -BeNullOrEmpty
        }

        It 'references files that exist on disk' {
            Test-Path (Join-Path $script:Here 'bump-version.ps1')    | Should -BeTrue
            Test-Path (Join-Path $script:Here 'VersionBumper.psm1') | Should -BeTrue
            Test-Path (Join-Path $script:Here 'VersionBumper.Tests.ps1') | Should -BeTrue
        }
    }
}

Describe 'Workflow through act' -Tag 'Act' {

    Context 'patch bump (1.2.3 + fixes -> 1.2.4)' {
        BeforeAll {
            $script:patch = Invoke-ActForFixture `
                -Label 'patch' `
                -VersionFileSource (Join-Path $script:Here 'fixtures/patch/VERSION') `
                -VersionFileName 'VERSION' `
                -CommitsFileSource (Join-Path $script:Here 'fixtures/patch/commits.txt') `
                -ActResultPath $script:ActResult `
                -SourceRoot $script:Here
        }

        It 'act exits 0' {
            $script:patch.ExitCode | Should -Be 0 -Because $script:patch.Output
        }
        It 'prints version=1.2.4 exactly' {
            $script:patch.Output | Should -Match 'NEW_VERSION_MARKER=1\.2\.4(\b|$)'
        }
        It 'does NOT print any other version bump' {
            $script:patch.Output | Should -Not -Match 'NEW_VERSION_MARKER=1\.3\.'
            $script:patch.Output | Should -Not -Match 'NEW_VERSION_MARKER=2\.'
        }
        It 'shows Job succeeded' {
            $script:patch.Output | Should -Match 'Job succeeded'
        }
    }

    Context 'minor bump (1.1.0 + feat -> 1.2.0)' {
        BeforeAll {
            $script:minor = Invoke-ActForFixture `
                -Label 'minor' `
                -VersionFileSource (Join-Path $script:Here 'fixtures/minor/VERSION') `
                -VersionFileName 'VERSION' `
                -CommitsFileSource (Join-Path $script:Here 'fixtures/minor/commits.txt') `
                -ActResultPath $script:ActResult `
                -SourceRoot $script:Here
        }

        It 'act exits 0' {
            $script:minor.ExitCode | Should -Be 0 -Because $script:minor.Output
        }
        It 'prints version=1.2.0 exactly' {
            $script:minor.Output | Should -Match 'NEW_VERSION_MARKER=1\.2\.0(\b|$)'
        }
        It 'shows Job succeeded' {
            $script:minor.Output | Should -Match 'Job succeeded'
        }
    }

    Context 'major bump (2.5.7 + refactor! -> 3.0.0)' {
        BeforeAll {
            $script:major = Invoke-ActForFixture `
                -Label 'major' `
                -VersionFileSource (Join-Path $script:Here 'fixtures/major/VERSION') `
                -VersionFileName 'VERSION' `
                -CommitsFileSource (Join-Path $script:Here 'fixtures/major/commits.txt') `
                -ActResultPath $script:ActResult `
                -SourceRoot $script:Here
        }

        It 'act exits 0' {
            $script:major.ExitCode | Should -Be 0 -Because $script:major.Output
        }
        It 'prints version=3.0.0 exactly' {
            $script:major.Output | Should -Match 'NEW_VERSION_MARKER=3\.0\.0(\b|$)'
        }
        It 'shows Job succeeded' {
            $script:major.Output | Should -Match 'Job succeeded'
        }
    }
}
