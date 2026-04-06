#!/usr/bin/env python3
"""Run all tests and exit with non-zero status if any fail."""
import sys
import unittest

loader = unittest.TestLoader()
suite = loader.discover("tests", pattern="test_*.py")
runner = unittest.TextTestRunner(verbosity=2)
result = runner.run(suite)
sys.exit(0 if result.wasSuccessful() else 1)
