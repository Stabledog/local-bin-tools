# Bash Coding Standard for AI Agents

This document provides explicit rules for writing bash scripts that conform to the `BASH_TEMPLATE.sh` conventions. Follow these rules sequentially when creating or refactoring scripts.

## Required Script Structure (in order)

1. **Shebang and initial set options**
   ```bash
   #!/usr/bin/env bash
   set -ue  # Always start with -ue
   ```

2. **PS4 and DEBUGSH setup**
   ```bash
   #shellcheck disable=2154
   PS4='$( _0=$?; exec 2>/dev/null; realpath -- "${BASH_SOURCE[0]:-?}:${LINENO} ^$_0 ${FUNCNAME[0]:-?}()=>" )'
   [[ -n "${DEBUGSH:-}" ]] && set -x
   ```

3. **Final set options**
   ```bash
   set -o pipefail  # or set -euo pipefail if combining
   ```

4. **Script metadata variables**
   ```bash
   scriptName="${scriptName:-"$(command readlink -f -- "$0")"}"
   # scriptDir="$(command dirname -- "${scriptName}")"  # if needed
   prog=$(basename "$0")  # if needed for usage/errors
   ```

5. **Global variables with defaults**
   ```bash
   export MY_VAR=${MY_VAR:-default_value}
   ```

6. **die() function** (always at top level, never in outer-scope braces)
   ```bash
   die() {
       builtin echo "ERROR($(basename "${scriptName}")): $*" >&2
       builtin exit 1
   }
   ```

7. **Outer-scope braces block for helper functions**
   ```bash
   {  # outer scope braces
   
       helper_1() {
           # function body indented by 4 spaces
       }
   
       helper_2() {
           # function body indented by 4 spaces
       }
   
   }
   ```

8. **main() function** (at top level, after outer-scope braces close)
   ```bash
   main() {
       # implementation
   }
   ```

9. **sourceMe wrapper** (always at end)
   ```bash
   if [[ -z "${sourceMe:-}" ]]; then
       main "$@"
       exit
   fi
   command true
   ```

## Indentation Rules

### Functions in Outer-Scope Braces
- Function declaration: indented 4 spaces
- Function body: indented 8 spaces (4 for function + 4 for body)
- Closing brace: indented 4 spaces

Example:
```bash
{  # outer scope braces

    usage() {
        printf "Usage: %s\n" "$prog"
        exit 2
    }

    helper() {
        local var="$1"
        echo "$var"
    }

}
```

### Heredocs in Functions
Use `cut -c 12-` pattern with 12-space indentation for heredoc content:

```bash
    usage() {
        printf "Usage: %s ORG PATTERN\n" "$prog"
        cut -c 12- <<'EOF'
            This text is indented 12 spaces in source.
            It will be trimmed by cut -c 12-.
            
            Examples:
              command arg1 arg2
EOF
        exit 2
    }
```

**Critical**: EOF marker must be at column 1 (no indentation).

### main() Function
- Declared at column 1 (no indentation)
- Body indented by 4 spaces

```bash
main() {
  # body uses 4-space indent
    if [[ "$#" -lt 1 ]]; then
        usage
    fi
}
```

## Common AI Mistakes to Avoid

1. **Missing closing brace for outer-scope block** - Always close `{` before `main()`
2. **Wrong indentation for functions in outer-scope** - Must indent function declaration by 4 spaces
3. **Using `cat` instead of `cut -c 12-`** - Template prefers cut pattern for heredocs
4. **Placing `usage()` outside outer-scope braces** - All helpers go inside `{}`
5. **Forgetting `die()` stays at top-level** - Only `die()` and `main()` are at column 1
6. **Using single brackets `[ ]` instead of double brackets `[[ ]]`** - Always use `[[ ]]` for conditionals
8. **Indenting EOF marker** - EOF must always be at column 1

## Heredoc Patterns

**Preferred pattern** (from template):
```bash
    helper() {
        cut -c 12- <<'EOF'
            Content here is indented 12 spaces.
            Will appear without leading spaces in output.
                After 12 chars, remaining spaces will be rendered as written.
EOF
    }
```


## Error Handling

1. **Use `die()` for fatal errors**:
   ```bash
   if ! command -v required_tool >/dev/null 2>&1; then
       die "required_tool not found" 
   fi
   ```

2. **Provide helpful error messages** with context and exit codes

3. **Capture command errors**:
   ```bash
   if ! some_command >"$tmpfile" 2>"${tmpfile}.err"; then
       cmd_rc=$?
       echo "Error: command failed (exit ${cmd_rc})" >&2
       [[ -s "${tmpfile}.err" ]] && sed 's/^/  /' "${tmpfile}.err" >&2
       exit ${cmd_rc}
   fi
   ```

## Variable and Function Naming

- **Local variables**: lowercase with underscores: `local tmp_file="..."`
- **Global variables/exports**: UPPERCASE: `export MY_VAR=...`
- **Functions**: lowercase with underscores: `helper_function()`
- Always use `local` for function-local variables

## Quoting and Command Execution

1. **Always quote variables**: `"$var"` not `$var`
2. **Always use double brackets `[[ ]]` for conditionals**, never single brackets `[ ]`:
   - Correct: `if [[ -n "$var" ]]; then`
   - Correct: `[[ "$x" = "value" ]] && action`
   - Wrong: `if [ -n "$var" ]; then`
3. **Use `command` for builtins when shadowing possible**: `command readlink`, `command dirname`
4. **Prefer bashisms for stderr/stdout**:
   - `&>file` instead of `>file 2>&1`
   - `|&` instead of `2>&1 |`

## Shellcheck Compliance

1. **Run shellcheck** on all scripts before considering them done
2. **Fix warnings** where practical
3. **Document suppressions** with inline comments above the suppression:
   ```bash
   # Variable set by trap, shellcheck can't detect
   #shellcheck disable=2154
   echo "$trap_set_var"
   ```

## Testing Requirements

1. **Test scripts** after creation/modification with actual arguments
2. **Use `sourceMe`** to enable unit testing of helper functions:
   ```bash
   sourceMe=1 source ./script.sh
   helper_function arg1 arg2
   ```
3. **Verify exit codes** match documented behavior

## Argument Parsing Pattern

```bash
main() {
  if [[ "$#" -lt 2 ]]; then
    usage
  fi

  if [[ "${1:-}" = "-h" ]] || [[ "${1:-}" = "--help" ]]; then
    usage
  fi

  local arg1="$1"
  shift
  local remaining="$*"
  
  # main logic here
}
```

## Cleanup Pattern

Use traps for cleanup:
```bash
tmpfile=$(mktemp /tmp/script.XXXXXX) || tmpfile=""
trap 'rc=$?; [[ -n "$tmpfile" ]] && rm -f "$tmpfile" "$tmpfile".*; exit "$rc"' EXIT
```

## Step-by-Step Script Creation

1. Copy shebang and set options (items 1-3 from structure)
2. Add PS4/DEBUGSH block
3. Define script variables (`scriptName`, `prog`)
4. Add `die()` function at top level
5. Open outer-scope braces with comment: `{  # outer scope braces`
6. Add all helper functions (usage, utilities) with proper indentation
7. Close outer-scope braces: `}`
8. Add `main()` function at top level
9. Add sourceMe wrapper at end
10. Run shellcheck and fix issues
11. Test with actual arguments

## Quick Reference: Indentation Levels

```bash
#!/usr/bin/env bash
# Column 1: shebang, set, die(), main(), sourceMe wrapper

die() {
  # Column 3: die body (2-space indent)
}

{  # Column 1: outer-scope open

    helper() {
        # Column 9: helper body (8-space indent = 4 for function + 4 for body)
        cut -c 12- <<'EOF'
            Content at column 13 (12 spaces)
EOF
    }

}  # Column 1: outer-scope close

main() {
  # Column 3: main body (2-space indent)
}

if [[ -z "${sourceMe:-}" ]]; then
    # Column 5: sourceMe block body (4-space indent)
fi
```

## Summary Checklist

Before considering a script complete:

- [ ] Follows structural order (shebang → PS4 → die → helpers → main → sourceMe)
- [ ] All helper functions inside outer-scope braces `{ }`
- [ ] `die()` and `main()` at top level (column 1)
- [ ] Helper functions indented 4 spaces, bodies 8 spaces
- [ ] Heredocs use `cut -c 12-` with 12-space-indented content
- [ ] EOF markers at column 1
- [ ] Shellcheck passes (or violations suppressed)
- [ ] Tested with actual arguments
- [ ] All variables quoted: `"$var"`
- [ ] Exit codes documented and tested
