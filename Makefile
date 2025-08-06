# Makefile for ai-terminals

# Default target
.PHONY: default
default: test

# Check Lua syntax on all files
.PHONY: syntax
syntax:
	@echo "Checking Lua syntax..."
	@find lua/ -name "*.lua" -exec luac -p {} \; && echo "All syntax checks passed!"

# Run tests
.PHONY: test
test: syntax
	@echo "Running tests..."
	@nvim -l ./tests/busted.lua tests/
