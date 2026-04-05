#!/bin/bash
cd "$(dirname "$0")"
python3 -m unittest test_renamer -v 2>&1
