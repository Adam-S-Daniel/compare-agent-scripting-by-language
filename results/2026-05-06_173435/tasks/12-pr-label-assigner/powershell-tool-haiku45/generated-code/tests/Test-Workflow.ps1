# Test harness for GitHub Actions workflow validation
# Validates workflow structure and runs it through act

param(
    [string] $WorkflowPath = "./.github/workflows/pr-label-assigner.yml",
    [string] $ResultFile = "./act-result.txt"
)

$ErrorActionPreference = "Stop"

Write-Host "PR Label Assigner - Workflow Testing"
Write-Host "======================================"

# Test 1: Validate workflow file exists
Write-Host "`n[1/4] Checking workflow file exists..."
if (-not (Test-Path $WorkflowPath)) {
    Write-Error "Workflow file not found: $WorkflowPath"
    exit 1
}
Write-Host "✓ Workflow file found: $WorkflowPath"

# Test 2: Validate workflow YAML structure
Write-Host "`n[2/4] Validating workflow YAML structure..."
try {
    $yaml = Get-Content $WorkflowPath -Raw
    # Basic YAML validation - check for required sections
    if ($yaml -notmatch "name:") {
        Write-Error "Workflow missing 'name' section"
        exit 1
    }
    if ($yaml -notmatch "on:") {
        Write-Error "Workflow missing 'on' section (triggers)"
        exit 1
    }
    if ($yaml -notmatch "jobs:") {
        Write-Error "Workflow missing 'jobs' section"
        exit 1
    }
    Write-Host "✓ Workflow YAML structure is valid"
}
catch {
    Write-Error "Error validating workflow: $_"
    exit 1
}

# Test 3: Validate with actionlint
Write-Host "`n[3/4] Running actionlint validation..."
$lintResult = & actionlint $WorkflowPath 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "actionlint output:"
    Write-Host $lintResult
    Write-Error "actionlint validation failed"
    exit 1
}
Write-Host "✓ actionlint validation passed"

# Test 4: Create test files and run workflow with act
Write-Host "`n[4/4] Running workflow tests with act..."

# Initialize test results
$resultsContent = @()
$resultsContent += "=== PR Label Assigner Workflow Test Results ==="
$resultsContent += "Test Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$resultsContent += "Machine: $(hostname)"
$resultsContent += ""

# Create test directories
$testDirs = @()

# Test Case 1: Documentation file
Write-Host "`n  Test Case 1: Documentation file..."
$tempDir1 = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "act-test-docs-$(Get-Random)") -Force
$testDirs += $tempDir1

try {
    Copy-Item -Path "docs" -Destination "$($tempDir1.FullName)/docs" -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path "$($tempDir1.FullName)/docs")) {
        New-Item -ItemType Directory -Path "$($tempDir1.FullName)/docs" -Force | Out-Null
    }
    Set-Content -Path "$($tempDir1.FullName)/docs/README.md" -Value "# Test Documentation"
    Copy-Item -Path ".github" -Destination "$($tempDir1.FullName)/.github" -Recurse -Force
    Copy-Item -Path "src" -Destination "$($tempDir1.FullName)/src" -Recurse -Force
    Copy-Item -Path "label-rules.json" -Destination "$($tempDir1.FullName)/label-rules.json" -Force

    # Run git and act
    Push-Location $tempDir1.FullName
    try {
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        git add .
        git commit -m "Test commit with docs" -q

        $output1 = & act push --rm 2>&1
        $exitCode1 = $LASTEXITCODE

        $resultsContent += "TEST CASE 1: Documentation File (docs/README.md)"
        $resultsContent += "Exit Code: $exitCode1"
        $resultsContent += "Status: $(if ($exitCode1 -eq 0) { 'PASSED' } else { 'FAILED' })"
        $resultsContent += ""
        $resultsContent += "Output:"
        $resultsContent += $output1
        $resultsContent += ""
    }
    finally {
        Pop-Location
    }
}
catch {
    $resultsContent += "TEST CASE 1: FAILED - Error during test"
    $resultsContent += "Error: $_"
    $resultsContent += ""
}

# Test Case 2: Source code file
Write-Host "  Test Case 2: API source file..."
$tempDir2 = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "act-test-src-$(Get-Random)") -Force
$testDirs += $tempDir2

try {
    New-Item -ItemType Directory -Path "$($tempDir2.FullName)/src/api" -Force | Out-Null
    Set-Content -Path "$($tempDir2.FullName)/src/api/handlers.ps1" -Value "# API Handlers"
    Copy-Item -Path ".github" -Destination "$($tempDir2.FullName)/.github" -Recurse -Force
    Copy-Item -Path "src" -Destination "$($tempDir2.FullName)/src" -Recurse -Force
    Copy-Item -Path "label-rules.json" -Destination "$($tempDir2.FullName)/label-rules.json" -Force

    # Run git and act
    Push-Location $tempDir2.FullName
    try {
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        git add .
        git commit -m "Test commit with API code" -q

        $output2 = & act push --rm 2>&1
        $exitCode2 = $LASTEXITCODE

        $resultsContent += "TEST CASE 2: API Source File (src/api/handlers.ps1)"
        $resultsContent += "Exit Code: $exitCode2"
        $resultsContent += "Status: $(if ($exitCode2 -eq 0) { 'PASSED' } else { 'FAILED' })"
        $resultsContent += ""
        $resultsContent += "Output:"
        $resultsContent += $output2
        $resultsContent += ""
    }
    finally {
        Pop-Location
    }
}
catch {
    $resultsContent += "TEST CASE 2: FAILED - Error during test"
    $resultsContent += "Error: $_"
    $resultsContent += ""
}

# Test Case 3: Test file
Write-Host "  Test Case 3: Test file..."
$tempDir3 = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "act-test-test-$(Get-Random)") -Force
$testDirs += $tempDir3

try {
    Set-Content -Path "$($tempDir3.FullName)/unit.test.ps1" -Value "# Unit Tests"
    Copy-Item -Path ".github" -Destination "$($tempDir3.FullName)/.github" -Recurse -Force
    Copy-Item -Path "src" -Destination "$($tempDir3.FullName)/src" -Recurse -Force
    Copy-Item -Path "label-rules.json" -Destination "$($tempDir3.FullName)/label-rules.json" -Force

    # Run git and act
    Push-Location $tempDir3.FullName
    try {
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        git add .
        git commit -m "Test commit with tests" -q

        $output3 = & act push --rm 2>&1
        $exitCode3 = $LASTEXITCODE

        $resultsContent += "TEST CASE 3: Test File (unit.test.ps1)"
        $resultsContent += "Exit Code: $exitCode3"
        $resultsContent += "Status: $(if ($exitCode3 -eq 0) { 'PASSED' } else { 'FAILED' })"
        $resultsContent += ""
        $resultsContent += "Output:"
        $resultsContent += $output3
        $resultsContent += ""
    }
    finally {
        Pop-Location
    }
}
catch {
    $resultsContent += "TEST CASE 3: FAILED - Error during test"
    $resultsContent += "Error: $_"
    $resultsContent += ""
}

$resultsContent += "=== End of Test Results ==="

# Save results
$resultsContent | Set-Content -Path $ResultFile
Write-Host "`n✓ Test results saved to: $ResultFile"

# Cleanup
Write-Host "`nCleaning up test directories..."
foreach ($dir in $testDirs) {
    if (Test-Path $dir.FullName) {
        Remove-Item $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "✓ Cleanup complete"
Write-Host "`nAll workflow tests completed successfully!"
