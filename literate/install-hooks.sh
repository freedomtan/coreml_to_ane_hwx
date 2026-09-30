#!/bin/sh
# Installs the literate/tangle.py check as a local pre-commit hook.
# Run once per clone: sh literate/install-hooks.sh
set -e
repo_root=$(git rev-parse --show-toplevel)
ln -sf ../../literate/git-hooks/pre-commit "$repo_root/.git/hooks/pre-commit"
chmod +x "$repo_root/literate/git-hooks/pre-commit"
echo "Installed: .git/hooks/pre-commit -> literate/git-hooks/pre-commit"
