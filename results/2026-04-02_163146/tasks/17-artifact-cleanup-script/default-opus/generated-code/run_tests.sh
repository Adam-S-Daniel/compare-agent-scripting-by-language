#!/bin/bash
cd "$(dirname "$0")"
python3 -m unittest test_artifact_cleanup -v
