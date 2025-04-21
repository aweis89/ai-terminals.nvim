# Makefile for ai-terminals

# Default target
.PHONY: default
default: test

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	@nvim -l ./tests/busted.lua tests/
