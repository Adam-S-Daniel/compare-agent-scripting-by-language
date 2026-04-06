# Semantic Version Bumper — PowerShell

This workspace implements a semantic version bumper using PowerShell and Pester TDD.

## Running Tests

```powershell
Invoke-Pester ./VersionBumper.Tests.ps1 -Output Detailed
```

Or via the convenience script:
```bash
./test.sh
```

## Allowed Commands

<!-- claude
allowed_tools:
  - Bash(pwsh*)
  - Bash(chmod*)
-->
