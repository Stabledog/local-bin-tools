#!/bin/bash
# send-email-core.sh - Core orchestration logic for send-email tool

#shellcheck disable=2154
PS4='$( _0=$?; exec 2>/dev/null; realpath -- "${BASH_SOURCE[0]:-?}:${LINENO} ^$_0 ${FUNCNAME[0]:-?}()=>" ) '
[[ -n "${DEBUGSH:-}" ]] && set -x
set -euo pipefail

scriptName="${scriptName:-"$(command readlink -f -- "$0")"}"
scriptDir="${scriptDir:-"$(command dirname -- "${scriptName}")"}"

die() {
    builtin echo "ERROR($(basename "${scriptName}")): $*" >&2
    builtin exit 1
}

{ # All functions except main and die must be nested within this block

    # Parse address file and resolve alias to email
    # Returns: email address on stdout, or exits with error
    resolve_address() {
        local alias="$1"
        local addresses_file="${HOME}/.config/send-email/addresses"
        
        [[ -f "$addresses_file" ]] || die "Addresses file not found: $addresses_file"
        
        local found_email=""
        local match_count=0
        
        # Parse addresses file: email alias1 alias2 alias3 ...
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// /}" ]] && continue
            
            # Parse line into email and aliases
            local parts
            read -ra parts <<< "$line"
            
            [[ ${#parts[@]} -lt 1 ]] && continue
            
            local email="${parts[0]}"
            
            # Check if alias matches any of the parts (including the email itself)
            for part in "${parts[@]}"; do
                if [[ "$part" == "$alias" ]]; then
                    ((match_count++))
                    found_email="$email"
                    
                    # Check for duplicate aliases
                    if [[ $match_count -gt 1 ]]; then
                        die "Duplicate alias '$alias' found in $addresses_file"
                    fi
                    
                    break
                fi
            done
        done < "$addresses_file"
        
        if [[ $match_count -eq 0 ]]; then
            echo "ERROR: Unknown alias '$alias'" >&2
            echo "" >&2
            echo "Available aliases:" >&2
            list_aliases >&2
            return 1
        fi
        
        echo "$found_email"
        return 0
    }

    # List available aliases for error messages
    list_aliases() {
        local addresses_file="${HOME}/.config/send-email/addresses"
        
        [[ -f "$addresses_file" ]] || return
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// /}" ]] && continue
            
            local parts
            read -ra parts <<< "$line"
            
            [[ ${#parts[@]} -lt 1 ]] && continue
            
            local email="${parts[0]}"
            
            # Print email and its aliases
            if [[ ${#parts[@]} -gt 1 ]]; then
                echo "  ${parts[*]:1} → $email"
            fi
        done < "$addresses_file"
    }

    # Build RFC-compliant email message
    format_email_message() {
        local from="$1"
        local to="$2"
        local subject="$3"
        local body="$4"
        local output_file="$5"
        
        # Generate RFC-compliant email with headers
        cat > "$output_file" <<EOF
From: $from
To: $to
Subject: $subject
Date: $(date -R)

$body
EOF
    }

    # Load and validate driver
    load_driver() {
        local driver_name="$1"
        # shellcheck disable=SC2154  # scriptDir is set by parent script
        local driver_file="${scriptDir}/drivers/${driver_name}.driver"
        
        [[ -f "$driver_file" ]] || die "Driver not found: $driver_name (expected: $driver_file)"
        
        # Source driver
        # shellcheck disable=SC1090
        sourceMe=1 source "$driver_file"
        
        # Validate interface functions exist
        if ! type -t driver_check_dependencies >/dev/null; then
            die "Driver $driver_name missing driver_check_dependencies()"
        fi
        
        if ! type -t driver_init >/dev/null; then
            die "Driver $driver_name missing driver_init()"
        fi
        
        if ! type -t driver_send_email >/dev/null; then
            die "Driver $driver_name missing driver_send_email()"
        fi
        
        # Check dependencies
        driver_check_dependencies || die "Driver $driver_name dependency check failed"
        
        # Initialize driver
        driver_init || die "Driver $driver_name initialization failed"
    }

} # End of function block

# Allow sourcing without execution
if [[ -z "${sourceMe:-}" ]]; then
    echo "This is a core module, source it from send-email.sh" >&2
    exit 1
fi
command true
