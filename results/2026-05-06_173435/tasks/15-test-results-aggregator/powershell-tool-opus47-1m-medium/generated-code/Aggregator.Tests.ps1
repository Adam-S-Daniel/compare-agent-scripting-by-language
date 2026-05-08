# Pester tests for the test-results aggregator.
# Pester 5.x style. Run with: Invoke-Pester -Path Aggregator.Tests.ps1

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'Aggregator.psm1'
    Import-Module $script:ModulePath -Force
}

Describe 'Read-JUnitXml' {
    BeforeAll {
        $script:JUnitSample = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suite_a" tests="3" failures="1" skipped="1" time="0.42">
    <testcase classname="Math" name="adds" time="0.10"/>
    <testcase classname="Math" name="divides" time="0.30">
      <failure message="div by zero">stack...</failure>
    </testcase>
    <testcase classname="Math" name="subtracts" time="0.02">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>
'@
    }

    It 'parses test cases out of JUnit XML' {
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value $script:JUnitSample -Encoding UTF8
        try {
            $r = Read-JUnitXml -Path $tmp
            $r.Tests.Count | Should -Be 3
            ($r.Tests | Where-Object { $_.Name -eq 'adds' }).Status | Should -Be 'passed'
            ($r.Tests | Where-Object { $_.Name -eq 'divides' }).Status | Should -Be 'failed'
            ($r.Tests | Where-Object { $_.Name -eq 'subtracts' }).Status | Should -Be 'skipped'
            ($r.Tests | Where-Object { $_.Name -eq 'adds' }).Duration | Should -Be 0.10
        } finally { Remove-Item $tmp -Force }
    }

    It 'returns a useful error for missing files' {
        { Read-JUnitXml -Path '/no/such/file.xml' } | Should -Throw '*not found*'
    }

    It 'returns a useful error for malformed XML' {
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value '<not xml' -Encoding UTF8
        try {
            { Read-JUnitXml -Path $tmp } | Should -Throw '*JUnit*'
        } finally { Remove-Item $tmp -Force }
    }
}

Describe 'Read-TestJson' {
    It 'parses tests out of a JSON results file' {
        $tmp = New-TemporaryFile
        $json = @'
{
  "tests": [
    {"classname":"Math","name":"adds","status":"passed","duration":0.1},
    {"classname":"Math","name":"divides","status":"failed","duration":0.3,"message":"x"}
  ]
}
'@
        Set-Content -Path $tmp -Value $json -Encoding UTF8
        try {
            $r = Read-TestJson -Path $tmp
            $r.Tests.Count | Should -Be 2
            ($r.Tests | Where-Object { $_.Name -eq 'divides' }).Status | Should -Be 'failed'
        } finally { Remove-Item $tmp -Force }
    }

    It 'errors on invalid JSON' {
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value '{not json' -Encoding UTF8
        try {
            { Read-TestJson -Path $tmp } | Should -Throw '*JSON*'
        } finally { Remove-Item $tmp -Force }
    }
}

Describe 'Read-TestResultFile dispatches by extension' {
    It 'reads .xml as JUnit' {
        $tmp = [IO.Path]::ChangeExtension((New-TemporaryFile), '.xml')
        Set-Content -Path $tmp -Value '<testsuites><testsuite name="s"><testcase classname="C" name="t" time="0.01"/></testsuite></testsuites>' -Encoding UTF8
        try {
            $r = Read-TestResultFile -Path $tmp
            $r.Tests.Count | Should -Be 1
        } finally { Remove-Item $tmp -Force }
    }

    It 'reads .json as JSON' {
        $tmp = [IO.Path]::ChangeExtension((New-TemporaryFile), '.json')
        Set-Content -Path $tmp -Value '{"tests":[{"classname":"C","name":"t","status":"passed","duration":0.01}]}' -Encoding UTF8
        try {
            $r = Read-TestResultFile -Path $tmp
            $r.Tests.Count | Should -Be 1
        } finally { Remove-Item $tmp -Force }
    }

    It 'errors on unknown extension' {
        $tmp = [IO.Path]::ChangeExtension((New-TemporaryFile), '.txt')
        Set-Content -Path $tmp -Value 'x'
        try { { Read-TestResultFile -Path $tmp } | Should -Throw '*Unsupported*' }
        finally { Remove-Item $tmp -Force }
    }
}

Describe 'Merge-TestResults' {
    BeforeAll {
        # Three "matrix" runs of the same suite. `flaky_test` passes once and
        # fails once; `always_fail` always fails; `stable` always passes.
        $script:Run1 = [pscustomobject]@{
            File   = 'run1.xml'
            Tests  = @(
                [pscustomobject]@{ ClassName='Suite'; Name='stable';      Status='passed'; Duration=0.1 }
                [pscustomobject]@{ ClassName='Suite'; Name='flaky_test';  Status='passed'; Duration=0.2 }
                [pscustomobject]@{ ClassName='Suite'; Name='always_fail'; Status='failed'; Duration=0.3; Message='boom' }
            )
        }
        $script:Run2 = [pscustomobject]@{
            File   = 'run2.xml'
            Tests  = @(
                [pscustomobject]@{ ClassName='Suite'; Name='stable';      Status='passed'; Duration=0.1 }
                [pscustomobject]@{ ClassName='Suite'; Name='flaky_test';  Status='failed'; Duration=0.2; Message='race' }
                [pscustomobject]@{ ClassName='Suite'; Name='always_fail'; Status='failed'; Duration=0.3; Message='boom' }
                [pscustomobject]@{ ClassName='Suite'; Name='skipper';     Status='skipped';Duration=0.0 }
            )
        }
    }

    It 'computes total counts and duration' {
        $a = Merge-TestResults -Runs @($script:Run1, $script:Run2)
        $a.Totals.Passed  | Should -Be 3   # stable*2 + flaky_test*1
        $a.Totals.Failed  | Should -Be 3   # always_fail*2 + flaky_test*1
        $a.Totals.Skipped | Should -Be 1
        [math]::Round($a.Totals.Duration, 2) | Should -Be 1.20
    }

    It 'identifies flaky tests (passed in some runs, failed in others)' {
        $a = Merge-TestResults -Runs @($script:Run1, $script:Run2)
        $a.Flaky.Count | Should -Be 1
        $a.Flaky[0].Name | Should -Be 'flaky_test'
    }

    It 'lists tests that always failed separately from flaky' {
        $a = Merge-TestResults -Runs @($script:Run1, $script:Run2)
        ($a.Failed | Where-Object { $_.Name -eq 'always_fail' }) | Should -Not -BeNullOrEmpty
        ($a.Failed | Where-Object { $_.Name -eq 'flaky_test'  }) | Should -BeNullOrEmpty
    }
}

Describe 'Format-MarkdownSummary' {
    BeforeAll {
        $script:Aggregate = [pscustomobject]@{
            Totals = [pscustomobject]@{ Passed=3; Failed=3; Skipped=1; Duration=1.5; Runs=2 }
            Flaky  = @([pscustomobject]@{ Key='Suite.flaky_test'; ClassName='Suite'; Name='flaky_test'; PassCount=1; FailCount=1; Runs=2 })
            Failed = @([pscustomobject]@{ Key='Suite.always_fail'; ClassName='Suite'; Name='always_fail'; FailCount=2; Runs=2; Message='boom' })
            Files  = @(
                [pscustomobject]@{ File='run1.xml'; Passed=2; Failed=1; Skipped=0; Duration=0.6 }
                [pscustomobject]@{ File='run2.xml'; Passed=1; Failed=2; Skipped=1; Duration=0.6 }
            )
        }
    }

    It 'emits a markdown header' {
        (Format-MarkdownSummary -Aggregate $script:Aggregate) | Should -Match '# Test Results'
    }

    It 'reports totals' {
        $md = Format-MarkdownSummary -Aggregate $script:Aggregate
        $md | Should -Match 'Passed.*3'
        $md | Should -Match 'Failed.*3'
        $md | Should -Match 'Skipped.*1'
    }

    It 'lists flaky tests in a Flaky section' {
        $md = Format-MarkdownSummary -Aggregate $script:Aggregate
        $md | Should -Match '## Flaky'
        $md | Should -Match 'flaky_test'
    }

    It 'lists failed tests in a Failed section' {
        $md = Format-MarkdownSummary -Aggregate $script:Aggregate
        $md | Should -Match '## Failed'
        $md | Should -Match 'always_fail'
    }

    It 'emits a per-file breakdown' {
        $md = Format-MarkdownSummary -Aggregate $script:Aggregate
        $md | Should -Match 'run1.xml'
        $md | Should -Match 'run2.xml'
    }
}

Describe 'Invoke-Aggregator (end-to-end CLI helper)' {
    It 'reads every fixture in a directory and writes a markdown file' {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("agg_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir | Out-Null
        try {
            Set-Content -Path (Join-Path $dir 'r1.xml') -Encoding UTF8 -Value @'
<testsuites><testsuite name="s">
  <testcase classname="C" name="t1" time="0.10"/>
  <testcase classname="C" name="flaky" time="0.20"/>
</testsuite></testsuites>
'@
            Set-Content -Path (Join-Path $dir 'r2.json') -Encoding UTF8 -Value @'
{"tests":[
  {"classname":"C","name":"t1","status":"passed","duration":0.1},
  {"classname":"C","name":"flaky","status":"failed","duration":0.2,"message":"x"}
]}
'@
            $out = Join-Path $dir 'summary.md'
            Invoke-Aggregator -InputDir $dir -OutFile $out
            Test-Path $out | Should -BeTrue
            $md = Get-Content $out -Raw
            $md | Should -Match '## Flaky'
            $md | Should -Match 'flaky'
        } finally { Remove-Item $dir -Recurse -Force }
    }
}
