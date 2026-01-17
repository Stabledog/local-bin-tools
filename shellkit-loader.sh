#!/bin/bash
# shellkit-loader.sh
#
# Invoked by shellkit-loader.bashrc during shell startup, this
# script scans the installed shellkits and sorts their
# dependencies, producing a load ordering.
#
# It prints the load ordering as a list of init scripts to
# be sourced.
#
# If a cycle or missing dependency is detected, it prints to
# stderr, but continues with a best-effort to yield the
# load order list anyway.

scriptName="${scriptName:-"$(readlink -f "$0")"}"
scriptDir=$(command dirname -- "${scriptName}")

#shellcheck disable=2154
PS4='$( _0=$?; exec 2>/dev/null; realpath -- "${BASH_SOURCE[0]:-?}:${LINENO} ^$_0 ${FUNCNAME[0]:-?}()=>" ) '


die() {
    builtin echo "ERROR($(basename "${scriptName}")): $*" >&2
    builtin exit 1
}

#shellcheck disable=1091
SHELLKIT_LOAD_DISABLE=1 source "${scriptDir}/shellkit-loader.bashrc"
[[ -n $SHELLKIT_LOADER_VER ]] || die "Missing ${scriptDir}/shellkit-loader.bashrc or SHELLKIT_LOADER_VER not defined"

stub() {
    {
        builtin printf "  <<< STUB "
        builtin printf "[%s] " "$@"
        builtin printf ">>>\n"
    } >&2
}

get_kit_depends() {
    # List unordered kit dependency tuples like:
    #     kit1 kit3
    #     kit3 kit4
    #     kit3 -
    # When the dependency is '-', it's just filler to ensure
    # all dependents are included in the output.
    while read -r kit; do
        printf "%s -\n" "${kit}"
        [[ -f ${kit}/load-depends ]] && {
            # We want one or more lines like [kitname] [dependency]
            # as input for tsort:
            grep -Ev ' *#' "${kit}/load-depends" | sed "s/^/${kit} /"
        }
    done < <( command ls ./*/Kitname 2>/dev/null | cut -c 3- | command xargs dirname 2>/dev/null )
}

format_tsort_errs() {
    local first=true
    while read -r line; do
        $first && {
            printf "ERROR(%s): dependency sorting error -- " "$(basename "$scriptName")"
            first=false
        }
        printf "   %s\n" "${line}"
    done >&2
}

get_sorted_kitnames() {
    get_kit_depends | tsort 2> >( format_tsort_errs ) | grep -v '^-$' | tac
}

main() {
    if [[ -n $SHLOADER_DIR ]]; then
        cd "$SHLOADER_DIR" || die Failed to cd to "$SHLOADER_DIR"
    else
        cd "${HOME}/.local/bin" || die Failed to cd to "${HOME}/.local/bin"
    fi
    while read -r kit; do
        [[ -d ${kit} ]] || {
            echo "ERROR($(basename "$scriptName")): shellkit ${kit} is referenced as a dependency but is not installed in ~/.local/bin/${kit}"
            echo "The shellkit dependency graph is :"
            (
                echo $'source:\tdepends-on:'
                get_kit_depends | grep -Ev " -$" | sed 's/ /\t/'
            ) | sed 's/^/   /'
            echo "Try running \"shpm install ${kit}\" to resolve this error."
            continue
        } >&2
        [[ -f ${kit}/${kit}.bashrc ]] && {
            echo "${kit}/${kit}.bashrc"
        }
    done < <(get_sorted_kitnames)
    true
}

[[ -z ${sourceMe} ]] && {
    case $1 in
        --version|-v) echo "$SHELLKIT_LOADER_VER"; exit 0;;
    esac
    main "$@"
    builtin exit
}
command true
