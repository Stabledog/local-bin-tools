# AI Development Guidelines for send-email

⚠️ **IMPORTANT**: This tool is part of the `~/.local/bin` repository. Before proceeding:

1. **Read the parent AGENTS.md first**: [`../AGENTS.md`](../AGENTS.md) contains the core guidelines for all tools in this repository
2. The git repository root is `~/.local/bin` (parent directory)
3. This tool lives in a subdirectory and is symlinked to the parent for PATH access

## Tool-Specific Guidelines: send-email

### Architecture Overview

**Purpose**: Command-line email sending tool with pluggable driver architecture

**Components**:
- `send-email.sh` - Main CLI (symlinked to parent for PATH access)
- `send-email-core.sh` - Core orchestration (address resolution, email formatting, driver loading)
- `send-email-setup.sh` - Interactive setup wizard (NOT symlinked)
- `drivers/gmail-smtp-curl.driver` - Gmail SMTP via curl (default driver)

**Configuration** (`~/.config/send-email/`):
- `credentials` (chmod 600) - Driver credentials (namespaced: GMAIL_*, OFFICE365_*, etc.)
- `addresses` - Whitelist with aliases: `email@domain.com alias1 alias2 alias3`

### Key Design Decisions

1. **Whitelist-only addressing** - Never allow arbitrary email addresses (typo protection)
2. **Driver interface** - Each driver implements: `driver_check_dependencies()`, `driver_init()`, `driver_send_email()`, `driver_help()`
3. **Credentials storage** - Plain text with filesystem permissions (600), namespaced variables per driver
4. **Sourced modules** - All modules use `sourceMe` pattern for testability

### Maintenance Notes

**When adding new drivers**:
1. Create `drivers/new-driver.driver` following gmail-smtp-curl.driver structure
2. Implement all four required functions
3. Use namespaced credentials (e.g., `OFFICE365_USER`, `OFFICE365_PASSWORD`)
4. Add driver-specific help to `driver_help()`

**Common false positives in shellcheck**:
- SC2034: Variables used by sourced drivers (`email_from`, `email_to`, `email_body_file`)
- SC2154: Variables set by parent script (`scriptDir` in sourced modules)
- SC1090/SC1091: Dynamic source paths

**Testing checklist**:
- All scripts must pass shellcheck
- Test with `--dry-run` before sending
- Verify error handling for missing config, invalid alias, auth failures

### Code Conventions

All scripts follow `../BASH_TEMPLATE.sh`:
- Functions (except `main` and `die`) nested in `{ }` block
- `set -ue` at start of `main()`
- `#shellcheck disable=2154` before PS4
- `sourceMe` pattern for modules
