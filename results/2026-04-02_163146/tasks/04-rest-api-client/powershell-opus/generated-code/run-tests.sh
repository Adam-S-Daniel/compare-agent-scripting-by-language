#!/bin/bash
pwsh -noprofile -c 'Invoke-Pester "./RestApiClient.Tests.ps1" -Output Detailed'
