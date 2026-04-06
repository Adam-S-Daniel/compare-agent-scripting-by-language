# Environment Matrix Generator

## Setup

.NET 10 SDK is installed at `~/.dotnet`. Add it to PATH before running:

```bash
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$PATH"
```

## Running Tests

```bash
dotnet test MatrixGenerator.Tests/ -v normal
```

## Running the File-Based App

```bash
dotnet run generate-matrix.cs
```

Or with a config file:

```bash
dotnet run generate-matrix.cs my-config.json
```

Or via stdin:

```bash
echo '{"dimensions":{"os":["ubuntu-latest","windows-latest"],"python-version":["3.9","3.10"]},"max-parallel":4,"fail-fast":false}' | dotnet run generate-matrix.cs
```

## Permissions

Allow these commands in Claude Code settings:
- `dotnet test *`
- `dotnet run *`
- `dotnet build *`
