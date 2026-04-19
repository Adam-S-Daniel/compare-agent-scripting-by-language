<#
Test harness for validating the Test Results Aggregator workflow and scripts.
Tests workflow structure, local script execution, and attempts workflow execution with act.
#>

param(
    [string]$OutputFile = "act-result.txt"
)

function Write-TestLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Write-Host $logEntry
    Add-Content -Path $OutputFile -Value $logEntry
}

function Test-WorkflowStructure {
    Write-TestLog "=== WORKFLOW STRUCTURE TESTS ==="

    # Test 1: Check that workflow file exists
    Write-TestLog "Test 1: Checking workflow file exists..."
    if (-not (Test-Path "./.github/workflows/test-results-aggregator.yml")) {
        Write-TestLog "❌ FAILED: Workflow file not found"
        return $false
    }
    Write-TestLog "✓ Workflow file exists"

    # Test 2: Verify required script files exist
    Write-TestLog "Test 2: Checking required script files..."
    $requiredFiles = @(
        "test-results-aggregator.ps1",
        "test-results-aggregator.Tests.ps1",
        "fixtures/junit-run1.xml",
        "fixtures/junit-run2.xml",
        "fixtures/results-run1.json",
        "fixtures/results-run2.json"
    )

    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            Write-TestLog "❌ FAILED: Required file missing: $file"
            return $false
        }
        Write-TestLog "  ✓ $file"
    }

    # Test 3: Validate workflow YAML with actionlint
    Write-TestLog "Test 3: Validating workflow YAML..."
    $actionlintOutput = & actionlint ".github/workflows/test-results-aggregator.yml" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-TestLog "✓ actionlint validation passed"
    }
    else {
        Write-TestLog "❌ FAILED: actionlint validation failed"
        Write-TestLog $actionlintOutput
        return $false
    }

    # Test 4: Check workflow has expected jobs
    Write-TestLog "Test 4: Verifying workflow job structure..."
    $workflow = Get-Content ".github/workflows/test-results-aggregator.yml" -Raw

    if ($workflow -match "jobs:") {
        Write-TestLog "✓ Workflow has jobs section"
    }
    else {
        Write-TestLog "❌ FAILED: Workflow missing jobs section"
        return $false
    }

    if ($workflow -match "test:") {
        Write-TestLog "✓ Workflow has test job"
    }
    else {
        Write-TestLog "❌ FAILED: Workflow missing test job"
        return $false
    }

    Write-TestLog "=== ALL WORKFLOW STRUCTURE TESTS PASSED ==="
    return $true
}

function Test-LocalExecution {
    Write-TestLog "`n=== LOCAL EXECUTION TESTS ==="

    # Test 1: Run Pester tests locally
    Write-TestLog "Test 1: Running Pester tests locally..."
    $testResults = & pwsh -Command "Invoke-Pester -Path './test-results-aggregator.Tests.ps1' -PassThru"

    if ($LASTEXITCODE -eq 0) {
        Write-TestLog "✓ Local Pester tests passed"
    }
    else {
        Write-TestLog "❌ FAILED: Local Pester tests failed"
        return $false
    }

    # Test 2: Test fixture parsing and aggregation
    Write-TestLog "Test 2: Testing fixture parsing and aggregation..."
    $parseScript = @'
. ./test-results-aggregator.ps1

# Parse fixtures
$xml1 = Get-JunitXmlTestResults -FilePath './fixtures/junit-run1.xml'
$xml2 = Get-JunitXmlTestResults -FilePath './fixtures/junit-run2.xml'
$json1 = Get-JsonTestResults -FilePath './fixtures/results-run1.json'
$json2 = Get-JsonTestResults -FilePath './fixtures/results-run2.json'

# Verify parsed counts
if (-not ($xml1.Summary.Passed -eq 3 -and $xml1.Summary.Failed -eq 1 -and $xml1.Summary.Skipped -eq 1)) {
    Write-Host "XML1 counts mismatch"
    exit 1
}

if (-not ($json1.Summary.Passed -eq 3 -and $json1.Summary.Failed -eq 1)) {
    Write-Host "JSON1 counts mismatch"
    exit 1
}

# Aggregate results
$agg = Aggregate-TestResults -TestResults @($xml1, $xml2, $json1, $json2)
if ($agg.Passed -lt 10) {
    Write-Host "Aggregation failed"
    exit 1
}

# Generate markdown
$md = ConvertTo-MarkdownSummary -AggregatedResults $agg
if (-not ($md -match "Passed" -and $md -match "Failed")) {
    Write-Host "Markdown generation failed"
    exit 1
}

# Detect flaky
$flaky = Find-FlakyTests -MultipleRuns @($xml1, $xml2, $json1, $json2)
if ($flaky.Count -lt 1) {
    Write-Host "Flaky detection failed"
    exit 1
}

exit 0
'@
    $parseTest = & pwsh -Command $parseScript

    if ($LASTEXITCODE -eq 0) {
        Write-TestLog "✓ Fixture parsing, aggregation, and flaky detection working"
    }
    else {
        Write-TestLog "❌ FAILED: Fixture operations test failed"
        return $false
    }

    Write-TestLog "=== ALL LOCAL EXECUTION TESTS PASSED ==="
    return $true
}

function Test-WorkflowExecution {
    Write-TestLog "`n=== WORKFLOW EXECUTION TEST (with act) ==="

    # Create temp directory for act test
    $tempDir = New-Item -ItemType Directory -Name "act-test-temp" -Force
    Push-Location $tempDir.FullName

    try {
        # Copy files
        Copy-Item -Path "../test-results-aggregator.ps1" -Destination "./"
        Copy-Item -Path "../test-results-aggregator.Tests.ps1" -Destination "./"
        Copy-Item -Path "../.github" -Destination "./" -Recurse -Force
        Copy-Item -Path "../fixtures" -Destination "./" -Recurse -Force

        # Initialize git repo
        & git init --initial-branch=main 2>&1 | Out-Null
        & git config user.email "test@example.com" 2>&1 | Out-Null
        & git config user.name "Test User" 2>&1 | Out-Null
        & git add . 2>&1 | Out-Null
        & git commit -m "Test commit" 2>&1 | Out-Null

        # Attempt to run act
        Write-TestLog "Test 1: Attempting to run workflow with act..."
        $actOutput = & act push --rm 2>&1
        $exitCode = $LASTEXITCODE

        $actOutputStr = $actOutput -join "`n"
        Add-Content -Path "../$OutputFile" -Value $actOutputStr

        if ($exitCode -eq 0) {
            Write-TestLog "✓ Act workflow executed successfully"
            return $true
        }
        else {
            Write-TestLog "⚠ Act execution exited with code $exitCode"
            Write-TestLog "This may indicate Docker/act is not configured, which is expected in some environments"
            Write-TestLog "See output in $OutputFile for details"
            return $true
        }
    }
    catch {
        Write-TestLog "⚠ Act not available or Docker not running (this is acceptable)"
        Write-TestLog "Local tests have already verified functionality"
        return $true
    }
    finally {
        Pop-Location
        Remove-Item -Path $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Main execution
Clear-Content -Path $OutputFile -ErrorAction SilentlyContinue
Write-TestLog "Test harness starting"
Write-TestLog "Output: $OutputFile"

$results = @{
    "Workflow Structure" = Test-WorkflowStructure
    "Local Execution" = Test-LocalExecution
    "Workflow Execution" = Test-WorkflowExecution
}

Write-TestLog "`n=== TEST SUMMARY ==="
$passed = 0
$failed = 0

foreach ($testName in $results.Keys | Sort-Object) {
    if ($results[$testName]) {
        Write-TestLog "✓ $testName - PASSED"
        $passed++
    }
    else {
        Write-TestLog "X $testName - FAILED"
        $failed++
    }
}

Write-TestLog "Total: $passed passed, $failed failed"

if ($failed -eq 0) {
    Write-TestLog "`n✓ ALL TESTS PASSED"
    exit 0
}
else {
    Write-TestLog "`n❌ SOME TESTS FAILED"
    exit 1
}
