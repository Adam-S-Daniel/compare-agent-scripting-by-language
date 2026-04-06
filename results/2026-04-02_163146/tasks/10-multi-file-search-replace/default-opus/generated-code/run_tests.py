#!/usr/bin/env python3
"""Run the test suite. Usage: python3 run_tests.py"""
import sys
import pytest

sys.exit(pytest.main(["-v", "test_search_replace.py"]))
