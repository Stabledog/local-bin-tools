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

### Command-Line Options

- `--to=ALIAS` - Recipient alias from address whitelist (required)
- `--subject=TEXT` - Email subject line (required)
- `--body=TEXT` - Email body content (required)
- `--body=@FILE` - Read body from file
- `--dry-run` - Preview message without sending
- `--driver=NAME` - Use specific driver (default: gmail-smtp-curl)
- `--help` - Show help message
- `--version` - Show version information

## Address Management

Recipients are resolved via `~/.config/send-email/addresses` whitelist.

### Format

```
email_address alias1 alias2 alias3 ...
```

### Example

```
user@gmail.com self me myself
friend@example.com friend alice
boss@company.com boss manager
team@example.com team devs
```

### Editing

Edit the file to add/remove contacts:

```bash
$EDITOR ~/.config/send-email/addresses
```

Or on Windows:

```bash
code ~/.config/send-email/addresses
```

## Configuration

**Location:** `~/.config/send-email/`

**Files:**
- `credentials` - Gmail credentials (mode 600, DO NOT share)
- `addresses` - Recipient whitelist with aliases

### Credentials File Format

```bash
# Gmail SMTP credentials
GMAIL_USER=your-email@gmail.com
GMAIL_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

**Important:** The credentials file should have mode 600 for security:

```bash
chmod 600 ~/.config/send-email/credentials
```

## Requirements

- bash (git-bash on Windows)
- curl with SSL/TLS support (native to git-bash)
- Gmail account with 2FA enabled
- Gmail App Password

## Gmail App Password Setup

1. Enable 2FA on your Gmail account at: https://myaccount.google.com/security
2. Visit: https://myaccount.google.com/apppasswords
3. Generate an App Password for "Mail"
4. Run `./send-email-setup.sh` and enter the password when prompted

**Note:** App Passwords are only available after enabling 2-Factor Authentication.

## Driver Architecture

The tool uses a modular driver system for different email providers.

### Current Drivers

- `gmail-smtp-curl` - Gmail SMTP via curl (default)

### Future Drivers

- Office 365 SMTP
- Gmail API with OAuth2
- Local sendmail (for testing)
- AWS SES

### Driver Interface

Each driver must implement:

- `driver_check_dependencies()` - Verify required tools
- `driver_init()` - Load config, validate credentials
- `driver_send_email()` - Send email with parameters
- `driver_help()` - Driver-specific setup instructions

## Troubleshooting

### Authentication failed (exit code 67)

**Problem:** Gmail rejected your credentials

**Solutions:**
- App Password may be invalid or expired
- Re-run setup: `cd ~/.local/bin/send-email && ./send-email-setup.sh`
- Verify 2FA is enabled on your Gmail account
- Generate a new App Password

### Invalid alias error

**Problem:** Alias not found in address whitelist

**Solutions:**
- Check available aliases: `cat ~/.config/send-email/addresses`
- Add the alias to the addresses file
- Use an existing alias from the list

### Permission warnings

**Problem:** Credentials file has insecure permissions

**Solution:**
```bash
chmod 600 ~/.config/send-email/credentials
```

### Could not resolve host (exit code 6)

**Problem:** DNS resolution failed

**Solutions:**
- Check your internet connection
- Verify DNS is working: `nslookup smtp.gmail.com`
- Try again after network is stable

### Failed to connect (exit code 7)

**Problem:** Cannot connect to Gmail SMTP server

**Solutions:**
- Check your internet connection
- Verify firewall is not blocking port 465
- Check if your organization blocks SMTP connections
- Try from a different network

### Not configured error

**Problem:** Configuration files missing

**Solution:**
```bash
cd ~/.local/bin/send-email
./send-email-setup.sh
```

## Development

### Testing without sending

```bash
send-email.sh --dry-run --to=self --subject="Test" --body="Test message"
```

### Source functions for testing

```bash
sourceMe=1 source send-email-core.sh
resolve_address "self"
```

### Check with shellcheck

```bash
shellcheck send-email.sh send-email-core.sh send-email-setup.sh drivers/*.driver
```

## Security Considerations

1. **Credentials file:** Always keep mode 600 to prevent unauthorized access
2. **Whitelist only:** Tool prevents sending to arbitrary addresses (typo protection)
3. **App Passwords:** Use Gmail App Passwords, not your main password
4. **Version control:** Never commit credentials file to git
5. **Sharing:** Do not share your credentials or App Password

## Examples

### Send a quick message

```bash
send-email.sh --to=self --subject="Quick note" --body="Remember to review PR"
```

### Send a report from file

```bash
send-email.sh --to=boss --subject="Daily Report" --body=@daily-report.txt
```

### Preview before sending

```bash
send-email.sh --dry-run --to=team --subject="Announcement" --body="Meeting at 3pm"
```

### Send from script

```bash
#!/bin/bash
# Generate report and email it

./generate-report.sh > report.txt

send-email.sh \
    --to=manager \
    --subject="Automated Report - $(date +%Y-%m-%d)" \
    --body=@report.txt

rm report.txt
```

## File Structure

```
send-email/
├── Kitname                          # Contains: "send-email"
├── _symlinks_                       # Lists: send-email.sh
├── README.md                        # This file
├── send-email-version.sh            # Version: 0.1.0
├── send-email.sh                    # Main CLI (symlinked to repo root)
├── send-email-core.sh               # Core orchestration logic
├── send-email-setup.sh              # Setup wizard (NOT symlinked)
└── drivers/
    └── gmail-smtp-curl.driver       # Gmail SMTP via curl
```

## Version

0.1.0 (January 2026)

## License

Part of the `~/.local/bin` personal tools repository.

## See Also

- [Gmail App Passwords](https://myaccount.google.com/apppasswords)
- [Gmail SMTP Settings](https://support.google.com/mail/answer/7126229)
- [curl SMTP Documentation](https://curl.se/docs/manpage.html#SMTP)
