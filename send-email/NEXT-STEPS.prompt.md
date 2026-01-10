# Implementation Prompt: send-email Tool

## Context

You are implementing a command-line email sending tool for the `~/.local/bin` repository. This is a personal tools directory following strict conventions documented in `AGENTS.md`. The user works in git-bash on Windows and uses VSCode.

**Repository conventions (from AGENTS.md):**
- Tools live in subdirectories with symlinks to repo root for PATH access
- Follow `BASH_TEMPLATE.sh` structure (sourceMe pattern, die(), usage(), main())
- All scripts must pass `shellcheck` with documented suppressions for false positives
- External dependencies must be checked at startup with actionable errors
- Non-executable files (docs, templates, configs) stay in tool subdir
- Include `--dry-run` modes for validation
- Each tool has: `Kitname`, `_symlinks_`, `setup.sh`, `{tool}-version.sh`, README.md

## Project Goal

Create a modular email sending tool that:
1. Sends email via Gmail SMTP using curl (native to git-bash)
2. Uses pluggable driver architecture for future email providers
3. Enforces whitelist-based addressing to prevent typos
4. Supports alias resolution for convenience
5. Has separate setup and send scripts
6. Follows repository conventions exactly

## Architecture Decisions

### File Structure

```
send-email/
├── Kitname                          # Contains: "send-email"
├── _symlinks_                       # Lists: send-email.sh
├── README.md                        # Tool documentation
├── send-email-version.sh            # Version: 0.1.0
├── send-email.sh                    # Main CLI (symlinked to repo root)
├── send-email-core.sh               # Core orchestration logic
├── send-email-setup.sh              # Setup wizard (NOT symlinked)
├── drivers/
│   └── gmail-smtp-curl.driver       # Gmail SMTP via curl
└── NEXT-STEPS.prompt.md             # This file
```

### Configuration Files (in user's home)

```
~/.config/send-email/
├── credentials                      # chmod 600, contains Gmail App Password
└── addresses                        # Whitelist with inline aliases
```

### Address File Format

Format: `email_address alias1 alias2 alias3 ...`

Example `~/.config/send-email/addresses`:
```
# Format: email_address alias1 alias2 ...
# First entry should be your own email
user@gmail.com self me myself
friend@example.com friend alice
work@company.com boss manager
team@example.com team devs
```

### Credentials File Format

Example `~/.config/send-email/credentials`:
```
# Gmail SMTP credentials
GMAIL_USER=user@gmail.com
GMAIL_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

### Driver Interface

Each driver must implement:
- `driver_check_dependencies()` - Verify required tools (e.g., curl)
- `driver_init()` - Load config, validate credentials
- `driver_send_email()` - Send email with parameters
- `driver_help()` - Driver-specific setup instructions

Driver receives these parameters via globals:
- `$email_from` - Sender email
- `$email_to` - Recipient email (already resolved)
- `$email_subject` - Subject line
- `$email_body` - Message body content
- `$email_body_file` - Temp file with message body

## Implementation Details

### 1. send-email.sh (Main CLI)

**Purpose:** Main entry point, argument parsing, validation

**Key features:**
- Follow `BASH_TEMPLATE.sh` structure exactly
- Check config exists, abort if not: "Not configured. Run: cd ~/.local/bin/send-email && ./send-email-setup.sh"
- Parse arguments: `--to=ALIAS`, `--subject=TEXT`, `--body=TEXT`, `--body=@FILE`, `--dry-run`, `--driver=NAME`, `--help`, `--version`
- Check credentials file permissions (should be 600), warn if not
- Source `send-email-core.sh` and driver
- Call core functions to resolve address and send email
- Support `sourceMe` pattern for testing

**Usage examples:**
```bash
# Simple send
send-email.sh --to=self --subject="Test" --body="Hello"

# Body from file
send-email.sh --to=friend --subject="Report" --body=@report.txt

# Dry run
send-email.sh --dry-run --to=boss --subject="Update" --body="Status update"

# Explicit driver
send-email.sh --driver=gmail-smtp-curl --to=team --subject="Announcement" --body="Meeting at 3pm"
```

**Error handling:**
- Missing config files → helpful setup message
- Invalid alias → list available aliases from addresses file
- Missing required args → show usage
- Driver errors → bubble up with context

**Code pattern:**
```bash
#!/bin/bash
# send-email.sh - Send email via configured driver

PS4='$( _0=$?; exec 2>/dev/null; realpath -- "${BASH_SOURCE[0]:-?}:${LINENO} ^$_0 ${FUNCNAME[0]:-?}()=>" ) '
[[ -n "$DEBUGSH" ]] && set -x
set -euo pipefail

scriptName="${scriptName:-"$(command readlink -f -- "$0")"}"
scriptDir="$(command dirname -- "${scriptName}")"

die() {
    builtin echo "ERROR($(basename "${scriptName}")): $*" >&2
    builtin exit 1
}

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
    
    # Check credentials permissions
    if [[ -f "$credentials_file" ]]; then
        local perms=$(stat -c '%a' "$credentials_file" 2>/dev/null || echo "unknown")
        if [[ "$perms" != "600" ]] && [[ "$perms" != "unknown" ]]; then
            echo "WARNING: Insecure permissions on $credentials_file (should be 600)" >&2
            echo "Run: chmod 600 $credentials_file" >&2
        fi
    fi
}

main() {
    # Parse arguments
    # Load send-email-core.sh
    # Resolve address
    # Load driver
    # Send email or dry-run
}

if [[ -z "${sourceMe:-}" ]]; then
    main "$@"
    builtin exit
fi
command true
```

### 2. send-email-core.sh (Orchestration Logic)

**Purpose:** Address resolution, email formatting, driver coordination

**Key functions:**

```bash
# Parse address file and resolve alias to email
resolve_address() {
    local alias="$1"
    local addresses_file="${HOME}/.config/send-email/addresses"
    
    [[ -f "$addresses_file" ]] || die "Addresses file not found: $addresses_file"
    
    # Parse format: email alias1 alias2 alias3 ...
    # Return email if alias matches
    # Abort if alias appears multiple times (duplicate detection)
    # Error if not found
}

# List available aliases for error messages
list_aliases() {
    local addresses_file="${HOME}/.config/send-email/addresses"
    # Parse and display aliases
}

# Build RFC-compliant email message
format_email_message() {
    local from="$1"
    local to="$2"
    local subject="$3"
    local body="$4"
    local output_file="$5"
    
    # Generate:
    # From: $from
    # To: $to
    # Subject: $subject
    # Date: $(date -R)
    # 
    # $body
}

# Load and validate driver
load_driver() {
    local driver_name="$1"
    local driver_file="${scriptDir}/drivers/${driver_name}.driver"
    
    [[ -f "$driver_file" ]] || die "Driver not found: $driver_name"
    
    # Source driver
    # shellcheck disable=SC1090
    sourceMe=1 source "$driver_file"
    
    # Validate interface
    type -t driver_check_dependencies >/dev/null || \
        die "Driver $driver_name missing driver_check_dependencies()"
    type -t driver_init >/dev/null || \
        die "Driver $driver_name missing driver_init()"
    type -t driver_send_email >/dev/null || \
        die "Driver $driver_name missing driver_send_email()"
    
    # Check dependencies
    driver_check_dependencies || die "Driver $driver_name dependency check failed"
    
    # Initialize driver
    driver_init || die "Driver $driver_name initialization failed"
}
```

### 3. drivers/gmail-smtp-curl.driver (Gmail SMTP Implementation)

**Purpose:** Send email via Gmail SMTP using curl

**Gmail SMTP details:**
- Server: smtp.gmail.com
- Port: 465 (SMTPS - SMTP over SSL)
- Auth: Username + App Password
- Requires 2FA enabled on Gmail account
- App Password from: https://myaccount.google.com/apppasswords

**Implementation:**

```bash
#!/bin/bash
# gmail-smtp-curl.driver - Gmail SMTP driver using curl

# Driver interface implementation

driver_check_dependencies() {
    command -v curl >/dev/null 2>&1 || {
        echo "ERROR: curl not found (required for Gmail SMTP)" >&2
        return 1
    }
    return 0
}

driver_init() {
    local credentials_file="${HOME}/.config/send-email/credentials"
    
    [[ -f "$credentials_file" ]] || {
        echo "ERROR: Credentials file not found: $credentials_file" >&2
        return 1
    }
    
    # Source credentials
    # shellcheck disable=SC1090
    source "$credentials_file"
    
    [[ -n "${GMAIL_USER:-}" ]] || {
        echo "ERROR: GMAIL_USER not set in $credentials_file" >&2
        return 1
    }
    
    [[ -n "${GMAIL_APP_PASSWORD:-}" ]] || {
        echo "ERROR: GMAIL_APP_PASSWORD not set in $credentials_file" >&2
        return 1
    }
    
    return 0
}

driver_send_email() {
    # Expects these globals:
    # - $email_from
    # - $email_to
    # - $email_subject
    # - $email_body_file (temp file with formatted message)
    
    local credentials_file="${HOME}/.config/send-email/credentials"
    # shellcheck disable=SC1090
    source "$credentials_file"
    
    # Use curl to send via SMTP
    local curl_output
    curl_output=$(curl -v \
        --url "smtps://smtp.gmail.com:465" \
        --ssl-reqd \
        --mail-from "$email_from" \
        --mail-rcpt "$email_to" \
        --user "${GMAIL_USER}:${GMAIL_APP_PASSWORD}" \
        --upload-file "$email_body_file" \
        2>&1)
    
    local exit_code=$?
    
    # Handle curl exit codes
    case $exit_code in
        0)
            echo "Email sent successfully to: $email_to"
            return 0
            ;;
        67)
            echo "ERROR: Authentication failed" >&2
            echo "Your Gmail App Password may be invalid or expired." >&2
            echo "Re-run setup: ~/.local/bin/send-email/send-email-setup.sh" >&2
            echo "" >&2
            echo "Curl output:" >&2
            echo "$curl_output" >&2
            return 1
            ;;
        *)
            echo "ERROR: Failed to send email (curl exit code: $exit_code)" >&2
            echo "" >&2
            echo "Curl output:" >&2
            echo "$curl_output" >&2
            return 1
            ;;
    esac
}

driver_help() {
    cat <<'EOF'
Gmail SMTP Driver (gmail-smtp-curl)

Sends email via Gmail's SMTP server using curl.

REQUIREMENTS:
  - Gmail account with 2FA enabled
  - Gmail App Password (not your regular password)
  - curl with SSL/TLS support (native to git-bash)

SETUP:
  1. Enable 2FA on your Gmail account
  2. Generate App Password: https://myaccount.google.com/apppasswords
  3. Run: ~/.local/bin/send-email/send-email-setup.sh
  4. Enter your Gmail address and App Password when prompted

CONFIGURATION:
  Credentials stored in: ~/.config/send-email/credentials (mode 600)
  Format:
    GMAIL_USER=your-email@gmail.com
    GMAIL_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx

TROUBLESHOOTING:
  - Authentication failed (exit 67): App Password invalid/expired
  - Connection failed: Check network, Gmail SMTP not blocked
  - Rate limiting: Gmail may throttle if sending too frequently

EOF
}

# Allow sourcing without execution
if [[ -z "${sourceMe:-}" ]]; then
    echo "This is a driver module, source it from send-email.sh" >&2
    exit 1
fi
command true
```

### 4. send-email-setup.sh (Setup Wizard)

**Purpose:** Interactive setup, config file creation, guided Gmail setup

**Key features:**
- **Idempotent:** Check what exists, only do what's missing
- **Status reporting:** Show "address book: found" or "address book: creating..."
- Create `~/.config/send-email/` directory if needed
- Prompt for Gmail credentials only if credentials file missing
- Explain App Password requirement with link
- Create credentials file (chmod 600) if missing
- Create addresses file with example entries if missing
- Offer test send
- **NOT symlinked to repo root** (user runs from subdir)

**Implementation flow:**

```bash
#!/bin/bash
# send-email-setup.sh - Setup wizard for send-email tool

PS4='$( _0=$?; exec 2>/dev/null; realpath -- "${BASH_SOURCE[0]:-?}:${LINENO} ^$_0 ${FUNCNAME[0]:-?}()=>" ) '
[[ -n "$DEBUGSH" ]] && set -x
set -euo pipefail

scriptName="${scriptName:-"$(command readlink -f -- "$0")"}"
scriptDir="$(command dirname -- "${scriptName}")"

die() {
    builtin echo "ERROR($(basename "${scriptName}")): $*" >&2
    builtin exit 1
}

main() {
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
    if [[ -f "$credentials_file" ]]; then
        echo "Credentials file: found"
        echo "  (Skipping Gmail configuration)"
        echo ""
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
    local credentials_file="${config_dir}/credentials"
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
    
    local addresses_file="${config_dir}/addresses"
    
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
        
        # Source send-email-core.sh and driver
        sourceMe=1 source "${scriptDir}/send-email-core.sh"
        sourceMe=1 source "${scriptDir}/drivers/gmail-smtp-curl.driver"
        
        driver_check_dependencies || die "Driver dependency check failed"
        driver_init || die "Driver initialization failed"
        
        # Create temp message file
        local temp_msg
        temp_msg=$(mktemp)
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
        email_from="$gmail_user"
        email_to="$gmail_user"
        email_subject="send-email Test"
        email_body_file="$temp_msg"
        
        if driver_send_email; then
            echo "✓ Test email sent successfully!"
        else
            echo "✗ Test email failed (see errors above)"
            rm -f "$temp_msg"
            exit 1
        fi
        
        rm -f "$temp_msg"
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
```

### 5. Supporting Files

**Kitname:**
```
send-email
```

**_symlinks_:**
```
send-email.sh
```

**send-email-version.sh:**
```bash
#!/bin/bash
# send-email-version.sh
echo "send-email version 0.1.0"
```

**README.md:**
```markdown
# send-email

Command-line email sending tool with pluggable driver architecture.

## Features

- Send email via Gmail SMTP using curl (default driver)
- Whitelist-based recipient management (prevents typos)
- Alias support for convenient addressing
- Dry-run mode for testing
- Modular driver architecture for future email providers

## Setup

First-time setup (required):

```bash
cd ~/.local/bin/send-email
./send-email-setup.sh
```

The setup wizard will:
1. Guide you through Gmail App Password creation
2. Save credentials securely (chmod 600)
3. Create address whitelist with your email
4. Optionally send a test email

## Usage

Send email to whitelisted addresses by alias:

```bash
# Simple send
send-email.sh --to=self --subject="Test" --body="Hello"

# Body from file
send-email.sh --to=friend --subject="Report" --body=@report.txt

# Dry run (preview without sending)
send-email.sh --dry-run --to=boss --subject="Update" --body="Status"
```

## Address Management

Recipients are resolved via `~/.config/send-email/addresses` whitelist.

Format: `email alias1 alias2 ...`

Example:
```
user@gmail.com self me myself
friend@example.com friend alice
boss@company.com boss manager
```

Edit the file to add/remove contacts:
```bash
$EDITOR ~/.config/send-email/addresses
```

## Configuration

**Location:** `~/.config/send-email/`

**Files:**
- `credentials` - Gmail credentials (mode 600, DO NOT share)
- `addresses` - Recipient whitelist with aliases

## Requirements

- bash (git-bash on Windows)
- curl with SSL/TLS support (native to git-bash)
- Gmail account with 2FA enabled
- Gmail App Password

## Gmail App Password Setup

1. Enable 2FA on your Gmail account
2. Visit: https://myaccount.google.com/apppasswords
3. Generate an App Password for "Mail"
4. Run `./send-email-setup.sh` and enter the password

## Driver Architecture

The tool uses a modular driver system for different email providers.

**Current drivers:**
- `gmail-smtp-curl` - Gmail SMTP via curl (default)

**Future drivers:**
- Office SMTP
- Gmail API (OAuth2)
- Local sendmail (testing)

## Troubleshooting

**Authentication failed (exit code 67):**
- App Password invalid or expired
- Re-run setup: `./send-email-setup.sh`

**Invalid alias error:**
- Alias not found in `~/.config/send-email/addresses`
- Add the alias or use an existing one

**Permission warnings:**
- Run: `chmod 600 ~/.config/send-email/credentials`

## Development

**Testing without sending:**
```bash
send-email.sh --dry-run --to=test --subject="Test" --body="Test"
```

**Source functions for testing:**
```bash
sourceMe=1 source send-email-core.sh
resolve_address "self"
```

**Check with shellcheck:**
```bash
shellcheck send-email.sh send-email-core.sh send-email-setup.sh drivers/*.driver
```

## Version

0.1.0 (January 2026)
```

## Implementation Checklist

### Phase 1: Core Structure
- [ ] Create all directory structure
- [ ] Create `Kitname` file
- [ ] Create `_symlinks_` file
- [ ] Create `send-email-version.sh`
- [ ] Create symlink: `ln -s send-email/send-email.sh ../send-email.sh`

### Phase 2: Core Logic
- [ ] Implement `send-email-core.sh`:
  - [ ] `resolve_address()` function
  - [ ] `list_aliases()` function
  - [ ] `format_email_message()` function
  - [ ] `load_driver()` function
- [ ] Test address resolution with sample addresses file

### Phase 3: Main CLI
- [ ] Implement `send-email.sh`:
  - [ ] Argument parsing (--to, --subject, --body, --dry-run, etc.)
  - [ ] Configuration checks
  - [ ] Permission checks
  - [ ] Help text / usage()
  - [ ] Version handling
  - [ ] Dry-run mode
  - [ ] Integration with core functions
- [ ] Test argument parsing and validation

### Phase 4: Gmail Driver
- [ ] Implement `drivers/gmail-smtp-curl.driver`:
  - [ ] `driver_check_dependencies()`
  - [ ] `driver_init()`
  - [ ] `driver_send_email()`
  - [ ] `driver_help()`
  - [ ] Curl SMTP integration
  - [ ] Error handling (exit code 67, etc.)
- [ ] Test with mock credentials

### Phase 5: Setup Wizard
- [ ] Implement `send-email-setup.sh`:
  - [ ] Interactive prompts
  - [ ] Directory creation
  - [ ] Credentials file creation (chmod 600)
  - [ ] Addresses file creation with examples
  - [ ] Optional test send
  - [ ] Success message with usage examples
- [ ] Test end-to-end setup flow

### Phase 6: Documentation & Polish
- [ ] Create comprehensive `README.md`
- [ ] Add inline comments to all functions
- [ ] Run `shellcheck` on all .sh files
- [ ] Fix any shellcheck violations or add suppressions
- [ ] Test all error paths
- [ ] Test on git-bash/Windows environment

### Phase 7: Integration Testing
- [ ] Test complete workflow:
  - [ ] Run setup wizard
  - [ ] Add test addresses
  - [ ] Send email to self
  - [ ] Test dry-run mode
  - [ ] Test invalid alias error
  - [ ] Test missing config error
  - [ ] Test authentication failure handling
- [ ] Verify symlink works from PATH
- [ ] Verify credentials file has correct permissions

## Testing Scenarios

1. **First-time user:**
   - Run `send-email.sh` without setup → should show setup instruction
   - Run `./send-email-setup.sh` → should complete successfully
   - Send test email → should receive email
   - Run `./send-email-setup.sh` again → should detect existing files and skip appropriately

2. **Address resolution:**
   - Valid alias → should resolve correctly
   - Invalid alias → should show available aliases
   - Multiple aliases for same email → any should work
   - Duplicate alias (same alias for different emails) → should abort with error

3. **Email sending:**
   - Body as string → should send correctly
   - Body from file (@path) → should read and send
   - Dry-run → should show preview without sending

4. **Error handling:**
   - Wrong App Password → exit 67, helpful message
   - Network issues → bubble up curl errors
   - Missing config → show setup instructions
   - Insecure permissions → show warning

5. **Dry-run mode:**
   - Should resolve aliases
   - Should show formatted message
   - Should NOT send email

## Gmail SMTP Technical Details

**Connection:**
- Protocol: SMTPS (SMTP over SSL)
- Server: smtp.gmail.com
- Port: 465
- TLS/SSL: Required

**Authentication:**
- Method: PLAIN (username + App Password)
- Username: Full Gmail address
- Password: 16-character App Password (not account password)

**Curl command structure:**
```bash
curl --url "smtps://smtp.gmail.com:465" \
     --ssl-reqd \
     --mail-from "sender@gmail.com" \
     --mail-rcpt "recipient@example.com" \
     --user "sender@gmail.com:app_password" \
     --upload-file message.txt
```

**Exit codes to handle:**
- 0: Success
- 6: Couldn't resolve host
- 7: Failed to connect
- 67: Authentication failed
- Other: Various SSL/protocol errors

**Message format:**
```
From: sender@gmail.com
To: recipient@example.com
Subject: Subject line here
Date: Fri, 10 Jan 2026 12:00:00 -0500

Body of the email goes here.
Multiple lines supported.
```

## Windows/Git-bash Considerations

1. **Path handling:**
   - Use `${HOME}` for user home directory
   - `realpath` and `readlink -f` work in git-bash
   - Forward slashes work fine

2. **Permissions:**
   - `chmod 600` works in git-bash
   - `stat -c '%a'` works for permission checks

3. **Curl:**
   - Native to git-bash
   - SSL/TLS support included
   - SMTP protocol supported

4. **Line endings:**
   - Git-bash handles automatically for most cases
   - Email headers can use Unix line endings (\n)
   - SMTP protocol accepts both

5. **Temporary files:**
   - `mktemp` works in git-bash
   - Clean up with `rm -f`

## Future Enhancements (Not in Phase 1)

- CC/BCC support
- Attachment handling
- HTML email support
- Email templates
- Batch sending
- Gmail API OAuth2 driver
- Office SMTP driver
- Address groups
- Configuration profiles (work/personal)
- Logging/history
- Retry logic
- Rate limiting protection

## Important Notes

- **Security:** Credentials file MUST be chmod 600
- **Whitelist only:** Never allow arbitrary email addresses
- **Error messages:** Bubble up curl errors for now, enrich later if needed
- **Setup separate:** Setup script is NOT symlinked, runs from subdir
- **Following conventions:** Must match BASH_TEMPLATE.sh structure and AGENTS.md requirements
- **Shellcheck clean:** All scripts must pass shellcheck

## Success Criteria

The implementation is complete when:

1. ✓ User can run setup wizard successfully
2. ✓ User can send email to self using alias
3. ✓ Address resolution works with multiple aliases
4. ✓ Dry-run shows preview without sending
5. ✓ Invalid alias shows helpful error
6. ✓ Missing config shows setup instructions
7. ✓ Auth failure shows helpful error (exit 67)
8. ✓ All scripts pass shellcheck
9. ✓ README.md documents all features
10. ✓ Symlink works from PATH

## Begin Implementation

Start with Phase 1 (Core Structure) and work through each phase sequentially. Test each component before moving to the next phase. Follow the repository conventions exactly as documented in AGENTS.md and BASH_TEMPLATE.sh.

The goal is a robust, maintainable tool that serves as the foundation for future email automation and AI agent integration.
