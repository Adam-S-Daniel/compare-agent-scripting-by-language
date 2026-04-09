# conftest.py — Add project root to sys.path so tests can import the module
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
