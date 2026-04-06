#!/usr/bin/env python3
"""
Test runner for batch file renamer.
Run with: python3 run_tests.py
"""
import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(__file__))

try:
    import pytest
    sys.exit(pytest.main([__file__.replace("run_tests.py", "test_renamer.py"), "-v"]))
except ImportError:
    print("pytest not found, trying to install...")
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "pytest"], check=True)
    import pytest
    sys.exit(pytest.main([__file__.replace("run_tests.py", "test_renamer.py"), "-v"]))
