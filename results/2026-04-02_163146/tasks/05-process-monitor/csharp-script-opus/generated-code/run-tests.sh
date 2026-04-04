#!/bin/bash
# Run all tests for the ProcessMonitor project
cd "$(dirname "$0")"
dotnet test ProcessMonitor.Tests/ --verbosity normal
