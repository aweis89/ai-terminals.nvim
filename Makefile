# Makefile for ai-terminals

# Default target
.PHONY: default
default: test

# Check Lua syntax on all files and markdown linting
.PHONY: syntax
syntax:
	@echo "Checking Lua syntax..."
	@find lua/ -name "*.lua" -exec luac -p {} \; && echo "All syntax checks passed!"
	@echo "Checking markdown linting..."
	@npx markdownlint-cli2 README.md && echo "Markdown linting passed!" || echo "Markdown linting issues found (see above)"

# Run tests
.PHONY: test
test: syntax
	@echo "Running tests..."
	@nvim -l ./tests/busted.lua tests/
