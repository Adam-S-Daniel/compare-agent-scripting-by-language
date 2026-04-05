#!/bin/bash
pwsh -noni -nop -c "Invoke-Pester -Path ./DatabaseSeed.Tests.ps1 -Output Detailed"
