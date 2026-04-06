#!/bin/bash
export PATH="$HOME/.dotnet:$PATH"
dotnet test ArtifactCleanup.Tests --verbosity normal
