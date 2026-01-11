**Agents for ~/.local/bin**

This directory contains personal command-line tools (origin: https:/github.com/Stabledog/local-bin-tools). The purpose of this document is to specify repository conventions and AI guidelines for adding and maintaining tools here.

- **Location / PATH:** This working copy is on the user's `PATH`. Tools placed here are intended to be runnable directly from a shell.

- **Executable layout:** Keep the canonical source for each tool inside a tool-specific subdirectory (for example: `my-tool/`). Put the actual executable file(s) in that subdirectory and create symlinks to the executable from the repository root so the tool is runnable directly from `PATH`.

- **Non-executable files:** Docs, templates, test fixtures, sample data, and other non-executable artifacts belong in the tool-specific subdir—not the repo root.

- **Shell language & style:** Assume `bash` is the shell unless a script explicitly targets another shell (PowerShell, zsh, etc.). Shell scripts should follow the style and structure of `BASH_TEMPLATE.sh` where practical, including:
	- a `usage()` function and clear argument parsing
	- a `main()` entrypoint
	- `sourceMe` support so helper functions can be sourced for interactive use or unit testing without executing the full script
	- **AI agents must read and follow `BASH-CODING-STANDARD.md`** which provides explicit structural rules, indentation requirements, and common pitfalls to avoid when creating or refactoring bash scripts

- **Linting / static checks:**
	- All shell scripts must be checked with `shellcheck` and fixed where practical. If `shellcheck` reports environment-specific or hard-to-resolve false positives, add targeted `shellcheck` suppressions and document the reasoning directly above the suppression.
	- Python scripts should be linted with `ruff` (or the chosen project linter) and fixed where practical.

- **External dependencies:** Scripts that depend on external programs must test for those programs at startup and abort with a clear, actionable error if missing. Do not perform automatic installs at runtime. If installation instructions are unambiguous across target environments, include short setup steps in the tool README or the error message.

- **Testing:** Validate scripts to a practical extent before declaring them done. Recommended approaches:
	- add lightweight unit tests for exported functions (for shell, `bats` or simple shell harnesses; for Python, `pytest`)
	- use `sourceMe` to load internal helpers during tests or interactive debugging

- **Robustness & safety:** Fail fast with clear errors. Avoid surprising side-effects.

- **Automation / CI (recommended):** Add a simple CI job or `Makefile` targets that run `shellcheck`, `ruff`, and basic tests for changed tools to prevent regressions.

- **Documentation:** 

    - Each tool should include a short README in its tool subdir describing purpose, usage, prerequisites, and any required setup steps.
    - Each tool should contain an AGENTS.md file which references the parent AGENTs.md (~/.local/bin/AGENTS.md), and then continues with tool-specific guidance for AI agents


