.PHONY: test help
.DEFAULT_GOAL := help

TEST_SCRIPT := .github/actions/version/check.test.sh

test:
	@$(TEST_SCRIPT)

help:
	@echo "Makefile for softopus/actions"
	@echo ""
	@echo "Usage:"
	@echo "    make <target>"
	@echo ""
	@echo "Targets:"
	@echo "    test      run tests"
	@echo "    help      show this help message"
