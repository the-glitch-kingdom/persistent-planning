#!/bin/bash
git config core.hooksPath .githooks
chmod +x .githooks/*
echo "Git hooks installed (.githooks/ directory configured)"
