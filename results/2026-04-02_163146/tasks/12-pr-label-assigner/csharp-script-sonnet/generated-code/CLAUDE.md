# PR Label Assigner - C# Implementation

## Allowed Commands

The following commands should be auto-approved for this project:
- `dotnet` - .NET SDK commands (build, test, run, restore, new)
- `curl` - For downloading .NET install script
- `wget` - Alternative download tool
- `bash` - Running shell scripts
- `sh` - Running shell scripts
- `python3` - Python scripts for setup
- `apt-get` - Package installation

## Setup

If .NET SDK is not installed, run:
```bash
curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0
export PATH="$HOME/.dotnet:$PATH"
```

## Running Tests

```bash
dotnet test PrLabelAssigner.Tests/
```
