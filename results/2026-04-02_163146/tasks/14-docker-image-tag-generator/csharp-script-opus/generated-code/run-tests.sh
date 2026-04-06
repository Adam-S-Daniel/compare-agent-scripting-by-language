#!/bin/bash
# Run tests for Docker Image Tag Generator
export PATH="/home/passp/.dotnet:$PATH"
export DOTNET_NOLOGO=1
cd "$(dirname "$0")"
dotnet test DockerTagGenerator.Tests/ --verbosity quiet
