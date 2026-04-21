#!/usr/bin/env bash
# Runs pure-Lua unit tests. Expects `lua` on PATH.
set -e
cd "$(dirname "$0")/.."
lua tests/test_calendar_model.lua
