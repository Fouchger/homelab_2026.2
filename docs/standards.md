# Project standards

## Code quality gates

We use pre-commit for consistent formatting and basic linting.

1. Install tooling
   1. `pipx install pre-commit`
   2. `pre-commit install`
2. Run locally
   1. `pre-commit run -a`

## Shell scripts

1. Bash only (no zsh features)
2. `set -Eeuo pipefail` and `IFS=$'\n\t'`
3. Scripts must source `lib/logging.sh` and use `info|warn|error|ok`
4. Every script must include a header comment block and explicit developer notes
5. Favour idempotence. If a script is destructive, it must ask for confirmation

## Markdown

1. Markdownlint with 120 char line length
2. Keep tables short and readable

## Secrets

1. No secrets in git. No exceptions
2. Use SOPS for encrypted files (Age recommended)
3. Treat token outputs (`*.token`) as sensitive and keep them out of the repo

## Terraform

1. Pin provider versions
2. Separate service modules
3. Use outputs to feed Ansible inventory generation
