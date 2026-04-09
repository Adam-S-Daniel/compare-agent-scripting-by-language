# Plan: Custom Act Container with Pre-installed PowerShell and Pester

## Problem

Every PowerShell benchmark run installs pwsh (~56MB) and Pester inside
the act container. This costs 26.2 minutes across 16 runs (avg 24s per
install, 64 total installs). On real GitHub runners these are pre-installed.
The overhead is pure benchmark artifact -- not reflective of real CI/CD.

## Solution

Build a custom Docker image extending `catthehacker/ubuntu:act-latest`
with pwsh and Pester pre-installed. Configure act to use it for
`ubuntu-latest` jobs.

## Approach

### 1. Dockerfile

```dockerfile
FROM catthehacker/ubuntu:act-latest

# Install PowerShell (matches what agents install in workflows)
RUN apt-get update -qq \
    && apt-get install -y -qq wget apt-transport-https software-properties-common \
    && wget -q "https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update -qq \
    && apt-get install -y -qq powershell \
    && rm -f packages-microsoft-prod.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Pester (PowerShell testing framework)
RUN pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
    Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope AllUsers"

# Verify
RUN pwsh --version && pwsh -Command "Get-Module -ListAvailable Pester | Select-Object -Property Version"
```

### 2. Build and tag locally

```bash
docker build -t act-ubuntu-pwsh:latest -f Dockerfile.act .
```

### 3. Configure act to use the custom image

Two options:

**Option A: `.actrc` file** (per-repo or global)
```
-P ubuntu-latest=act-ubuntu-pwsh:latest
```
Place in the workspace root so act picks it up automatically.

**Option B: Runner.py modification**
Have runner.py write a `.actrc` file into each workspace before running
the agent. This way the agent's `act push` automatically uses the
custom image. The agent doesn't need to know about it -- the image swap
is transparent.

### 4. Runner.py changes

```python
# In _run_single_task, before starting the agent:
actrc_path = workspace / ".actrc"
actrc_path.write_text("-P ubuntu-latest=act-ubuntu-pwsh:latest\n")
```

Alternatively, the benchmark instructions could tell agents that pwsh
is already available, avoiding the install step entirely. But that
changes what agents produce (they'd write different workflows), which
changes the benchmark. Keeping the image swap transparent preserves
comparability.

### 5. Benchmark instructions changes

**No changes needed for transparency approach.** Agents still write
"Install PowerShell" steps in their workflows. Those steps become
near-instant (apt finds pwsh already installed, no download needed).
The `if ! command -v pwsh` guards many agents already use would skip
installation entirely.

**Optional for future v4:** Add a note that pwsh and Pester are
pre-installed in the runner environment, matching real GitHub runners.
This would let agents skip the install step, producing cleaner workflows.

### 6. Impact estimate

- **Time saved:** ~26 minutes across 16 runs (1.6 min/run avg)
- **Cost saved:** ~$2.44 (from reduced act execution time -> fewer
  API-idle seconds)
- **pwsh-runtime-install-overhead trap:** Would drop to near-zero
  (apt-get finds package already installed in <1s)
- **No impact on other modes:** Only the powershell runs use pwsh

### 7. Files to create/modify

| File | Action |
|------|--------|
| `Dockerfile.act` | New -- custom act image |
| `runner.py` | Add `.actrc` injection into workspaces |
| `benchmark-instructions-v4.md` | (Optional future) Note pwsh pre-installed |
| `AGENTS.md` | Document the custom image |

### 8. Validation

1. Build the image: `docker build -t act-ubuntu-pwsh:latest -f Dockerfile.act .`
2. Test manually: `cd /tmp && mkdir test && cd test && git init && echo '...' > .github/workflows/test.yml && act push -P ubuntu-latest=act-ubuntu-pwsh:latest`
3. Verify pwsh is found without apt-get install
4. Re-run one powershell task and confirm install step is near-instant
5. Check that the trap detector shows 0s for pwsh-runtime-install-overhead

### 9. Risks

- **Image size:** catthehacker/ubuntu:act-latest is ~1.2GB. Adding pwsh
  adds ~200MB. Acceptable.
- **Version drift:** pwsh version in the image may differ from what
  agents try to install. The `if ! command -v pwsh` guard handles this.
- **Act compatibility:** act's `-P` flag is well-documented and stable.
- **Cache invalidation:** When pwsh updates, rebuild the image. Could
  automate with a simple script.
