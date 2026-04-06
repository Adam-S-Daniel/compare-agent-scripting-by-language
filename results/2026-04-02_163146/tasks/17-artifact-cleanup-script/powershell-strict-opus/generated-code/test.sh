#!/bin/bash
cd "$(dirname "$0")"
exec pwsh -NoProfile -NonInteractive -File ./run-tests.ps1
