#!/usr/bin/env python3
"""Wrapper to discover and run all tests in this directory."""
import sys
import os

# Add the directory containing this file to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import unittest

# Discover and run tests
loader = unittest.TestLoader()
suite = loader.discover(
    start_dir=os.path.dirname(os.path.abspath(__file__)),
    pattern="test_*.py",
)

runner = unittest.TextTestRunner(verbosity=2)
result = runner.run(suite)

# Exit with non-zero code if tests failed
sys.exit(0 if result.wasSuccessful() else 1)
