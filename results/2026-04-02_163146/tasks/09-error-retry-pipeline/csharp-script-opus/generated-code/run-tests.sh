#!/bin/bash
cd "$(dirname "$0")"
dotnet test PipelineTests/PipelineTests.csproj --verbosity normal
