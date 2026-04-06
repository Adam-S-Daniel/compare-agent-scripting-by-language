#!/bin/bash
cd "$(dirname "$0")"
pwsh -NoProfile -File run-tests.ps1
