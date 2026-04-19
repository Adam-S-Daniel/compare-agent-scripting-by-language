$ErrorActionPreference = "Stop"

Write-Host "=== GitHub Actions Workflow Validation ==="
Write-Host ""

$workflowPath = ".github/workflows/semantic-version-bumper.yml"
$passed = 0
$failed = 0

# Test 1: Workflow file exists
Write-Host "Test 1: Workflow file exists"
if (Test-Path $workflowPath) {
    Write-Host "  ✓ PASS - $workflowPath found"
    $passed++
} else {
    Write-Host "  ✗ FAIL - $workflowPath not found"
    $failed++
    exit 1
}

# Test 2: Parse YAML and validate structure
Write-Host ""
Write-Host "Test 2: Parse YAML and validate structure"
try {
    $workflowContent = Get-Content $workflowPath -Raw

    # Basic YAML validation - check for required fields
    if ($workflowContent -match "^name:") {
        Write-Host "  ✓ Has 'name' field"
        $passed++
    } else {
        Write-Host "  ✗ Missing 'name' field"
        $failed++
    }

    if ($workflowContent -match "\non:") {
        Write-Host "  ✓ Has 'on' trigger"
        $passed++
    } else {
        Write-Host "  ✗ Missing 'on' trigger"
        $failed++
    }

    if ($workflowContent -match "jobs:") {
        Write-Host "  ✓ Has 'jobs' section"
        $passed++
    } else {
        Write-Host "  ✗ Missing 'jobs' section"
        $failed++
    }

    if ($workflowContent -match "bump-version:") {
        Write-Host "  ✓ Has 'bump-version' job"
        $passed++
    } else {
        Write-Host "  ✗ Missing 'bump-version' job"
        $failed++
    }

    if ($workflowContent -match "shell: pwsh") {
        Write-Host "  ✓ Uses 'shell: pwsh' (PowerShell)"
        $passed++
    } else {
        Write-Host "  ✗ Doesn't use 'shell: pwsh'"
        $failed++
    }

} catch {
    Write-Host "  ✗ Error parsing YAML: $_"
    $failed++
}

# Test 3: Verify script files referenced in workflow exist
Write-Host ""
Write-Host "Test 3: Verify script files exist"
$requiredScripts = @(
    "semantic-version-bumper.ps1",
    "bump-version.ps1",
    "semantic-version-bumper.tests.ps1"
)

foreach ($script in $requiredScripts) {
    if (Test-Path $script) {
        Write-Host "  ✓ $script exists"
        $passed++
    } else {
        Write-Host "  ✗ $script not found"
        $failed++
    }
}

# Test 4: Run actionlint
Write-Host ""
Write-Host "Test 4: Validate workflow with actionlint"
try {
    $lintOutput = & actionlint $workflowPath 2>&1
    $lintExit = $LASTEXITCODE

    if ($lintExit -eq 0) {
        Write-Host "  ✓ PASS - actionlint validation successful"
        $passed++
    } else {
        Write-Host "  ✗ FAIL - actionlint found errors:"
        Write-Host $lintOutput
        $failed++
    }
} catch {
    Write-Host "  ✗ FAIL - Could not run actionlint: $_"
    $failed++
}

# Test 5: Check for required steps
Write-Host ""
Write-Host "Test 5: Verify workflow contains required steps"
$requiredSteps = @(
    "Checkout code",
    "Run Pester tests",
    "Bump semantic version"
)

foreach ($step in $requiredSteps) {
    if ($workflowContent -match $step) {
        Write-Host "  ✓ Has '$step' step"
        $passed++
    } else {
        Write-Host "  ✗ Missing '$step' step"
        $failed++
    }
}

# Summary
Write-Host ""
Write-Host "=== Validation Summary ==="
Write-Host "Passed: $passed"
Write-Host "Failed: $failed"

if ($failed -gt 0) {
    Write-Host ""
    Write-Error "Workflow validation failed"
    exit 1
} else {
    Write-Host ""
    Write-Host "✓ All workflow validation tests passed!"
    exit 0
}
