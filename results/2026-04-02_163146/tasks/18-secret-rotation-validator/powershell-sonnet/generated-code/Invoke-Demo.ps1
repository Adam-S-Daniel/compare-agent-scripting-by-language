# Invoke-Demo.ps1
# Demonstration of the Secret Rotation Validator
# Run with: pwsh Invoke-Demo.ps1

. (Join-Path $PSScriptRoot 'SecretRotationValidator.ps1')

Write-Host ""
Write-Host "=== Secret Rotation Validator Demo ===" -ForegroundColor Cyan
Write-Host ""

# --- Load configuration from the fixture file ---
$configPath = Join-Path $PSScriptRoot 'fixtures/secrets-config.json'
$config = Import-SecretConfig -Path $configPath

Write-Host "Loaded $($config.Secrets.Count) secrets from config." -ForegroundColor Green
Write-Host "Warning window: $($config.WarningWindowDays) days"
Write-Host ""

# --- Generate the report (use a fixed reference date for reproducible output) ---
$referenceDate = [datetime]'2024-01-15'

$report = Invoke-SecretRotationReport `
    -Secrets           $config.Secrets `
    -ReferenceDate     $referenceDate `
    -WarningWindowDays $config.WarningWindowDays

# --- Output: Markdown ---
Write-Host "--- MARKDOWN OUTPUT ---" -ForegroundColor Yellow
$md = Format-RotationReport -Report $report -Format 'Markdown'
Write-Host $md

# --- Output: JSON ---
Write-Host "--- JSON OUTPUT ---" -ForegroundColor Yellow
$json = Format-RotationReport -Report $report -Format 'JSON'
Write-Host $json
