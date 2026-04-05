#!/bin/bash
exec pwsh -NoProfile -NonInteractive -File "$(dirname "$0")/Run-Tests.ps1"
