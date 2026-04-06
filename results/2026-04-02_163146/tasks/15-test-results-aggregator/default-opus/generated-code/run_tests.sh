#!/bin/bash
cd "$(dirname "$0")"
python3 -m pytest test_aggregator.py -v
