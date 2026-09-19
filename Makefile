# Optional shortcuts; the scripts and normal Swift/Xcode workflows remain usable.
.DEFAULT_GOAL := help
SHELL := /bin/bash

# SwiftPM shares its build directory. In particular, never race clean with build.
.NOTPARALLEL:
.PHONY: help build app test run clean verify

help:
	@printf '%s\n' \
	  'Glint development commands:' \
	  '  make build   Build and ad-hoc sign build/Glint.app (release)' \
	  '  make app     Alias for build' \
	  '  make test    Run tests with automatic Swift Testing compatibility' \
	  '  make run     Build, then open Glint (does not restart a running copy)' \
	  '  make clean   Remove Swift build products and the generated app only' \
	  '  make verify  Check syntax, build, test, and verify the app signature' \
	  '  make help    Show these commands' \
	  '' \
	  'Live Codex tests are opt-in: GLINT_LIVE_TESTS=1 make test' \
	  'Make is optional. See README for direct script and Xcode workflows.'

build:
	bash scripts/build.sh

app: build

test:
	bash scripts/test.sh

run: build
	open build/Glint.app

clean:
	bash scripts/clean.sh

verify:
	bash scripts/verify.sh
