# Sample-Usage.ps1
# Demonstrates the Secret Rotation Validator with realistic mock secret data.
# Run with: pwsh Sample-Usage.ps1

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

[string]$modulePath = Join-Path $PSScriptRoot 'SecretRotationValidator.psm1'
Import-Module $modulePath -Force

# --- Mock secret configuration ---
# In a real scenario this would come from a vault API, config file, or CI secret store.
[PSCustomObject[]]$secrets = @(
    [PSCustomObject]@{
        Name         = 'DATABASE_PASSWORD'
        LastRotated  = (Get-Date).AddDays(-95)   # Expired 5 days ago
        RotationDays = 90
        RequiredBy   = [string[]]@('web-app', 'api-service', 'admin-portal')
    }
    [PSCustomObject]@{
        Name         = 'AWS_ACCESS_KEY'
        LastRotated  = (Get-Date).AddDays(-80)   # Expires in 10 days (warning)
        RotationDays = 90
        RequiredBy   = [string[]]@('data-pipeline', 'analytics')
    }
    [PSCustomObject]@{
        Name         = 'SLACK_WEBHOOK_TOKEN'
        LastRotated  = (Get-Date).AddDays(-35)   # Expired 5 days ago (30-day policy)
        RotationDays = 30
        RequiredBy   = [string[]]@('alerting')
    }
    [PSCustomObject]@{
        Name         = 'SMTP_CREDENTIALS'
        LastRotated  = (Get-Date).AddDays(-10)   # Fresh — 80 days remaining
        RotationDays = 90
        RequiredBy   = [string[]]@('notification-service')
    }
    [PSCustomObject]@{
        Name         = 'GITHUB_PAT'
        LastRotated  = (Get-Date).AddDays(-5)    # Fresh — 175 days remaining
        RotationDays = 180
        RequiredBy   = [string[]]@('ci-cd', 'release-automation')
    }
)

[int]$warningDays = 14

# --- Markdown report ---
Write-Host ''
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ' MARKDOWN OUTPUT' -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
[string]$markdownReport = Invoke-SecretRotationValidator `
    -Secrets $secrets `
    -WarningDays $warningDays `
    -OutputFormat 'Markdown'
Write-Host $markdownReport

# --- JSON report ---
Write-Host ''
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ' JSON OUTPUT' -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
[string]$jsonReport = Invoke-SecretRotationValidator `
    -Secrets $secrets `
    -WarningDays $warningDays `
    -OutputFormat 'Json'
Write-Host $jsonReport
