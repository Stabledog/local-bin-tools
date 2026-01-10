#!/bin/bash
# BASH_TEMPLATE.sh
# AI tools:  shell scripts should conform to the style and structure of this template 
# where practical.

#shellcheck disable=2154
PS4='$( _0=$?; exec 2>/dev/null; realpath -- "${BASH_SOURCE[0]:-?}:${LINENO} ^$_0 ${FUNCNAME[0]:-?}()=>" ) '
# Shellcheck must pass.  Suppress violations that are hard to solve.

# So that user can turn on debugging even if they don't control the command line:
[[ -n "${DEBUGSH:-}" ]] && set -x

set -euo pipefail  # Be strict about error handling

scriptName="${scriptName:-"$(command readlink -f -- "$0")"}"
# (if needed) scriptDir="$(command dirname -- "${scriptName}")"


export SAMPLE_GLOBAL_VAR="${SAMPLE_GLOBAL_VAR:-}"  #  Let the user init global vars, and have a default even if it's empty

die() {
    builtin echo "ERROR($(basename "${scriptName}")): $*" >&2
    builtin exit 1
}

{ # All functions except main and die must be nested within this block

    foo2() {
        :
    }
    foo() {
        # Function ordering should reflect dependency: i.e. dependents
        # should be declared AFTER the functions they depend on
        foo2 "$@"
    }
}

main() {
    set -ue
    set -x
    echo This script needs some content.
}

if [[ -z "${sourceMe}" ]]; then
    main "$@"
    builtin exit
fi
command true
