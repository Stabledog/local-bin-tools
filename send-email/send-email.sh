#!/bin/bash
# send-email.sh - Send email via configured driver

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

    usage() {
        cat <<'EOF'
Usage: send-email.sh [OPTIONS]

Send email via configured email driver (default: gmail-smtp-curl)

OPTIONS:
  --to=ALIAS          Recipient alias from ~/.config/send-email/addresses
  --subject=TEXT      Email subject line
  --body=TEXT         Email body (or @FILE to read from file)
  --dry-run           Show what would be sent without sending
  --driver=NAME       Use specific driver (default: gmail-smtp-curl)
  --help              Show this help
  --version           Show version

EXAMPLES:
  send-email.sh --to=self --subject="Test" --body="Hello"
  send-email.sh --to=friend --subject="Report" --body=@report.txt
  send-email.sh --dry-run --to=boss --subject="Update" --body="Status"

SETUP:
  First-time setup: cd ~/.local/bin/send-email && ./send-email-setup.sh

ADDRESS RESOLUTION:
  Recipients are resolved via ~/.config/send-email/addresses whitelist.
  Use aliases (e.g., 'self', 'boss', 'team') not raw email addresses.
  Run setup to configure your address whitelist.

EOF
        exit 2
    }

    # Check configuration exists
    check_config() {
        local config_dir="${HOME}/.config/send-email"
        local addresses_file="${config_dir}/addresses"
        local credentials_file="${config_dir}/credentials"
        
        if [[ ! -f "$addresses_file" ]] || [[ ! -f "$credentials_file" ]]; then
            die "Not configured. Run: cd ~/.local/bin/send-email && ./send-email-setup.sh"
        fi
        
        # Check credentials permissions (Windows/git-bash may not support all stat features)
        if [[ -f "$credentials_file" ]]; then
            local perms
            perms=$(stat -c '%a' "$credentials_file" 2>/dev/null || echo "unknown")
            if [[ "$perms" != "600" ]] && [[ "$perms" != "unknown" ]]; then
                echo "WARNING: Insecure permissions on $credentials_file (should be 600)" >&2
                echo "Run: chmod 600 $credentials_file" >&2
            fi
        fi
    }

}

main() {
    set -ue
    
    # Default values
    local to_alias=""
    local subject=""
    local body=""
    local body_from_file=""
    local dry_run=0
    local driver_name="gmail-smtp-curl"
    local show_version=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --to=*)
                to_alias="${1#*=}"
                shift
                ;;
            --subject=*)
                subject="${1#*=}"
                shift
                ;;
            --body=*)
                body="${1#*=}"
                # Check if body is from file (starts with @)
                if [[ "$body" =~ ^@ ]]; then
                    body_from_file="${body#@}"
                    body=""
                fi
                shift
                ;;
            --dry-run)
                dry_run=1
                shift
                ;;
            --driver=*)
                driver_name="${1#*=}"
                shift
                ;;
            --version)
                show_version=1
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                die "Unknown option: $1 (use --help for usage)"
                ;;
        esac
    done
    
    # Handle version request
    if [[ $show_version -eq 1 ]]; then
        if [[ -f "${scriptDir}/send-email-version.sh" ]]; then
            bash "${scriptDir}/send-email-version.sh"
        else
            echo "send-email version unknown"
        fi
        exit 0
    fi
    
    # Validate required arguments
    [[ -n "$to_alias" ]] || die "Missing required argument: --to=ALIAS"
    [[ -n "$subject" ]] || die "Missing required argument: --subject=TEXT"
    
    # Load body from file if specified
    if [[ -n "$body_from_file" ]]; then
        [[ -f "$body_from_file" ]] || die "Body file not found: $body_from_file"
        body=$(cat "$body_from_file")
    fi
    
    [[ -n "$body" ]] || die "Missing required argument: --body=TEXT or --body=@FILE"
    
    # Check configuration exists
    check_config
    
    # Load core functions
    # shellcheck disable=SC1091
    sourceMe=1 source "${scriptDir}/send-email-core.sh"
    
    # Resolve recipient address
    local recipient_email
    recipient_email=$(resolve_address "$to_alias") || exit 1
    
    echo "Recipient: $to_alias → $recipient_email"
    
    # Load and initialize driver
    load_driver "$driver_name"
    
    # Get sender email from credentials
    local config_dir="${HOME}/.config/send-email"
    local credentials_file="${config_dir}/credentials"
    
    # shellcheck disable=SC1090
    source "$credentials_file"
    
    local sender_email="${GMAIL_USER:-}"
    [[ -n "$sender_email" ]] || die "GMAIL_USER not set in $credentials_file"
    
    # Create temporary message file
    local temp_msg
    temp_msg=$(mktemp)
    
    # Cleanup on exit
    trap 'rm -f "$temp_msg"' EXIT
    
    # Format email message
    format_email_message "$sender_email" "$recipient_email" "$subject" "$body" "$temp_msg"
    
    # Dry run or actual send
    if [[ $dry_run -eq 1 ]]; then
        echo ""
        echo "========== DRY RUN (not sending) =========="
        echo "Driver: $driver_name"
        echo "From: $sender_email"
        echo "To: $recipient_email"
        echo "Subject: $subject"
        echo ""
        echo "Message preview:"
        echo "---"
        cat "$temp_msg"
        echo "---"
        echo ""
        echo "========== END DRY RUN =========="
    else
        # Set globals for driver
        # shellcheck disable=SC2034  # Variables used by sourced driver
        email_from="$sender_email"
        # shellcheck disable=SC2034  # Variables used by sourced driver
        email_to="$recipient_email"
        # shellcheck disable=SC2034  # Variables used by sourced driver
        email_subject="$subject"
        # shellcheck disable=SC2034  # Variables used by sourced driver
        email_body="$body"
        # shellcheck disable=SC2034  # Variables used by sourced driver
        email_body_file="$temp_msg"
        
        # Send email
        driver_send_email || exit 1
    fi
}

if [[ -z "${sourceMe:-}" ]]; then
    main "$@"
    builtin exit
fi
command true
