#!/usr/bin/env bash
set -ue
#shellcheck disable=2154
PS4='$( _0=$?; exec 2>/dev/null; realpath -- "${BASH_SOURCE[0]:-?}:${LINENO} ^$_0 ${FUNCNAME[0]:-?}()=>" )'
[[ -n "${DEBUGSH:-}" ]] && set -x
set -o pipefail

prog=$(basename "$0")

die() {
  echo "ERROR(${prog}): $*" >&2
  exit ${2:-1}
}

{  # outer scope for helper functions (keeps main/die at top-level)

    usage() {
        printf "Usage: %s ORG PATTERN\n" "$prog"
        cut -c 12- <<'EOF'
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

}

main() {
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
    die "gh CLI not found. Install from https://cli.github.com/ and authenticate (gh auth login)." 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    die "jq is required but not installed. Install jq from https://stedolan.github.io/jq/ or via your package manager." 1
  fi

  tmpfile=$(mktemp /tmp/gh-find-repo.XXXXXX) || tmpfile=""
  trap 'rc=$?; [ -n "$tmpfile" ] && rm -f "$tmpfile"; exit "$rc"' EXIT

  errfile="${tmpfile}.err"
  gh api --paginate "orgs/${org}/repos" >"$tmpfile" 2>"$errfile" || gh_err=$?

  if [ -s "$errfile" ] && grep -qi 'not found' "$errfile"; then
    if gh api --paginate "users/${org}/repos" >"$tmpfile" 2>"$errfile"; then
      :
    else
      gh_rc=${gh_err:-$?}
      echo "Error: 'gh api' returned Not Found for '${org}', and retry against users failed (exit ${gh_rc})." >&2
      echo "gh output:" >&2
      sed 's/^/  /' "$errfile" >&2
      exit ${gh_rc}
    fi
  elif [ -s "$errfile" ]; then
    gh_rc=${gh_err:-0}
    echo "Error: 'gh api' failed for '${org}' (exit ${gh_rc})." >&2
    echo "gh output:" >&2
    sed 's/^/  /' "$errfile" >&2
    exit ${gh_rc}
  fi

  if ! jq -r --arg pat "$pattern" '.[] | select(.name | test($pat; "i")) | [ .name, .html_url, (.description // "") ] | @tsv' <"$tmpfile"; then
    jq_rc=$?
    echo "Error: 'jq' failed (exit ${jq_rc})." >&2
    exit 4
  fi

  # trap will clean tmpfile
}

if [ -z "${sourceMe:-}" ]; then
  main "$@"
  exit
fi
command true
