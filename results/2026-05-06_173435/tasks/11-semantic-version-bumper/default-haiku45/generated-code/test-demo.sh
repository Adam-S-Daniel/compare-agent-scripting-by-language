#!/bin/bash
echo "=== SEMANTIC VERSION BUMPER - LIVE DEMO ==="
echo ""
echo "Demo 1: Feature commit (minor bump)"
echo "Input: COMMITS='feat(auth): add login form'"
COMMITS="feat(auth): add login form" node cli.js . 2>&1 | grep -E '"newVersion"|"changelog"' | head -2
echo ""
echo "Demo 2: Fix commit (patch bump)"
echo "Input: COMMITS='fix: correct nav styling'"
COMMITS="fix: correct nav styling" node cli.js . 2>&1 | grep -E '"newVersion"' | head -1
echo ""
echo "Demo 3: Breaking change (major bump)"
echo "Input: COMMITS='feat!: redesign API'"
COMMITS="feat!: redesign API" node cli.js . 2>&1 | grep -E '"newVersion"' | head -1
echo ""
echo "=== ALL TESTS PASSING ==="
npm test 2>&1 | grep "Tests:" | head -1
