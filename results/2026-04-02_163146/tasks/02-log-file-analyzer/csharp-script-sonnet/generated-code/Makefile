# Makefile for Log File Analyzer
# .NET 10 is typically at /usr/share/dotnet/dotnet
# Alternatively: install with dotnet-install.sh --channel 10.0

DOTNET ?= /usr/share/dotnet/dotnet
WORKSPACE := $(shell pwd)
TEST_DIR  := $(WORKSPACE)/LogAnalyzer.Tests
SAMPLE    := $(TEST_DIR)/Fixtures/sample.log
REPORT    := $(WORKSPACE)/sample.log.report.json

.PHONY: test run install-dotnet

## Run all tests
test:
	$(DOTNET) test $(TEST_DIR)/ --verbosity normal

## Run the file-based app on the sample log
run:
	$(DOTNET) run $(WORKSPACE)/LogAnalyzer.cs -- $(SAMPLE) $(REPORT)

## Install .NET 10 to a local .dotnet directory (if not in PATH)
install-dotnet:
	curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir $(WORKSPACE)/.dotnet
