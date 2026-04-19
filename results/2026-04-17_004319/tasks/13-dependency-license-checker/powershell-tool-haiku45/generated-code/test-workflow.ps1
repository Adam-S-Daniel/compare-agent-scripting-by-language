# Test harness for running the GitHub Actions workflow via act
# This script validates the workflow against test cases

param(
    [string]$OutputFile = "act-result.txt"
)

$ErrorActionPreference = "Stop"

# Initialize result file
$null = New-Item -Path $OutputFile -ItemType File -Force
$actOutput = @()

Write-Host "Starting workflow test harness..."
Write-Host "Output will be saved to: $OutputFile"

# Test case 1: Basic dependency parsing
Write-Host "`n=== Test Case 1: Basic dependency parsing ==="
Write-Host "Running workflow via act..."

$process = Start-Process -FilePath "act" -ArgumentList @(
    "push",
    "--rm",
    "--verbose"
) -NoNewWindow -RedirectStandardOutput ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "act-output-1.txt")) -RedirectStandardError ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "act-error-1.txt")) -PassThru

Wait-Process -InputObject $process
$exitCode1 = $process.ExitCode

Write-Host "Test Case 1 Exit Code: $exitCode1"

$outputPath1 = $process.StartInfo.RedirectStandardOutput.FileName
$errorPath1 = $process.StartInfo.RedirectStandardError.FileName

if (Test-Path $outputPath1) {
    $output1 = Get-Content $outputPath1 -Raw
    $actOutput += "=== Test Case 1: Basic dependency parsing ==="
    $actOutput += $output1
    $actOutput += ""
    Write-Host "Captured output from test case 1"

    # Verify success indicators in output
    if ($output1 -match "Job succeeded" -and $exitCode1 -eq 0) {
        Write-Host "✓ Test Case 1 PASSED"
    } else {
        Write-Host "✗ Test Case 1 FAILED"
        Write-Host "Exit Code: $exitCode1"
        if ($output1 -match "error|failed|Error|Failed") {
            Write-Host "Errors found in output"
        }
    }
}

if (Test-Path $errorPath1) {
    $errors1 = Get-Content $errorPath1 -Raw
    if (-not [string]::IsNullOrWhiteSpace($errors1)) {
        $actOutput += "=== Errors from Test Case 1 ==="
        $actOutput += $errors1
        $actOutput += ""
    }
}

# Save results to output file
$actOutput | Set-Content -Path $OutputFile -Force
Write-Host "`nResults saved to $OutputFile"

# Exit with status
if ($exitCode1 -eq 0) {
    Write-Host "`n✓ All workflow tests completed successfully"
    exit 0
} else {
    Write-Host "`n✗ Workflow tests failed"
    exit 1
}
