#!/usr/bin/env bash
set -euo pipefail

prog=$(basename "$0")
usage() {
  printf "Usage: %s ORG PATTERN\n" "$prog"
  cat <<'EOF'
Search all repositories in organization ORG for PATTERN (case-insensitive).
Outputs tab-separated: name <tab> url <tab> description

Examples:
  gh-find-repo.sh stabledog vscode
  gh-find-repo.sh my-org "test-repo"

Requirements:
  - GitHub CLI (`gh`) must be installed and authenticated.
  - `jq` must be installed (this script uses `jq` to filter results).
EOF
  exit 2
}

if [ "$#" -lt 2 ]; then
  usage
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
fi

org="$1"
shift
pattern="$*"

if [ -z "$pattern" ]; then
  usage
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI not found. Install from https://cli.github.com/ and authenticate (gh auth login)." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed. Install jq from https://stedolan.github.io/jq/ or via your package manager." >&2
  exit 1
fi

# Use jq for safe, case-insensitive regex matching.
gh api --paginate "orgs/${org}/repos" | \
  jq -r --arg pat "$pattern" '.[] | select(.name | test($pat; "i")) | "\(.name)\t\(.html_url)\t\(.description // \"\")"'
