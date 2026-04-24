---
name: jq 1.6 reserved keywords in act container
description: The act-ubuntu-pwsh:latest container has jq 1.6 despite apt reporting 1.7.1; 'include' and 'import' are reserved keywords that break $include/$exclude jq variable names
type: project
---

The `act-ubuntu-pwsh:latest` Docker container has jq 1.6 at `/usr/bin/jq` even though `apt-get install jq` reports "already newest version (1.7.1)". This means:

**Why:** The base catthehacker/ubuntu:act-latest image manually installed jq 1.6 binary but registered a different version in the apt database. apt-get sees it as "already installed" and doesn't reinstall.

**How to apply:** When writing jq expressions that will run in the act container:
- Never use `$include` as a jq variable name — `include` is a reserved keyword in jq 1.6
- Never use `--argjson include` — same reason  
- Never use `$import` — also reserved
- Use alternative names: `$inc`, `$inc_list`, `$exc`, `$exc_list` etc.
- Test jq expressions by running `docker run --rm act-ubuntu-pwsh:latest bash -c "jq --version && your_expression"` to verify compatibility
