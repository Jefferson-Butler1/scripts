#!/usr/bin/env bash
# set -euo pipefail # Enable strict error handling

# Configuration
git diff main --name-only --diff-filter=d | xargs -I{} npx prettier --write "{}" && npx eslint_d --fix "{}"

git add .

if [ "$(git log | head -n 5 | tail -n 1 | grep "eslint" -c)" -gt 0 ]; then
	git commit --amend
else
	git commit -am "style:eslint fix"
fi
