#!/bin/bash
# send-email-setup.sh - Setup wizard for send-email tool

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

main() {
    set -ue
    
    echo "========================================"
    echo "  send-email Tool Setup"
    echo "========================================"
    echo ""
    
    # Check curl available
    command -v curl >/dev/null 2>&1 || die "curl not found (required)"
    
    # Create config directory
    local config_dir="${HOME}/.config/send-email"
    if [[ -d "$config_dir" ]]; then
        echo "Config directory: found"
    else
        echo "Config directory: creating..."
        mkdir -p "$config_dir"
        echo "Config directory: created"
    fi
    echo ""
    
    # Setup credentials (skip if exists)
    local credentials_file="${config_dir}/credentials"
    local gmail_user=""
    
    if [[ -f "$credentials_file" ]]; then
        echo "Credentials file: found"
        echo "  (Skipping Gmail configuration)"
        echo ""
        
        # Extract gmail_user for later use
        # shellcheck disable=SC1090
        source "$credentials_file"
        gmail_user="${GMAIL_USER:-}"
    else
        echo "Credentials file: not found"
        echo ""
        echo "Step 1: Gmail Configuration"
        echo "---------------------------"
        echo ""
        echo "You need a Gmail App Password (not your regular password)."
        echo ""
        echo "Prerequisites:"
        echo "  1. Gmail account with 2-Factor Authentication enabled"
        echo "  2. Generate App Password at:"
        echo "     https://myaccount.google.com/apppasswords"
        echo ""
        echo "Instructions:"
        echo "  1. Go to the link above"
        echo "  2. Sign in to your Google account"
        echo "  3. Select 'Mail' and your device"
        echo "  4. Click 'Generate'"
        echo "  5. Copy the 16-character password (format: xxxx-xxxx-xxxx-xxxx)"
        echo ""
        
        read -r -p "Enter your Gmail address: " gmail_user
        [[ -n "$gmail_user" ]] || die "Gmail address required"
        
        read -r -s -p "Enter your App Password: " app_password
        echo ""
        [[ -n "$app_password" ]] || die "App Password required"
        
        # Remove spaces/dashes from app password
        app_password="${app_password// /}"
        app_password="${app_password//-/}"
        
        # Write credentials file
        cat > "$credentials_file" <<EOF
# Gmail SMTP credentials
# Created: $(date)
GMAIL_USER=$gmail_user
GMAIL_APP_PASSWORD=$app_password
EOF
        
        chmod 600 "$credentials_file"
        echo "✓ Credentials saved to: $credentials_file (mode 600)"
        echo ""
    fi
    
    # Setup addresses file (skip if exists)
    echo "Step 2: Address Whitelist"
    echo "-------------------------"
    echo ""
    
    local addresses_file="${config_dir}/addresses"
    
    if [[ -f "$addresses_file" ]]; then
        echo "Address book: found"
        echo "  (Skipping address whitelist creation)"
        echo ""
    else
        echo "Address book: not found"
        echo ""
        echo "Creating address whitelist with example entries."
        echo "Edit ~/.config/send-email/addresses to add your contacts."
        echo ""
        
        # Get gmail_user from credentials if not set
        if [[ -z "${gmail_user:-}" ]] && [[ -f "$credentials_file" ]]; then
            # shellcheck disable=SC1090
            source "$credentials_file"
            gmail_user="${GMAIL_USER:-}"
        fi
        
        cat > "$addresses_file" <<EOF
# Email address whitelist with aliases
# Format: email_address alias1 alias2 alias3 ...
#
# Examples:
# user@gmail.com self me myself
# friend@example.com friend alice
# boss@company.com boss manager
# team@example.com team devs

${gmail_user:-user@gmail.com} self me myself
EOF
        
        echo "✓ Address file created: $addresses_file"
        echo ""
        if [[ -n "${gmail_user:-}" ]]; then
            echo "Your email ($gmail_user) added with aliases: self, me, myself"
        else
            echo "Example entry added (edit to add your email)"
        fi
        echo ""
    fi
    
    # Offer test send
    echo "Step 3: Test Email (Optional)"
    echo "-----------------------------"
    echo ""
    read -r -p "Send test email to yourself? (y/n): " do_test
    
    if [[ "$do_test" =~ ^[Yy] ]]; then
        echo ""
        echo "Sending test email..."
        
        # Get gmail_user if not already set
        if [[ -z "${gmail_user:-}" ]]; then
            # shellcheck disable=SC1090
            source "$credentials_file"
            gmail_user="${GMAIL_USER:-}"
        fi
        
        # Source send-email-core.sh and driver
        # shellcheck disable=SC1091
        sourceMe=1 source "${scriptDir}/send-email-core.sh"
        # shellcheck disable=SC1091
        sourceMe=1 source "${scriptDir}/drivers/gmail-smtp-curl.driver"
        
        driver_check_dependencies || die "Driver dependency check failed"
        driver_init || die "Driver initialization failed"
        
        # Create temp message file
        local temp_msg
        temp_msg=$(mktemp)
        
        # Cleanup on exit (use || true to handle unbound variable if script exits early)
        trap 'rm -f "${temp_msg:-}"' EXIT
        
        cat > "$temp_msg" <<EOFMSG
From: $gmail_user
To: $gmail_user
Subject: send-email Test
Date: $(date -R)

This is a test email from the send-email tool.

Setup completed successfully!

--
Sent via send-email tool
EOFMSG
        
        # Set globals for driver
        # shellcheck disable=SC2034  # Variables used by sourced driver
        email_from="$gmail_user"
        # shellcheck disable=SC2034  # Variables used by sourced driver
        email_to="$gmail_user"
        # shellcheck disable=SC2034  # Variables used by sourced driver
        email_subject="send-email Test"
        # shellcheck disable=SC2034  # Variables used by sourced driver
        email_body_file="$temp_msg"
        
        if driver_send_email; then
            echo "✓ Test email sent successfully!"
        else
            echo "✗ Test email failed (see errors above)"
            exit 1
        fi
    fi
    
    echo ""
    echo "========================================"
    echo "  Setup Complete!"
    echo "========================================"
    echo ""
    echo "Configuration saved to: ${config_dir}/"
    echo ""
    echo "Usage examples:"
    echo "  send-email.sh --to=self --subject='Test' --body='Hello'"
    echo "  send-email.sh --to=self --subject='Report' --body=@report.txt"
    echo "  send-email.sh --dry-run --to=self --subject='Test' --body='Preview'"
    echo ""
    echo "Edit your address whitelist:"
    echo "  \$EDITOR ${addresses_file}"
    echo ""
}

main "$@"
