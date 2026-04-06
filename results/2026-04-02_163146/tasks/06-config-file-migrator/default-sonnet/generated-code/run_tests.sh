#!/bin/bash
# Run the config migrator test suite
cd "$(dirname "$0")"
python3 -m unittest test_config_migrator -v
