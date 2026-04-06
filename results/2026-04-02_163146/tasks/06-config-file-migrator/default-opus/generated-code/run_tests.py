#!/usr/bin/env python3
"""Test runner script - executes pytest programmatically."""
import sys
import pytest
sys.exit(pytest.main([__file__.replace("run_tests.py", "test_config_migrator.py"), "-v", "--tb=short"]))
